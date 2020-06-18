#!/bin/bash
env=$1
classCPlus=$2
ip=$3
login=$4
spkf=$5
mapwd=$6
mupwd=$7
dbName=$8
mmv=$9
classCPlusOffset=${10}
fluentdHost=${11}
fluentdPort=${12}
resourceName=${13}
mepwd=${14}

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
if [ "$scriptDir" == /Users/* ]; then
  nucleusHome="$(cd $scriptDir/../../../../../../.. >/dev/null & pwd)"
else
  nucleusHome="/Nucleus"
fi

echo "{" > $scriptDir/mongoRsAnsible/vars.json
echo "  \"NUCLEUS_HOME\": \"$nucleusHome\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"jumpIp\": \"$ip\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"classCPlus\": \"$classCPlus\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"classCPlusOffset\": \"$classCPlusOffset\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"dbName\": \"$dbName\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"mongo_major_version\": \"$mmv\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"login\": \"$login\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"sshKeyFile\": \"$spkf\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"fluentdHost\": \"$fluentdHost\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"fluentdPort\": \"$fluentdPort\"," >> $scriptDir/mongoRsAnsible/vars.json
echo "  \"resourceName\": \"$resourceName\"" >> $scriptDir/mongoRsAnsible/vars.json
echo "}" >> $scriptDir/mongoRsAnsible/vars.json

echo "{" > $scriptDir/mongoRsAnsible/replVars.json
echo "  \"login\": \"$login\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"databaseName\": \"$dbName\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"classCPlus\": \"$classCPlus\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"classCPlusOffset\": \"$classCPlusOffset\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"parentHosts\": [" >> $scriptDir/mongoRsAnsible/replVars.json
echo "    {" >> $scriptDir/mongoRsAnsible/replVars.json
echo "      \"name\": \"mongo1\"" >> $scriptDir/mongoRsAnsible/replVars.json
echo "    },{" >> $scriptDir/mongoRsAnsible/replVars.json
echo "      \"name\": \"mongo2\"" >> $scriptDir/mongoRsAnsible/replVars.json
echo "    },{" >> $scriptDir/mongoRsAnsible/replVars.json
echo "      \"name\": \"mongo3\"" >> $scriptDir/mongoRsAnsible/replVars.json
echo "    }" >> $scriptDir/mongoRsAnsible/replVars.json
echo "  ]," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"skipOpLog\": \"true\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"mongoDbPort\": \"27017\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"mongoReplicaSetName\": \"rs-$dbName\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"secrets\": {" >> $scriptDir/mongoRsAnsible/replVars.json
echo "    \"mongoAdminUsername\": \"admin\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "    \"mongoAdminPassword\": \"$mapwd\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "    \"mongoUsername\": \"application\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "    \"mongoPassword\": \"$mupwd\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "    \"mongoExporterUsername\": \"mongodb_exporter\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "    \"mongoExporterPassword\": \"$mepwd\"" >> $scriptDir/mongoRsAnsible/replVars.json
echo "  }," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"hostSubstitution\": \"{{ inventory_hostname }}\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"mongo_major_version\": \"4.0\"," >> $scriptDir/mongoRsAnsible/replVars.json
echo "  \"featureCompatibilityVersion\": \"4.0\"" >> $scriptDir/mongoRsAnsible/replVars.json
echo "}" >> $scriptDir/mongoRsAnsible/replVars.json

pushd $scriptDir/mongoRsAnsible
echo "Creating Provisioning Set-Up..."
ansible-playbook -i localhost, playbook.yml --extra-vars "@vars.json"
popd

pushd $scriptDir/mongo
echo "Provisioning Mongo Replicaset"
ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i localhost,  waitForBoxen.yml 
ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory -l mongo mongo.yml
ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory -l jump upload.yml
ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory -l jump tasks.final.yml
ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i inventory -l mongo monitoring.yml
popd
