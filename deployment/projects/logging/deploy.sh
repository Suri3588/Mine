#!/bin/bash

if [ "$1" == "--continue-on-failure" ] || [ "$1" == "-c" ] ; then
  CONTINUE_ON_FAILURE=true
else
  CONTINUE_ON_FAILURE=false
fi

FAILURE_COUNT=0
NAMESPACE="logging"
MASTER_NODE_COUNT=$esMasterNodeCount
DATA_NODE_COUNT=$esDataNodeCount

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
pushd $scriptDir

# Create temp dir and cleanup hook.
TMP_DIR="/dev/shm/deploy.$$"
trap "rm -rf $TMP_DIR" EXIT
mkdir "$TMP_DIR"

logError() {
  local MESSAGE="$1"

  if test -t 1 ; then
    echo -e "\033[01;31mError:\033[00m $MESSAGE" 1>&2
  else
    echo "Error: $MESSAGE" 1>&2
  fi
}

checkExitCode() {
  local EXIT_CODE=$1
  local ERROR_MSG="$2"

  if [ $EXIT_CODE -ne 0 ]; then
    logError "$ERROR_MSG"
    FAILURE_COUNT=$(( $FAILURE_COUNT + 1 ))

    if [ $CONTINUE_ON_FAILURE == false ] ; then
      popd
      exit $EXIT_CODE
    fi
  fi
}

isElasticSearchRunning() {
    [[ "Running" == "`kubectl get pods -n $NAMESPACE | grep elasticsearch | awk '{print $3}' | sort -u`" ]]
}

addFileSecret() {
    local SECRET_NAME="$1"
    local FILE_PATH="$2"
    local FILE_KEY="$3"   # Optional
    
    local ACTION_1="Creating"
    local ACTION_2="create"

   kubectl --namespace=$NAMESPACE get secrets $SECRET_NAME > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        ACTION_1="Updating"
        ACTION_2="update"
    fi

    echo "$ACTION_1 '$SECRET_NAME' secret..."

    if [ -z "$FILE_KEY" ]; then
        kubectl --namespace $NAMESPACE create secret generic $SECRET_NAME --from-file="$FILE_PATH" --dry-run -o yaml | kubectl apply -f -
    else
        kubectl --namespace $NAMESPACE create secret generic $SECRET_NAME --from-file=$FILE_KEY="$FILE_PATH" --dry-run -o yaml | kubectl apply -f -
    fi

    checkExitCode $? "Unable to $ACTION_2 $SECRET_NAME secret."
}

renderElastalertRule() {
    local RULE_TYPE="$1"        # pagerduty or sendgrid
    local RULE_FILENAME="$2"
    local PAGER_DUTY_KEY="$3"   # Only needed if RULE_TYPE == pagerduty

    mkdir -p "$TMP_DIR/elastalertRules"

    cat "alerts-elastalert/$RULE_FILENAME" > "$TMP_DIR/elastalertRules/$RULE_FILENAME"

    if [ "$RULE_TYPE" == "sendgrid" ]; then
        echo 'alert:' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo '- "email"' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo 'email:' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo "- \"$esPrimaryAlertEmail\"" >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo 'from_addr: "no_replies@nucleushealth.io"' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo 'smtp_host: "smtp.sendgrid.net"' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo 'smtp_port: "587"' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo 'smtp_auth_file: "/opt/config/elastalert-smtp-config.yaml"' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
    elif [ "$RULE_TYPE" == "pagerduty" ]; then
        echo 'alert:' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo '- "pagerduty"' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo 'pagerduty:' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo "pagerduty_service_key: \"$PAGER_DUTY_KEY\"" >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo 'pagerduty_client_name: "ElastAlert"' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo 'pagerduty_event_type: "trigger"' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
        echo 'pagerduty_api_version: "v2"' >> "$TMP_DIR/elastalertRules/$RULE_FILENAME"
    fi
}

