#!/bin/bash

# This is a library, and is not meant to be called directly.

# Boolean to control whether to exit, after checking a bad exit code.
CONTINUE_ON_FAILURE=false
# Number of failures that have occured, while running this script.
FAILURE_COUNT=0

checkForVar() {
	local DESCRIPTION="$1"
    local VAR_VALUE="$2"

    if [ -z "$VAR_VALUE" ]; then
        echo "No $DESCRIPTION specified secret-vars.txt" 1>&2
        exit 1
    fi
}

logError() {
  local MESSAGE="$1"

  if test -t 1 ; then
    echo -e "\033[01;31mError:\033[00m $MESSAGE" 1>&2
  else
    echo "Error: $MESSAGE" 1>&2
  fi
}

logSuccess() {
  local MESSAGE="$1"

  if test -t 1 ; then
    echo -e "\033[01;32mSuccess:\033[00m $MESSAGE" 1>&2
  else
    echo "Success: $MESSAGE" 1>&2
  fi
}

checkExitCode() {
  local EXIT_CODE=$1
  local ERROR_MSG="$2"

  if [ $EXIT_CODE -ne 0 ]; then
    logError "$ERROR_MSG"
    FAILURE_COUNT=$(( $FAILURE_COUNT + 1 ))

    if [ $CONTINUE_ON_FAILURE == false ] ; then
      exit $EXIT_CODE
    fi
  fi
}
