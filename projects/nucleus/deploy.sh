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

# apply shared first
pushd shared
	./deploy.sh --registryUser "$registryReaderId" --registryPassword "$registryReaderPassword"
	checkExitCode $? "Unable to run shared deploy.sh."
popd

# apply secrets second
configList=$(find $deploymentDir/$secretsDir -name "*.yaml")
for file in $configList; do 
    kubectl apply -f "$file"
    checkExitCode $? "Unable to apply $file."
done 

# apply the remaining project configurations
dyrectories=( chunkFrameExtraction edgeServerDdp imageDataService imageViewerService meteorUiDdp p10Accumulator p10Chunk studyRollup backupService backgroundProcessor )

for dyr in "${dyrectories[@]}"; do
	pushd $dyr
	./deploy.sh --registryUser "$registryReaderId" --registryPassword "$registryReaderPassword"
	checkExitCode $? "Unable to run $dyr deploy.sh."
	popd
done

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

