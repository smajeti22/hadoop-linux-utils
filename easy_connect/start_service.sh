#!/bin/bash
set -x
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "" ]; then
	echo "Usage: start_service.sh PASSWORD ADMIN_HOSTNAME_PREFIX(c4265) DNS_NAME(hwx.com) SERVICE_NAME(HDFS)"
	exit 0
fi
PASSWORD=$1
ADMIN_HOSTNAME_PREFIX=$2
CLUSTER_NAME=$ADMIN_HOSTNAME_PREFIX
DNS_NAME=$3
AMBARI_SERVER_HOST=$ADMIN_HOSTNAME_PREFIX-node1.$DNS_NAME
SERVICE_NAME=$4
curl -u admin:$PASSWORD -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :'\""Start $SERVICE_NAME via REST"\"}', "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://$AMBARI_SERVER_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE_NAME

