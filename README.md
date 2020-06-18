# KNucleus-cs

Repository for the Container Stuff




## ReadinessProbe and LivenessProbe
    These are  important concepts for k8s services (you can read more about it here https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/),

### ReadinessProbe

readinessProbe: Indicates whether the Container is ready to service requests. If the readiness probe
fails, the endpoints controller removes the Pod’s IP address from the endpoints of all Services that
match the Pod. The default state of readiness before the initial delay is Failure. If a Container
does not provide a readiness probe, the default state is Success.

### LivenessProbe

livenessProbe: Indicates whether the Container is running. If the liveness probe fails, the kubelet
kills the Container, and the Container is subjected to its restart policy. If a Container does not
provide a liveness probe, the default state is Success.


### Startup probe 
Our current version of the k8s cluster does not support the startup probe yet!!! Revisit this in the future.

### Current nucleus implementation of ReadinessProbe and LivenessProbe
	 The readinessProbe and livenessProbe are used to by k8s to decide to start sending traffic or restart a Pod. Ideally, we would have a /healthz endpoints to check if the application is ready to receive traffic. We do not have one today, for that we create the issue https://jira.statrad.com/browse/NIX-14801 
watch it to see when this will be implemented appropriately, and then we can update all paste usages of the current solution. 

By now, we are taking advantage of meteor default behave, by calling the path `/` that returns http 200 Ok if the application is working and fails or takes a long time to respond if the application is having some problem. With this behavior, it attends to our initial requirement to tell k8s if the
A pod is ready to receive traffic and or un-health to handle traffic, and it needs to restart.

 Note:
 initialDelaySeconds delay showed up to be necessary, and this application takes a long time to start
 working and if we define a short time it will lead to an infinity restart and the Pod would never
 start receiving traffic, 120s seems to be adequate for the moment, note that we used the same
 value for the shutdown (see: preStop in the lifecycle)

  All this definition is made in the Deployment artifacts.

# Important notes on ingresses rules

* We need to add the security headers to any new ingress we have, use the next state of code to do it, check the isse https://jira.statrad.com/browse/NIX-15478 for history of what it can cause.
Ideally this would be some templete we would replicate every where, for now we are "copy" and "pasting" it.
```
    # TODO
    # If you need to add more CSP info which is a certain deployment specific information,
    # please add it on deployment branch directly (e.g. hub/ hub3/ statrad etc.)
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: SAMEORIGIN";
      more_set_headers "Content-Security-Policy: default-src 'self' 'unsafe-inline' 'unsafe-eval' *.{{ deployDomain }} blob:; style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com; font-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.gstatic.com https://themes.googleusercontent.com http://themes.googleusercontent.com; connect-src 'self' https://dc.services.visualstudio.com/v2/track https://*.{{ deployDomain }} ws://*.{{ deployDomain }} wss://*.{{ deployDomain}} ws://localhost:* wss://localhost:* http://localhost:* http://localhost-1:* http://localhost-2:* http://localhost-3:* https://nucleussupport.wpengine.com:* https://dc.services.visualstudio.com; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.google.com/recaptcha/ https://www.gstatic.com/recaptcha/ blob:; frame-src 'self' https://www.google.com/recaptcha/; img-src 'self' blob: data: https://localhost:* https://localhost-1:* https://localhost-2:* https://localhost-3:*{{ frameAncestors }}";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "Referrer-Policy: no-referrer";
      more_set_headers "Feature-Policy: geolocation 'none'; midi 'none'; sync-xhr 'none'; microphone 'none'; camera 'none'; magnetometer 'none'; gyroscope 'none'; speaker 'self'; fullscreen 'self'; payment 'none'";
    nginx.ingress.kubernetes.io/server-snippet: |
      ssl_stapling on;
      ssl_stapling_verify on;
      resolver 8.8.8.8 8.8.4.4;

```