createElastalertRules() {
    local SECRET_NAME="elastalert-rules"
    local ACTION_1="Creating"
    local ACTION_2="create"
    local RULES_FILE
    local RULES_KEY

    kubectl --namespace=$NAMESPACE get secrets $SECRET_NAME > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        ACTION_1="Updating"
        ACTION_2="update"
    fi

    echo "$ACTION_1 '$SECRET_NAME' secret..."

    mkdir -p "$TMP_DIR/elastalertRules"  # This should exist, but this fails gracefully if not.
    pushd "$TMP_DIR/elastalertRules"
    tar cvzf /dev/shm/lastRules.tgz *     # DELETE ME BEFORE CHECK-IN.

	local CREATE_COMMAND="kubectl --namespace $NAMESPACE create secret generic $SECRET_NAME"

    while read RULES_FILE
    do
        RULES_KEY=${RULES_FILE%.*}
        CREATE_COMMAND="$CREATE_COMMAND --from-file=$RULES_KEY=./$RULES_FILE"
    done < <( ls )

    eval "$CREATE_COMMAND --dry-run -o yaml | kubectl apply -f -"
	checkExitCode $? "Unable to $ACTION_2 $SECRET_NAME secret."

    popd   # /KNucleus-cs/deployment/projects/logging
}

# Setup namespace
echo "Installing $NAMESPACE namespace"
kubectl apply -f namespace.yaml
checkExitCode $? "Unable to apply $NAMESPACE namespace."


# Setup secrets
kubectl --namespace=$NAMESPACE get secrets grafana > /dev/null
if [ $? -ne 0 ]; then
  kubectl --namespace=$NAMESPACE create secret generic grafana --from-literal=admin-password="$grafanaAdminPassword" --from-literal=ldap-toml=""
  checkExitCode $? "Unable to upload grafanaAdminPassword."
fi

kubectl --namespace=$NAMESPACE get secrets elasticsearch > /dev/null
if [ $? -ne 0 ]; then
  kubectl --namespace=$NAMESPACE create secret generic elasticsearch --from-literal=elasticsearch-password="$elasticsearchPassword" --from-literal=elasticsearch-read-only-password="$elasticsearchReadOnlyPassword" --from-literal=kibana-password="$kibanaPassword" --from-literal=kibana-admin-password="$kibanaAdminPassword" --from-literal=beats-password="$beatsPassword"
  checkExitCode $? "Unable to upload elasticsearch passwords."
fi

kubectl --namespace=$NAMESPACE get secrets alerts > /dev/null
if [ $? -ne 0 ]; then
  kubectl --namespace=$NAMESPACE create secret generic alerts --from-literal=sendmailAPIKey="$sendmailAPIKey" --from-literal=pagerDutyKeyGeneral="$pagerDutyKeyGeneral"
  checkExitCode $? "Unable to upload alert keys."
fi

kubectl --namespace=$NAMESPACE get secrets tls-certificate
if [ $? -ne 0 ]; then
  kubectl get secret tls-certificate --namespace=ingress-nginx --export -o yaml | \
    kubectl apply --namespace=$NAMESPACE -f -

  checkExitCode $? "Unable to apply secret."
fi

# Create secret-safe configs.
sed "s/ELASTICSEARCH_PASSWORD/$elasticsearchPassword/" config-templates/curator.yml > "$TMP_DIR/curator.yml"
sed "s/ELASTICSEARCH_PASSWORD/$elasticsearchPassword/" config-templates/fluent-output.conf > "$TMP_DIR/output.conf"
sed "s/ELASTICSEARCH_PASSWORD/$elasticsearchPassword/" config-templates/grafana-datasources.yaml > "$TMP_DIR/datasources.yaml"
sed "s/ELASTICSEARCH_PASSWORD/$elasticsearchPassword/" config-templates/kibana.yml > "$TMP_DIR/kibana.yml"
sed "s/ELASTICSEARCH_PASSWORD/$elasticsearchPassword/" config-templates/elastalert_config.yaml > "$TMP_DIR/elastalert_config.yaml"
sed "s/SENDMAIL_API_KEY/$sendmailAPIKey/" config-templates/elastalert-smtp-config.yaml > "$TMP_DIR/elastalert-smtp-config.yaml"
sed "s/SENDMAIL_API_KEY/$sendmailAPIKey/" config-templates/alertmanager-config.yaml > "$TMP_DIR/config.yml"
sed "s/BEATS_PASSWORD/$beatsPassword/" config-templates/metricbeat.yml > "$TMP_DIR/metricbeat.yml"

