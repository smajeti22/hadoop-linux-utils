#!/bin/bash

local_jar_path=$1
clustername=$2
target_cluster_hdp_version=$3
for counter in {2..4}
do
	sftp root@$clustername-node$counter:/tmp <<< $'put' $local_jar_path''
done