*frameAncestors* import information is an important for the environment  you can find that information in the issue :  (https://jira.statrad.com/browse/NIX-14955), for now the values we know it : 

```
   CSP frame-ancestors:
       https://concise-dev.vitalhealthsoftware.com/
       https://concise-test.vitalhealthsoftware.com/
       https://concise-stage.vitalhealthsoftware.com/
       https://concise-stage.medtronic.com/
       https://concise-demo.medtronic.com/
       https://www.conciseoutcomes.com
       https://concise-dev.medtronic.com

 
     AC:
 For Concise to test:

     https://concise-dev.vitalhealthsoftware.com/
     https://concise-stage.vitalhealthsoftware.com/
     https://concise-stage.medtronic.com/
     https://concise-demo.medtronic.com/
     https://www.conciseoutcomes.com
     https://concise-dev.medtronic.com
  For automated testing:
      https://jsfiddle.net 
      https://fiddle.jshell.net
```

* Body size: Most of nucleus endpoints receive a big request, consider setting big values for this property in the ingress configurations, e.g.: `nginx.ingress.kubernetes.io/proxy-body-size: 1g # To allow request up to 1g of body size.` 

* Connection timeout: Some requests to get or process images may take a long time to process, and that is expected, consider adding a big value and make sure it is big enough to handle a big request in a high load scenario. e.g: `nginx.ingress.kubernetes.io/proxy-connect-timeout: "70000" # Should not go over 75s see`

* Retry next POD in case of fail: Some request may fail for many reasons, in that case, we have a configuration that tries the next POD if one of them fail, you will find this definition in the `nginx.ingress.kubernetes.io/proxy-next-upstream` in each ingress, *IMPORTANT NOTE* we do not retry post, options and put request because they are dangerous and can lead into duplications, today we limit this retry to `3` different Pods check `nginx.ingress.kubernetes.io/proxy-next-upstream-tries` if you want to change this behavior. *Final note*: It is no different from build 2.0 releases as you can see in this link https://github.com/radconnectIT/Nucleus/blob/dev/master/devOps/library/configurators/nucleusLoadBalancerServerUploads/NucleusLoadBalancerServerTemplate.conf.j2#L31 we already use this nginx feature in the current deploy

* Cors configuration: Nginx has a cors configuration out of the box, we take advantages of that with the properties, `nginx.ingress.kubernetes.io/enable-cors: "true"` and `nginx.ingress.kubernetes.io/cors-allow-headers:` this is a point of attention to maintenance because if we add new headers, these configurations need to be updated in the deployment templates.

* Errors 502 with no know reason: 502 errors may happen because of several different reasons, (110: Operation timed out (slow backend), 111: Connection refused (wrong backend configuration), bad gateway (maybe high load) and others ) all the presented ones are easier to fix with configuration changes and scaling up. However, there is still one present in the logs like (104: Connection reset by peer) it is a standard error for PHP and Node applications, and it seems to be related to keep-alive feature between the proxy and the upstream(service), this one is harder to fix, we have faced this issue in the image data service upload endpoint (check the issue https://jira.statrad.com/browse/NIX-13213) ans we have fixed it changing the property `nginx.ingress.kubernetes.io/proxy-http-version: "1.0"` by default Nginx k8s controller uses the 1.1 version. Visit the PR https://github.com/radconnectIT/KNucleus-cs/pull/130 to see how we fixed that.

* Http2, nucleus image viewers use http2 to speed up the image loading, in the current implementation one singles browser or viewer client can open up to 700 simultaneous request to the server, Nginx or other ingresses use to have and small number for concurrent connect (Nginx is 1000), when a new connection is needed on old one will be close, that may present in the front end as "Connection reset" or "Http2::Connection reset", the way we fixed this was by increasing the number of connect and streams in Nginx that will result into using more memory on Nginx (see http://nginx.org/en/docs/http/ngx_http_v2_module.html#http2_max_requests for instance);
[Limitation] The current implication must support up to ~140 simultaneous big loading;  If you are seeing this error in some environment it may have gone over this limitation, consider implementing nginx auto scaling (See: https://jira.statrad.com/browse/NIX-14949). 



# Known possible problems
* *nodeSelector* is fixed for some services that are expected for some services, e.g.: monitoring (linkerd), but may not be the best for the nucleus services. During load test and Performance Tuning, we moved Chunk-frame-extraction and image-data-service to use any node with hardware available to run then, and they are moved if the node is running out of resources. The change in image-data-service resulted in a great impact in the ingestion speed, and the change to Chunk-frame resulted in an improvement in the ChunkJob processing and reduced the stress in the ingestion nodes improving, in consequence, the P10ChunkJob jobs.

 In future releases we intend to test the system without any *nodeSelector* fidelity. (No time to go over all the tests in 21 anymore)

* *Ingestion stop* or *Newly uploaded or ingested exam images are not available on the exam list*:
    We have this known problem where big or problematic uploads can cause the ingestion queues to be
    slow or stop.
    How to identify it is happening? 
        Using the ingestion database run the query 
```js
//Query
db.Imaging.FrameExtractionChunkJobs.jobs.aggregate([
        {
             "$project": {
                 "status": "$status",
                "event":1
            }
        },
        {
            $group: {
                    "_id": "$status",
                    "total":{ "$sum": 1}
                }
        },
    ]);
// Result example
{ "_id" : "running", "total" : 5 }
{ "_id" : "completed", "total" : 12375 }
{ "_id" : "ready", "total" : 1 }// This number should not be big, 
{ "_id" : "failed", "total" : 1 }
// And

db.Imaging.StudyUploadProcessingStatuses.count({unprocessedChunksCounter: { $gt:0}}) // This one also should be below 10 

```

Normally ready will be less than 10, when it is bigger then 100 we probably have a problem already 
during the problem registered in [NIX-15619](https://jira.statrad.com/browse/NIX-15619) there were
`{ "_id" : "ready", "total" : 319806 }`

*How to solve it?*
    1) When the queue is not too big(less then thousands) one possible solution is to increase the number of `chunk-frame-extraction` and what the number of jobs in the queues.
    2) Purging the queue also will solve the problem (There will be data loss here), for that use the queries:
```
db.Imaging.FrameExtractionChunkJobs.jobs.remove(<query for the jobs you want to clen>);
db.Imaging.StudyUploadProcessingStatuses.count({unprocessedChunksCounter: { $gt:0} ... });
``` 
    2.1) In some cases you will need to restart the pods after cleaning up the queue, for that use the follow command
```
    kubectl rollout restart deployment p10-accumulator -n nucleus
    kubectl rollout restart deployment chunk-frame -n nucleus
```
The point 1 is the preferential way of solving this problem since the 2 will lead to data loss and
we maybe need to resend the data latter.
Also read https://confluence.statrad.com/display/DevOps/Stalled+Study+Upload+Processing+Troubleshooting
for more information about this problem.

* *Kibana database gets corrupted or disk gets full*:  From time to time kibana is having problems and the database get corrupted (or something like that, we still need to investigate this deeper).  Next I will describe how to solve it if it happens and you need to fix it.
   1) Go to the environment branch e.g `git checkout Deployment/shared-services-qe` 
   2) Change local context to the deployment aks cluster `az aks get-credentials -g shared-services-qe -n shared-services-qe-aks  --admin`
   3) Delete the resources kibana +  elasticsearch from k8s (Do not worry the next step will
   recreate them all )

   ```
       cd deployment/projects/logging
       ./tearDownElasticsearch.sh # Check template branch if you do not find this script in your branch
   ```

   4) Run the manual build for the shared service (This step will take care of recreating all the
   resources you have deleted in the step 3). e.g: `open https://prod-cicd.nucleushealthdev.io/job/multi-env-cd/job/Deployment%252Fshared-services-qe/ <hit the button "Build now">`

   5) After that to start receiving data run:
   ```
    kubectl scale deployment -n logging fluentd-es --replicas=0
    kubectl scale deployment -n logging fluentd-es --replicas=1
   ```