addFileSecret "curator-config" "$TMP_DIR/curator.yml"
addFileSecret "fluent-output-config" "$TMP_DIR/output.conf"
addFileSecret "grafana-datasources-config" "$TMP_DIR/datasources.yaml"
addFileSecret "kibana-config" "$TMP_DIR/kibana.yml"
addFileSecret "metricbeat-config" "$TMP_DIR/metricbeat.yml" "metricbeat.yml"
addFileSecret "elastalert-config" "$TMP_DIR/elastalert_config.yaml"
addFileSecret "elastalert-smtp-config" "$TMP_DIR/elastalert-smtp-config.yaml"
addFileSecret "alertmanager-config" "$TMP_DIR/config.yml"

# Install elasticsearch
echo "Installing elasticsearch cluster"
MASTER_NODE_LIST=""
for (( c=0; c<$MASTER_NODE_COUNT; c++ ))
do
	if [ -z "$MASTER_NODE_LIST" ]; then
		MASTER_NODE_LIST="elasticsearch-master-$c"
	else
		MASTER_NODE_LIST="$MASTER_NODE_LIST,elasticsearch-master-$c"
	fi
done

NODE_LIST="$MASTER_NODE_LIST"
for (( c=0; c<$DATA_NODE_COUNT; c++ ))
do
	NODE_LIST="$NODE_LIST,elasticsearch-data-$c.elasticsearch-data.$NAMESPACE.svc.cluster.local"
done

NODE_LIST="$NODE_LIST,elasticsearch-client"

# Create service account, if it doesn't already exist.
if ! kubectl get serviceaccounts -n $NAMESPACE | grep -q sa-elasticsearch ; then
    echo "Creating 'sa-elasticsearch' service account"
    kubectl create serviceaccount sa-elasticsearch -n $NAMESPACE
    checkExitCode $? "Unable to create service account."
else
    echo "Service account 'sa-elasticsearch' already exists."
fi

echo "Installing elasticsearch RBAC"
kubectl apply -f elasticsearch-10-rbac.yml
checkExitCode $? "Unable to apply elasticsearch RBAC."
echo "Installing elasticsearch client service"
kubectl apply -f elasticsearch-20-client-service.yml
checkExitCode $? "Unable to apply elasticsearch client service."
echo "Installing elasticsearch data service"
kubectl apply -f elasticsearch-21-data-service.yml
checkExitCode $? "Unable to apply elasticsearch data service."

for (( c=0; c<$MASTER_NODE_COUNT; c++ ))
do
    echo "Installing elasticsearch master service ($(( $c + 1 ))/$MASTER_NODE_COUNT)"
    sed "s/ORDINAL/$c/g" elasticsearch-22-master-service-template.yml > elasticsearch-22-master-service-$c.yml
    kubectl apply -f elasticsearch-22-master-service-$c.yml
    checkExitCode $? "Unable to apply elasticsearch master-$c service."
done

echo "Installing elasticsearch data stateful set"
sed -i "s/NODE_LIST_VALUES/$NODE_LIST/" elasticsearch-30-statefulset-data.yml
sed -i "s/MASTER_NODES_VALUES/$MASTER_NODE_LIST/" elasticsearch-30-statefulset-data.yml
kubectl apply -f elasticsearch-30-statefulset-data.yml
checkExitCode $? "Unable to apply elasticsearch data stateful set."

