#!/bin/bash

if [ -z "$1" ]; then
	echo "Description: Calculates the various IP addresses and subnets that are needed during a hijaack, from the front-end-subnet."
	echo "      Usage: ./calculateIPs.sh FRONT_END_SUBNET"
	exit 1
fi

FES="$1"

IP_ONLY=`echo "$FES" | sed 's/\/.*//'`

IP4=`echo "$IP_ONLY" | sed 's/.*\.//'`
REMAINING=`echo "$IP_ONLY" | sed 's/\.[^.]*$//'`
IP3=`echo "$REMAINING" | sed 's/.*\.//'`
REMAINING=`echo "$REMAINING" | sed 's/\.[^.]*$//'`
IP2=`echo "$REMAINING" | sed 's/.*\.//'`
REMAINING=`echo "$REMAINING" | sed 's/\.[^.]*$//'`
IP1=`echo "$REMAINING" | sed 's/.*\.//'`

MINUS_SIX=$(( $IP3 - 6 ))
PLUS_ONE=$(( $IP3 + 1 ))
Y_PLUS_THREE=$(( $MINUS_SIX + 3 ))

echo "    Frontend Subnet: $FES"
echo "         K8S Subnet: $IP1.$IP2.$MINUS_SIX.$IP4/22"
echo "           Jump Box: $IP1.$IP2.$IP3.105"
echo "           Passthru: $IP1.$IP2.$PLUS_ONE.105"
echo "         classCPlus: $IP1.$IP2.$MINUS_SIX"
echo "   classCPlusOffset: $IP1.$IP2.$IP3"
#echo "Internal Ingress IP: $IP1.$IP2.$MINUS_SIX.105"
echo "Internal Ingress IP: $IP1.$IP2.$Y_PLUS_THREE.105"

