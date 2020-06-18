#!/bin/bash

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    return
fi

if [ -z "$secretsDir" ]; then
    echo "No Secrets directory specified in secret-vars.txt"
    return
fi

NAMESPACE="default"
SERVICE_ACCOUNT_NAME=api-deployment-account
KUBECFG_FILE_NAME="$deploymentDir/$secretsDir/k8s-conf"

get_secret_name_from_service_account() {
    echo "Getting secret of service account ${SERVICE_ACCOUNT_NAME} on ${NAMESPACE}..."
    SECRET_NAME=$(kubectl get sa "${SERVICE_ACCOUNT_NAME}" --namespace="${NAMESPACE}" -o json | jq -r .secrets[].name)
    echo "Secret name: ${SECRET_NAME}"
}

extract_ca_crt_from_secret() {
    echo "Extracting ca.crt from secret..."
    kubectl get secret --namespace "${NAMESPACE}" "${SECRET_NAME}" -o json | jq -r '.data["ca.crt"]' | base64 -d > "$deploymentDir/$secretsDir/k8s-ca.crt"
}

get_user_token_from_secret() {
    echo "Getting user token from secret..."
    USER_TOKEN=$(kubectl get secret --namespace "${NAMESPACE}" "${SECRET_NAME}" -o json | jq -r '.data["token"]' | base64 -d)
}

set_kube_config_values() {
    CONTEXT=$(kubectl config current-context)
    echo "Setting current context to: $CONTEXT"

    CLUSTER_NAME=$(kubectl config get-contexts "$CONTEXT" | awk '{print $3}' | tail -n 1)
    echo "Cluster name: ${CLUSTER_NAME}"

    ENDPOINT=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"${CLUSTER_NAME}\")].cluster.server}")
    echo "Endpoint: ${ENDPOINT}"

    echo "Setting a cluster entry in kubeconfig..."
    kubectl config set-cluster "${CLUSTER_NAME}" \
      --kubeconfig="${KUBECFG_FILE_NAME}" \
      --server="${ENDPOINT}" \
      --certificate-authority="$deploymentDir/$secretsDir/k8s-ca.crt" \
      --embed-certs=true

    echo "Setting token credentials entry in kubeconfig..."
    kubectl config set-credentials \
      "${SERVICE_ACCOUNT_NAME}-${NAMESPACE}-${CLUSTER_NAME}" \
      --kubeconfig="${KUBECFG_FILE_NAME}" \
      --token="${USER_TOKEN}"

    echo "Setting a context entry in kubeconfig..."
    kubectl config set-context \
    "${SERVICE_ACCOUNT_NAME}-${NAMESPACE}-${CLUSTER_NAME}" \
      --kubeconfig="${KUBECFG_FILE_NAME}" \
      --cluster="${CLUSTER_NAME}" \
      --user="${SERVICE_ACCOUNT_NAME}-${NAMESPACE}-${CLUSTER_NAME}" \
      --namespace="${NAMESPACE}"
}

unset KUBECONFIG

az aks get-credentials -g $resourceGroup -n $resourceGroup-aks --admin --overwrite-existing
get_secret_name_from_service_account
extract_ca_crt_from_secret
get_user_token_from_secret
set_kube_config_values
rm "$deploymentDir/$secretsDir/k8s-ca.crt"

echo "The Kubernetes configuration file $deploymentDir/$secretsDir/k8s-conf has been created"