for (( c=0; c<$MASTER_NODE_COUNT; c++ ))
do
    echo "Installing elasticsearch master node ($(( $c + 1 ))/$MASTER_NODE_COUNT)"
    sed "s/ORDINAL/$c/g;s/NODE_LIST_VALUES/$NODE_LIST/;s/MASTER_NODES_VALUES/$MASTER_NODE_LIST/" elasticsearch-40-deployment-master-template.yml > elasticsearch-40-deployment-master-$c.yml
    kubectl apply -f elasticsearch-40-deployment-master-$c.yml
    checkExitCode $? "Unable to apply elasticsearch master-$c."
done

echo "Installing elasticsearch client node"
sed -i "s/NODE_LIST_VALUES/$NODE_LIST/" elasticsearch-60-deployment-client.yml
sed -i "s/MASTER_NODES_VALUES/$MASTER_NODE_LIST/" elasticsearch-60-deployment-client.yml
kubectl apply -f elasticsearch-60-deployment-client.yml
checkExitCode $? "Unable to apply elasticsearch client."

# Applying elasticsearch ingress rule
./applyElasticsearchIngress.sh
checkExitCode $? "Unable to apply elasticsearch ingress rule."


# Install additional products
echo "Installing fluentd"
# TODO: wire in an azure file storage account for linkerd long term storage
#kubectl apply -f $deploymentDir/$secretsDir/azure-files-fluentd-secret.yaml
checkExitCode $? "Unable to apply fluentd secrets."
kubectl apply -f fluentd.yaml
checkExitCode $? "Unable to apply fluentd."

echo "Creating grafana dashboards config map"
kubectl delete configmap grafana-dashboards -n $NAMESPACE 2> /dev/null
kubectl create configmap grafana-dashboards -n $NAMESPACE --from-file=grafana-dashboard-json
checkExitCode $? "Unable to create grafana dashboards config map."

echo "Installing grafana"
kubectl apply -f grafana.yaml
checkExitCode $? "Unable to apply grafana."

echo "Installing kibana"
kubectl apply -f kibana.yaml
checkExitCode $? "Unable to apply kibana."

echo "Installing metricbeat"
kubectl apply -f metricbeat.yaml
checkExitCode $? "Unable to apply metricbeat."

echo "Installing prometheus rule"
kubectl apply -f prometheus.yaml
checkExitCode $? "Unable to apply prometheus."

echo "Installing kube-state-metrics"
kubectl apply -f kube-state-metrics/
checkExitCode $? "Unable to apply kube-state-metrics."

echo "Installing ElasticSearch curator CronJob to keep history properly cleaned"
kubectl apply -f curator.yaml
checkExitCode $? "Unable to apply curator."

# Wait for elasticsearch to come up, before setting up users.
echo -n "Waiting for elasticsearch cluster to come online..."
MAX_WAIT_TIME=1200 # 20 minutes
WAIT_TIME=0
while ! isElasticSearchRunning ; do
    echo -n "."
    sleep 10
    WAIT_TIME=$(( $WAIT_TIME + 10 ))
    if [ $WAIT_TIME -eq $MAX_WAIT_TIME ]; then
        logError "The elasticsearch cluster never came online."
		exit 1
    fi
done
echo

# Leaving the following in and commenting, just in case we swtich back, in the near future.
# Set up the bootstrap password.
#echo "Configuring elasticsearch bootstrap password..."
#CLIENT_POD=`kubectl get pods -n logging | grep elasticsearch-client | head -1 | awk '{print $1}'`
#if [ -n "$CLIENT_POD" ]; then
#    echo "$elasticsearchBootstrapPassword" | kubectl exec -n logging $CLIENT_POD -- /usr/share/elasticsearch/bin/elasticsearch-keystore add -xf "bootstrap.password"
#    checkExitCode $? "Unable to configure elasticsearch bootstrap password."
#else
#    logError "Could not find the elasticsearch-client pod."
#    exit 1
#fi