* Current SystemEvents does not scale: We know the event system we have implemented today have scalability problems you can check that in
    2 points in code
    (https://github.com/radconnectIT/Nucleus/blob/0696b04ac186a5dc448bf2d1528229a0bc892be4/nodeModules/mubsub/lib/channel.js#L167) here in the lib and here(https://github.com/radconnectIT/Nucleus/blob/0696b04ac186a5dc448bf2d1528229a0bc892be4/appServer/Packages/system-events/services/subscribe.js#L173) in the application code. Basically what our system events do cam be described as: 
    1) It promotes a race between all the workers to pick the next work item, lets suppose we have 12 workers running (this is how this is today)
    2) All the workers will receive every the items and try to `Claime` it to do sending an insert command to mongo. 
    3) Out of the 12 workers 11 will thrown an error and 1 will successfully `claime` the work to do. Mongo deals with the concurrency problem here with an unic index.
    4) Workers pick work to do even if they are busy.
    5) Workers keep the items in processing state in memory (If they restart there is no retry we lost that items)
Reading the flow above, note that scaling horizontally the workers will make the "fight" for the work item worse (not better), so thing twice before increasing the number of backgroud-processors (We intend to eliminate this limitation in the next version with Azure Service Bus).
Based on the calculations we have made in our load test the current system events is good enough for the  current load but it is easy to break it if we grown the processing too much. But we also do not want the backgroud-processors to restart and if they do we need to investigate why and mitigate the problem.

