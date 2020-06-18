#!/bin/bash

CONTINUE_ON_FAILURE=false

while [ -n "$1" ]; do
	case "$1" in
		"--continue-on-failure" | "-c")
			CONTINUE_ON_FAILURE=true
			shift
			;;
		*)
			echo "Error: Unexpected command: $1" 1>&2
			exit 1
	esac
done

FAILURE_COUNT=0

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
pushd $scriptDir

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

grep -R "{{" * > junk.out
rsize=$(wc -l < junk.out)
size=$(echo $rsize)
if [ $size -gt 1 ]; then
  echo "There are undefined configuration variable: "
  cat junk.out
  rm junk.out
  popd
  exit 1
fi
rm junk.out

pushd ingress-nginx
echo "Installing the ingress services"

kubectl apply -f ingress-nginx-namespace.internal.yaml
checkExitCode $? "Unable to apply ingress-nginx-namespace.internal."
kubectl apply -f rbac.internal.yaml
checkExitCode $? "Unable to apply rbac.internal."
kubectl apply -f ingress-nginx-internal.yaml
checkExitCode $? "Unable to apply ingress-nginx-internal."
kubectl apply -f ingress-nginx-namespace.yaml
checkExitCode $? "Unable to apply ingress-nginx-namespace."
kubectl apply -f rbac.yaml
checkExitCode $? "Unable to apply rbac."
kubectl apply -f default-backend.yaml
checkExitCode $? "Unable to apply default-backend."

kubectl --namespace ingress-nginx get secrets tls-certificate 2> /dev/null
if [ $? -eq 0 ]; then
	kubectl --namespace ingress-nginx delete secret tls-certificate
  checkExitCode $? "Unable to delete ingress-nginx cert."
fi

kubectl --namespace ingress-nginx create secret tls tls-certificate --key "$deploymentDir/$secretsDir/ssl.key" --cert "$deploymentDir/$secretsDir/ssl.crt" 
checkExitCode $? "Unable to apply ingress-nginx cert."

kubectl --namespace ingress-nginx get secrets tls-dhparam 2> /dev/null
if [ $? -ne 0 ]; then
	kubectl --namespace ingress-nginx create secret generic tls-dhparam --from-file="$deploymentDir/$secretsDir/dhparam.pem"
	checkExitCode $? "Unable to apply ingress-nginx dhParam file ."
fi

kubectl apply -f ingress-nginx.yaml
checkExitCode $? "Unable to apply ingress-nginx."

echo "Installing the OAuth2 Proxy as part of ingress services"
kubectl --namespace ingress-nginx get secrets oauth2-proxy 2> /dev/null
if [ $? -eq 0 ]; then
  kubectl --namespace ingress-nginx delete secret oauth2-proxy
  checkExitCode $? "Unable to delete oauth2-proxy secret."
fi

kubectl --namespace ingress-nginx create secret generic oauth2-proxy --from-literal=client-id="$oath2ClientID" --from-literal=client-secret="$oath2ClientSecret" --from-literal=cookie-secret="$cookieSecret"
checkExitCode $? "Unable to apply oauth2 proxy secrets."

kubectl --namespace=ingress-nginx apply -f oauth2-proxy.yaml
checkExitCode $? "Unable to apply oauth2-proxy."

popd
pushd linkerd

echo "Installing linkerd2"
kubectl apply -f linkerd.yaml
checkExitCode $? "Unable to apply linkerd."

echo "Installing kube state metrics"
kubectl apply -f kube-state-metrics-rbac.yaml
checkExitCode $? "Unable to apply kube-state-metrics-rbac."
kubectl apply -f kube-state-metrics-service.yaml
checkExitCode $? "Unable to apply kube-state-metrics-service."
kubectl apply -f kube-state-metrics-deployment.yaml
checkExitCode $? "Unable to apply kube-state-metrics-deployment."

echo "Installing node information daemonsets"
kubectl apply -f node-exporter-service.yaml
checkExitCode $? "Unable to apply node-exporter-service."
kubectl apply -f node-exporter-ds.yaml
checkExitCode $? "Unable to apply node-exporter-ds."

echo "Installing ingress rules"
kubectl --namespace linkerd get secrets tls-certificate 2> /dev/null
if [ $? -ne 0 ]; then
  kubectl get secret tls-certificate --namespace=ingress-nginx --export -o yaml | kubectl apply --namespace=linkerd -f -
  checkExitCode $? "Unable to apply ingress rules secrets ."
fi

kubectl apply -f prometheus-ingress.yaml
checkExitCode $? "Unable to apply prometheus-ingress."
kubectl apply -f linkerd-ingress.yaml
checkExitCode $? "Unable to apply linkerd-ingress."

popd
pushd fluent

echo "Installing the fluent-bit daemonset"
kubectl apply -f namespace.yaml
checkExitCode $? "Unable to apply namespace."
kubectl apply -f fluent-bit-rbac.yaml
checkExitCode $? "Unable to apply fluent-bit-rbac."
kubectl apply -f fluent-bit.yaml
checkExitCode $? "Unable to apply fluent-bit."

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
    echo -e "\033[01;32mSuccess.\033[00m "
  else
    echo "Success."
  fi
fi

