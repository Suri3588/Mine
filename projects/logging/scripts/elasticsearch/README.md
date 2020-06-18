# Elasticsearch Scripts

Scripts for mananging an elasticsearch deployment.

Make sure that you're in the correct kubernetes context, for the shared services
deployment, that you wish to perform these operations on. You will also want
to run:
```
. ./extract-secrets.sh /Deployment/secret-vars.txt
```
...to set the 'elasticsearchPassword', that will be required by these
scripts (or just set that one variable manually).

## Inspection

Scripts for showing the state of an elasticsearch cluster.

### checkClusterHealth.sh

Provides a general report on the health of an elasticsearch cluster. A healthy cluster
should report 'green'. However, if this is a small test cluster, with a 'esMasterNodeCount'
less than three, then it will never report 'green', only 'yellow' (not enough master nodes
to elect a new primary, if one goes down).

### listDashboards.sh

Lists all of the dashboard, by ID and title, in kibana.

```
./listDashboards.sh
./listDashboards.sh --ids-only
```

### listIndexPatterns.sh

Lists all of the index patterns, by ID and title, in kibana.

```
./listIndexPatterns.sh
./listIndexPatterns.sh --ids-only
```

### listVisualizations.sh

Lists all of the visualizations, by ID and title, in kibana.

```
./listVisualizations.sh
./listVisualizations.sh --ids-only
```

### showDashboard.sh

Dumps the JSON, for a kibana dashboard, to standard out.

```
./showDashboard.sh K8S-Top-Error-Messages
```

### showIndexPattern.sh

Dumps the JSON, for a kibana index pattern, to standard out.

```
./showIndexPattern.sh Filebeat-Star
```

### showVisualization.sh

Dumps the JSON, for a kibana visualization, to standard out.

```
./showVisualization.sh Mongo-Early-Warnings
```

## Persistence

### Saving

Use these scripts to save kibana saved-objects, to the local git branch. The
best way to do this is to first change to the shared services context, that you
want to import from, run extract-secrets, from the relevant branch (or make
sure your 'elasticsearchPassword' ENV var is set), and then change to the
branch that you want to save into, before running these scripts.

#### saveDashboard.sh

Download and save a dashboard to the following locations:

```
/KNucleus-cs/projects/logging/kibana-dashboards-json
/KNucleus-cs/deployment/projects/logging/kibana-dashboards-json
```

Note: If the /KNucleus-cs/deployment/projects/logging does not exist, nothing will be saved there.

Example:
```
./saveDashboard.sh K8S-Top-Error-Messages
./saveDashboard.sh --recurse K8S-Top-Error-Messages
```

If '--recurse' is specified (or '-r'), then any objects, referenced by this dashboard, will also be saved.

#### saveIndexPattern.sh

Download and save an index pattern to the following locations:

```
/KNucleus-cs/projects/logging/kibana-index-patterns-json
/KNucleus-cs/deployment/projects/logging/kibana-index-patterns-json
```

Note: If the /KNucleus-cs/deployment/projects/logging does not exist, nothing will be saved there.

Example:
```
./saveIndexPattern.sh Metricbeat-Star
./saveIndexPattern.sh --recurse Logstash-Star
```

If '--recurse' is specified (or '-r'), then any objects, referenced by this index pattern, will also be saved.

#### saveVisualization.sh

Download and save a visualization to the following locations:

```
/KNucleus-cs/projects/logging/kibana-visualizations-json
/KNucleus-cs/deployment/projects/logging/kibana-visualizations-json
```

Note: If the /KNucleus-cs/deployment/projects/logging does not exist, nothing will be saved there.

Example:
```
./saveVisualization.sh App-Errors
./saveVisualization.sh --recurse Nucleus-Top-Ten-Error-Messages
```

If '--recurse' is specified (or '-r'), then any objects, referenced by this visualization, will also be saved.

#### saveAllObjects.sh

Do not use this script lightly. This will save all kibana index patterns,
visualizations, and dashboards. If used on a virgin system, with only your
own changes, that should be fine. If other people have been experimenting
on this deployment, you many inadvertently commit their changes as well.

All this script does is save the ndjson, for every object, in these locations:

```
/KNucleus-cs/projects/logging/kibana-dashboards-json
/KNucleus-cs/projects/logging/kibana-index-patterns-json
/KNucleus-cs/projects/logging/kibana-visualizations-json
```

And if you have a '/KNucleus-cs/deployment/projects/logging' directory (ie. a
rendered deployment), then they will be copied under there, as well.

Review the modified and/or uncommitted files, to make sure that what you're about
to commit, makes sense.

### Importation

Scripts to import kibana saved objects, in ndjson format.

#### importKibanaSavedObject.sh

Passing in an 'ndjson' file, to this script, will attempt to import a saved object
into Kibana.

```
./importKibanaSavedObject.sh ./logging/kibana-visualizations-json/nucleus-mongo-early-warnings-log-entries.ndjson
```

#### importAllKibanaSavedObjects.sh

This will import all index patterns, visualizations and dashboards, into
Kibana, from the following relative directory locations:

```
../../kibana-dashboards-json
../../kibana-index-patterns-json
../../kibana-visualizations-json
```

So, if you can run the script from either of these locations:

```
/KNucleus-cs/projects/logging/scripts/elasticsearch
/KNucleus-cs/deployment/projects/logging/scripts/elasticsearch
```

You do not necessarily have to have a deployment directory.
Note that all existing objects will be overwritten.

## Troubleshooting

### rescaleElasticsearch.sh

Rescales all of the elasticsearch pods.

### tearDownElasticsearch.sh

Not in this dir :), two dirs up. Deletes all elasticsearch kubernetes pods.
This should be followed up by a "deploy.sh" to rebuild elasticsearch/kibana
from the ground up. Data will be lost, but this may be necessary to repair
some problems.