* In version 20.*  image data service and edge server ddp have a memory leak, the current configuration is made to deal with that, but it may result into more Pods been restarted during the day. 

* Today, our ingestpool has the max of 28G of memory been composed of two servers of 14G each, and Only the chunk-frame-extraction can use up to 32G of memory, and those same nodes still run p10-accumulator, p10-chunk and study-rollup (That can also go up to 72G of memory).  In some situational on a memory stress in the ingestion pool for example if chunk-frame-extraction or study-rollup eats all the memory from the node, we may get into a situation where k8s cannot schedule any other pods to that nodes, and we can get to a state where there is 0 process of p10-chunk, chunk-frame-extraction, p10-accumulator, and even study-rollup running for a long period.

* Linkerd prometheus uses a lot of resources currently we are running it in the default node (where k8s administrative tools runs), this is not a standard configuration, so we do not yet know the implications of that in the production like traffic, during the load test lots of times we found prometheus using all memory in the node it was running and even alerting resource usage on azure, that also cause the linkerd to stop working, and during the high load, we could not analyze the metrics on linkerd. In the current configuration, prometheus does not horizontal scale in a future fix for this we may use this tutorial to make scale with us https://www.robustperception.io/scaling-and-federating-prometheus


## Current terraform limitations

* Node pool name: terraform azure k8s node pool has a limitation of 12 characters long, but using 12 characters, there will not be any validation errors, the creation will fail, and in the end, there will be a ghost node with a truncated name of `11` characters. *Important* Node Pool cannot have a name longer than 11 characters for windows nodes that limitations go down to 6 characters.

* Resizing an node pool by terraform will make all nodes of that node pool to go down

* If you rename some pool we end up with ghost pools with the old name (Need to be manual deleted after the update to delete use the command ` az vmss delete --name $node-pool-name -g $resource-group-name`) 


## Current infra services nodes and configurations 

Note: All services are showing the max resource * the number of replicas


# How to make general evolutions in CD Pipeline

Update the template `tools/templates/dev.jenkinsfile.j2` to normal deploy and `tools/templates/sharedServices.dev.jenkinsfile.j2` for shared service, in the template branch. Follow the next section to test in the deployment branch.

## How to update Jenkins.dev file into your Deployment branch