# Change elasticsearch password.
#CLIENT_POD=`kubectl get pods -n logging | grep elasticsearch-client | head -1 | awk '{print $1}'`
#kubectl exec -it -n logging $CLIENT_POD -- curl -s -u "elastic:$elasticsearchReadWritePassword" http://localhost:9200/_security/user/elastic | grep -q security_exception
#if [ $? -eq 0 ]; then
#    # Looks like the password was never setup before.
#    echo "Configuring elasticsearch read/write password..."
#    kubectl exec -it -n logging $CLIENT_POD -- curl -s -H 'Content-Type: application/json' -u "elastic:$elasticsearchBootstrapPassword" http://localhost:9200/_security/user/elastic/_password -d '{ "password" : "$elasticsearchReadWritePassword" }' | grep -q "{}"
#    checkExitCode $? "Unable to setup elasticsearch read/write password."
#else
#    echo "Elasticsearch read/write password already set up."
#fi

# Change kibana password.
#CLIENT_POD=`kubectl get pods -n logging | grep elasticsearch-client | head -1 | awk '{print $1}'`
#kubectl exec -it -n logging $CLIENT_POD -- curl -s -u "kibana:$kibanaPassword" http://localhost:9200/_cluster/health | grep -q security_exception
#if [ $? -eq 0 ]; then
#    # Looks like the password was never setup before.
#    echo "Changing kibana password..."
#    kubectl exec -it -n logging $CLIENT_POD -- curl -s -H 'Content-Type: application/json' -u "elastic:$elasticsearchPassword" http://localhost:9200/_security/user/kibana/_password -d '{ "password" : "$kibanaPassword" }' | grep -q "{}"
#    checkExitCode $? "Unable to change kibana password."
#else
#    echo "Kibana password already set up."
#fi

# Setup users and roles.
echo "Setting up users and roles..."
./scripts/elasticsearch/setupUsersAndRoles.sh
checkExitCode $? "Unable to setup users and roles."

echo "Loading elasticsearch pipelines..."
./scripts/elasticsearch/loadPipelines.sh
checkExitCode $? "Unable to load elasticsearch pipelines."

echo "Configuring kibana..."
./scripts/elasticsearch/configureKibana.sh
checkExitCode $? "Unable to configure kibana."

if [ "$isProduction" == "true" ]; then
    IMPORTANT_RULE_TYPE="pagerduty"
else
    IMPORTANT_RULE_TYPE="sendgrid"
fi

echo "Creating elastalert rules secrets..."
renderElastalertRule "sendgrid"  "chunkCount-1K.yaml"
renderElastalertRule "$IMPORTANT_RULE_TYPE" "chunkCount-3K.yaml" "$pagerDutyKeyGeneral"
renderElastalertRule "$IMPORTANT_RULE_TYPE" "Mongo-Fatal-Error.yaml" "$pagerDutyKeyGeneral"
renderElastalertRule "$IMPORTANT_RULE_TYPE" "pm2-restartloopalert-edgeservers.yaml" "$pagerDutyKeyGeneral"
createElastalertRules
checkExitCode $? "Unable to create elastalert rules secrets."

echo "Installing elastalert..."
kubectl apply -f elastalert.yaml
checkExitCode $? "Unable to install elastalert."

echo "Installing prometheus alert manager..."
kubectl apply -f alertmanager.yaml
checkExitCode $? "Unable to install prometheus alert manager."

popd

if [ $FAILURE_COUNT -gt 0 ]; then
    if [ $FAILURE_COUNT -gt 1 ]; then
        logError "There were $FAILURE_COUNT failures encountered during the deploy."
    else
        logError "A failure occured during the deploy." 1>&2
    fi

    exit 1
else
    if test -t 1 ; then
       echo -e "\033[01;32mSuccess.\033[00m"
    else
        echo "Success."
    fi
fi