1) Pull from template branch `git pull origin nk8s_template`
2) Start the provisioner `cd projects/provisioner/&&vagrant up`
3) Ssh to the vagrant machine  `vagrant ssh`
4) In the vagrant machine go to ` cd /Deployment/ `
5) login into azure `az login`
6) Source the secrets file `source ./extract-secrets.sh --silent`
7) Run the update script. `/KNucleus-cs/tools/update-jenkins.sh`



````

# Run the two most heavy services edge-server-ddp, and image-data-service both have to know memory leak problems, and that is why they are the only ones with auto-scaling configurations

+-----------------------------------------------------------------------+
|                                                                       |
|                                                                       |
|                           dataprocpool (4)                            |
|                            Standard_DS4_v2                            |
|                                112 GB                                 |
|                                32 CPU                                 |
|                                                                       |
+---------------------------------+   +---------------------------------+
|       edge-server-ddp (8 - 32)  |   |     image-data-service (12 - 48)|
|     Max: 16 GB / Each: 2 GB     |   |     Max: 24 GB / Each: 2 GB     |
|    Max: 16 CPU / Each: 2 CPU    |   |    Max: 24 CPU / Each: 2 CPU    |
+---------------------------------+   +---------------------------------+
|                                                                       |
|                                                                       |
|                                                                       |
+-----------------------------------------------------------------------+


# This node runs all the k8s administrative services + linkerd related ones. We omitted them here because they are more than ten different services; the visualization would not be good.

+-----------------------------------------------------------------------+
|                                                                       |
|                                                                       |
|                             default (2)                               |
|                           Standard_DS11_v2                            |
|                                 28 GB                                 |
|                                 4 CPU                                 |
|                                                                       |
|                                                                       |
|                                                                       |
|                                                                       |
+-----------------------------------------------------------------------+


# Ingestion pool (shorted name because of pool name limitations), here we have a resource allocation problem to be addressed soon check the known problem section

+-----------------------------------------------------------------------+
|                                                                       |
|                                                                       |
|                            ingestpool (2)                             |
|                            Standard_DS3_v2                            |
|                                 28 GB                                 |
|                                 8 CPU                                 |
|                                                                       |
+---------------------------------+   +---------------------------------+
|   chunk-frame-extraction (8)    |   |       p10-accumulator (3)       |
|     Max: 32 GB / Each: 4 GB     |   |     Max: 6 GB / Each: 2 GB      |
|    Max: 16 CPU / Each: 2 CPU    |   |    Max: 3 CPU / Each: 1 CPU     |
+---------------------------------+   +---------------------------------+
+---------------------------------+   +---------------------------------+
|         p10-chunk (12)          |   |        study-rollup (12)        |
|     Max: 24 GB / Each: 2 GB     |   |     Max: 72 GB / Each: 6 GB     |
|    Max: 12 CPU / Each: 1 CPU    |   |    Max: 12 CPU / Each: 1 CPU    |
+---------------------------------+   +---------------------------------+
|                                                                       |
|                                                                       |
|                                                                       |
+-----------------------------------------------------------------------+




# Ui pool (To run all the user-facing ui services)

+-----------------------------------------------------------------------+
|                                                                       |
|                                                                       |
|                              uipool (2)                               |
|                            Standard_DS3_v2                            |
|                                 28 GB                                 |
|                                 8 CPU                                 |
|                                                                       |
+---------------------------------+   +---------------------------------+
|    image-viewer-service (3)     |   |       meteor-ui-ddp (12)        |
|     Max: 6 GB / Each: 2 GB      |   |     Max: 48 GB / Each: 4 GB     |
|    Max: 6 CPU / Each: 2 CPU     |   |    Max: 24 CPU / Each: 2 CPU    |
+---------------------------------+   +---------------------------------+
|                                                                       |
|                                                                       |
|                                                                       |
+-----------------------------------------------------------------------+
                                                                                                                                                                                  
```

