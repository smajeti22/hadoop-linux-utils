#!/bin/bash
#Author - Srinivasu Majeti(smajeti@cloudera.com)
#Script to configure cross real between two MIT KDC enabled kerberized clusters
#Cloudera Inc.
#Two mandatory arguments to this script : 
#  First argument: IP Address of the second cluster ambari server
#  Second argument: ssh root password of the ambari server (assuming both ambari servers are with same ssh password)
#  Third argument (OPTIONAL) : IP address of the first cluster ambari server if script it not run from ambari server of the first cluster.
###########################################

STAGE_LOC="/tmp/stage/cross-realm-`date '+%Y%m%d%H%M%S'`"
mkdir -p $STAGE_LOC
rm -rf $STAGE_LOC/*
#User Input Required Mandatory
CLUSTER2_AMBARI_HOST=$1
CLUSTER1_SSH_PASSWORD=$2
CLUSTER1_AMBARI_HOST=$3

#User Input Required Optional . Assumed to be same as first cluster/defaults if not given input
CLUSTER1_KADMIN_PASSWORD=hadoop
CLUSTER2_KADMIN_PASSWORD=hadoop
if [ $CLUSTER1_AMBARI_HOST == "" ];
then
	CLUSTER1_AMBARI_HOST=localhost
fi
CLUSTER1_AMBARI_ADMIN_PASSWORD=$CLUSTER1_SSH_PASSWORD
CLUSTER2_SSH_PASSWORD=$CLUSTER1_SSH_PASSWORD
CLUSTER1_AMBARI_ADMIN_USER=admin
CLUSTER2_AMBARI_ADMIN_USER=admin
CLUSTER2_AMBARI_ADMIN_PASSWORD=$CLUSTER1_SSH_PASSWORD

#User Input Derived from cluster
CLUSTER1_AMBARI_PROTOCOL=http
CLUSTER2_AMBARI_PROTOCOL=http
CLUSTER1_AMBARI_PORT=8080
CLUSTER2_AMBARI_PORT=8080
CLUSTER1_NAME=""
CLUSTER2_NAME=""
CLUSTER1_DOMAIN=""
CLUSTER2_DOMAIN=""

#usage() { echo "$0 usage:" && grep " .)\ #" $0; exit 0; }
#[ $# -eq 0 ] && usage
#while getopts ":hs:p:" arg; do
#  case $arg in
#    p) # Specify p value.
#      echo "p is ${OPTARG}"
#      ;;
#    s) # Specify strength, either 45 or 90.
#      strength=${OPTARG}
#      [ $strength -eq 45 -o $strength -eq 90 ] \
#        && echo "Strength is $strength." \
#        || echo "Strength needs to be either 45 or 90, $strength found instead."
#      ;;
#    h | *) # Display help.
#      usage
#      exit 0
#      ;;
#  esac
#done

getMachineType()
{
	unameOut="$(uname -s)"
	case "${unameOut}" in
    	Linux*)     machine=Linux;;
    	Darwin*)    machine=Mac;;
    	CYGWIN*)    machine=Cygwin;;
    	MINGW*)     machine=MinGw;;
    	*)          machine="UNKNOWN:${unameOut}"
	esac
	echo ${machine}
}

ts()
{
        echo "`date +%Y-%m-%d,%H:%M:%S`"
}

	echo -e "\n`ts` Installing sshpass as needed" |tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout
	(brew list sshpass || brew install sshpass || yum list installed sshpass || yum -y install sshpass) > /dev/null 2>&1
	echo -e "\n`ts` Retrieving hostname for $CLUSTER2_AMBARI_HOST" |tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout
	ssh-keygen -R $CLUSTER1_AMBARI_HOST
	ssh-keygen -R $CLUSTER2_AMBARI_HOST
	if [ $CLUSTER1_AMBARI_HOST != "localhost" ];
	then
		echo -e "\n`ts` Retrieving hostname for $CLUSTER1_AMBARI_HOST" |tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout
		CLUSTER1_AMBARI_HOST=`sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST 'hostname -f'`
	fi
	CLUSTER2_AMBARI_HOST=`sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST 'hostname -f'`
	ssh-keygen -R $CLUSTER1_AMBARI_HOST
	ssh-keygen -R $CLUSTER2_AMBARI_HOST

	echo -e "\n`ts` Discovering Ambari Port and Protocol from both clusters" |tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout
	sshpass -p $CLUSTER1_SSH_PASSWORD  scp  -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST:/etc/ambari-server/conf/ambari.properties $STAGE_LOC/ambari.properties.$CLUSTER1_AMBARI_HOST
	cluster1_ssl_enabled=`grep api.ssl $STAGE_LOC/ambari.properties.$CLUSTER1_AMBARI_HOST | cut -d '=' -f2 | tr -d ' '`
	CLUSTER1_AMBARI_PORT=`grep client.api.port $STAGE_LOC/ambari.properties.$CLUSTER1_AMBARI_HOST | cut -d '=' -f2 | tr -d ' '` 
	if [ "$cluster1_ssl_enabled" == "true" ]; then
		CLUSTER1_AMBARI_PORT=`grep client.api.ssl.port $STAGE_LOC/ambari.properties.$CLUSTER1_AMBARI_HOST | cut -d '=' -f2 | tr -d ' '`
		CLUSTER1_AMBARI_PROTOCOL=https
		if [ "$CLUSTER1_AMBARI_PORT" == "" ]; then
			CLUSTER1_AMBARI_PORT=8443
		fi
	else
		CLUSTER1_AMBARI_PORT=`grep client.api.port $STAGE_LOC/ambari.properties.$CLUSTER1_AMBARI_HOST | cut -d '=' -f2 | tr -d ' '`
		if [ "$CLUSTER1_AMBARI_PORT" == "" ]; then
			CLUSTER1_AMBARI_PORT=8080
		fi
	fi
	sshpass -p $CLUSTER2_SSH_PASSWORD  scp  -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST:/etc/ambari-server/conf/ambari.properties $STAGE_LOC/ambari.properties.$CLUSTER2_AMBARI_HOST
	cluster2_ssl_enabled=`grep api.ssl $STAGE_LOC/ambari.properties.$CLUSTER2_AMBARI_HOST | cut -d '=' -f2 | tr -d ' '`
	CLUSTER2_AMBARI_PORT=`grep client.api.port $STAGE_LOC/ambari.properties.$CLUSTER2_AMBARI_HOST | cut -d '=' -f2 | tr -d ' '` 
	if [ "$cluster1_ssl_enabled" == "true" ]; then
		CLUSTER2_AMBARI_PORT=`grep client.api.ssl.port $STAGE_LOC/ambari.properties.$CLUSTER2_AMBARI_HOST | cut -d '=' -f2 | tr -d ' '`
		CLUSTER2_AMBARI_PROTOCOL=https
		if [ "$CLUSTER2_AMBARI_PORT" == "" ]; then
			CLUSTER2_AMBARI_PORT=8443
		fi
	else
		CLUSTER2_AMBARI_PORT=`grep client.api.port $STAGE_LOC/ambari.properties.$CLUSTER2_AMBARI_HOST | cut -d '=' -f2 | tr -d ' '`
		if [ "$CLUSTER2_AMBARI_PORT" == "" ]; then
			CLUSTER2_AMBARI_PORT=8080
		fi
	fi
	echo -e "\n`ts` CLUSTER1_AMBARI_PORT=$CLUSTER1_AMBARI_PORT ,CLUSTER1_AMBARI_PROTOCOL=$CLUSTER1_AMBARI_PROTOCOL" |tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout
	echo -e "\n`ts` CLUSTER2_AMBARI_PORT=$CLUSTER2_AMBARI_PORT ,CLUSTER2_AMBARI_PROTOCOL=$CLUSTER2_AMBARI_PROTOCOL" |tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout

	echo -e "\n`ts` Discovering Ambari Cluster Names from both clusters" |tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout
	CLUSTER1_NAME="$(curl -u ${CLUSTER1_AMBARI_ADMIN_USER}:${CLUSTER1_AMBARI_ADMIN_PASSWORD} -i -k -H 'X-Requested-By: ambari'  $CLUSTER1_AMBARI_PROTOCOL://$CLUSTER1_AMBARI_HOST:$CLUSTER1_AMBARI_PORT/api/v1/clusters | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p')"
	CLUSTER2_NAME="$(curl -u ${CLUSTER2_AMBARI_ADMIN_USER}:${CLUSTER2_AMBARI_ADMIN_PASSWORD} -i -k -H 'X-Requested-By: ambari'  $CLUSTER2_AMBARI_PROTOCOL://$CLUSTER2_AMBARI_HOST:$CLUSTER2_AMBARI_PORT/api/v1/clusters | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p')"
	echo -e "\n`ts` CLUSTER1_NAME=$CLUSTER1_NAME, CLUSTER2_NAME=$CLUSTER2_NAME" |tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout

mergeEtcHostsAndRedistribute(){
	echo -e "\n`ts` Collect /etc/hosts from both cluster admin nodes and merge without duplicate entries/words. Then distribute modified /etc/hosts back to all nodes"
	OLD_IFS=$IFS
	IFS=$'\n'
	sshpass -p $CLUSTER1_SSH_PASSWORD  scp  -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST:/etc/hosts $STAGE_LOC/etc_hosts.$CLUSTER1_AMBARI_HOST
	sshpass -p $CLUSTER2_SSH_PASSWORD  scp  -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST:/etc/hosts $STAGE_LOC/etc_hosts.$CLUSTER2_AMBARI_HOST
	cat $STAGE_LOC/etc_hosts.$CLUSTER1_AMBARI_HOST $STAGE_LOC/etc_hosts.$CLUSTER2_AMBARI_HOST > $STAGE_LOC/etc_hosts_merged
	sort $STAGE_LOC/etc_hosts_merged | uniq > $STAGE_LOC/etc_hosts_merged_uniq_final
	duplicated_words=`cut -d' ' -f2-  $STAGE_LOC/etc_hosts_merged_uniq_final | tr -s [:space:] \\\n |  sort | uniq -d`
        if [ "$duplicated_words" != "" ]; then
                for duplicate_word in $duplicated_words
                do
			if [ $(getMachineType) == "Mac" ];
			then
                        	sed -i '' "s/ $duplicate_word //g" $STAGE_LOC/etc_hosts_merged_uniq_final
                        	sed -i '' "s/ $duplicate_word$//g" $STAGE_LOC/etc_hosts_merged_uniq_final
			elif [ $(getMachineType) == "Linux" ];
			then
                        	sed -i "s/ $duplicate_word //g" $STAGE_LOC/etc_hosts_merged_uniq_final
                        	sed -i "s/ $duplicate_word$//g" $STAGE_LOC/etc_hosts_merged_uniq_final
			fi
                done
        fi

	#sed -i "s/$(cut -d' ' -f2-  $STAGE_LOC/etc_hosts_merged_uniq_final | tr -s [:space:] \\n |  sort | uniq -d)//g" $STAGE_LOC/etc_hosts_merged_uniq_final
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST 'cp /etc/hosts /etc/hosts.bkp'
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST 'cp /etc/hosts /etc/hosts.bkp'
	sshpass -p $CLUSTER1_SSH_PASSWORD scp -o StrictHostKeyChecking=no $STAGE_LOC/etc_hosts_merged_uniq_final root@$CLUSTER1_AMBARI_HOST:/etc/hosts
	sshpass -p $CLUSTER2_SSH_PASSWORD scp -o StrictHostKeyChecking=no $STAGE_LOC/etc_hosts_merged_uniq_final root@$CLUSTER2_AMBARI_HOST:/etc/hosts
	for cluster_node in $(curl -H "X-Requested-By:ambari" -u $CLUSTER1_AMBARI_ADMIN_USER:$CLUSTER1_AMBARI_ADMIN_PASSWORD -k -X GET $CLUSTER1_AMBARI_PROTOCOL://$CLUSTER1_AMBARI_HOST:$CLUSTER1_AMBARI_PORT/api/v1/hosts | grep host_name | cut -d '"' -f4)
	do
		ssh-keygen -R $cluster_node
		sshpass -p $CLUSTER1_SSH_PASSWORD  scp  -o StrictHostKeyChecking=no $STAGE_LOC/etc_hosts_merged_uniq_final root@$cluster_node:/etc/hosts
	done
	for cluster_node in $(curl -H "X-Requested-By:ambari" -u $CLUSTER2_AMBARI_ADMIN_USER:$CLUSTER2_AMBARI_ADMIN_PASSWORD -k -X GET $CLUSTER2_AMBARI_PROTOCOL://$CLUSTER2_AMBARI_HOST:$CLUSTER2_AMBARI_PORT/api/v1/hosts | grep host_name | cut -d '"' -f4)
	do
		ssh-keygen -R $cluster_node
		sshpass -p $CLUSTER2_SSH_PASSWORD  scp  -o StrictHostKeyChecking=no $STAGE_LOC/etc_hosts_merged_uniq_final root@$cluster_node:/etc/hosts
	done
	IFS=$OLD_IFS
	echo -e "\n`ts` Modified /etc/hosts:" 
	echo -e "\n`ts` `cat $STAGE_LOC/etc_hosts_merged_uniq_final`"
}

mergeAuthToLocalConfigAndReconfigure(){
	echo -e "\n`ts` Collect hadoop.security.auth_to_local of core-site configuration from HDFS service of both clusters and merge them into one and redistribute back to both clusters"
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=get --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=core-site" > $STAGE_LOC/core-site_$CLUSTER1_AMBARI_HOST
	cluster1_auth_to_local=`cat $STAGE_LOC/core-site_$CLUSTER1_AMBARI_HOST | grep hadoop.security.auth_to_local | cut -d '"' -f4`
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=get --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=core-site" > $STAGE_LOC/core-site_$CLUSTER2_AMBARI_HOST
	cluster2_auth_to_local=`cat $STAGE_LOC/core-site_$CLUSTER2_AMBARI_HOST | grep hadoop.security.auth_to_local | cut -d '"' -f4`
	cluster2_auth_to_local=`echo $cluster2_auth_to_local | sed "s/DEFAULT//g"`
	echo "$cluster1_auth_to_local" > $STAGE_LOC/temp_value_cluster1
	echo "$cluster2_auth_to_local" >> $STAGE_LOC/temp_value_cluster1
	sed -i.bkp 's/\\n/\'$'\n''/g' $STAGE_LOC/temp_value_cluster1
	sed -i.bkp 's/\$/\\$/g' $STAGE_LOC/temp_value_cluster1
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=set --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=core-site -k hadoop.security.auth_to_local -v \"`cat $STAGE_LOC/temp_value_cluster1`\""
	
	cluster2_auth_to_local=`cat $STAGE_LOC/core-site_$CLUSTER2_AMBARI_HOST | grep hadoop.security.auth_to_local | cut -d '"' -f4`
	cluster1_auth_to_local=`echo $cluster1_auth_to_local | sed "s/DEFAULT//g"`
	echo "$cluster2_auth_to_local" > $STAGE_LOC/temp_value_cluster2
	echo "$cluster1_auth_to_local" >> $STAGE_LOC/temp_value_cluster2
	sed -i.bkp 's/\\n/\'$'\n''/g' $STAGE_LOC/temp_value_cluster2
	sed -i.bkp 's/\$/\\$/g' $STAGE_LOC/temp_value_cluster2
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=set --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=core-site -k hadoop.security.auth_to_local -v \"`cat $STAGE_LOC/temp_value_cluster2`\""
	echo -e "\n`ts` Modified hadoop.security.auth_to_local for cluster $CLUSTER1_NAME:"
	echo -e "\n`ts` `cat $STAGE_LOC/temp_value_cluster1`"
	echo -e "\n`ts` Modified hadoop.security.auth_to_local for cluster $CLUSTER2_NAME:"
	echo -e "\n`ts` `cat $STAGE_LOC/temp_value_cluster2`"
}

configureKrb5Conf(){
	echo -e "\n`ts` Modifying krb5-conf template in Kerberos service for both clusters"
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=get --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=krb5-conf" > $STAGE_LOC/krb5-conf_complete_$CLUSTER1_AMBARI_HOST
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=get --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=krb5-conf" > $STAGE_LOC/krb5-conf_complete_$CLUSTER2_AMBARI_HOST
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=get --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=kerberos-env" > $STAGE_LOC/kerberos-env_complete_$CLUSTER1_AMBARI_HOST
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=get --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=kerberos-env" > $STAGE_LOC/kerberos-env_complete_$CLUSTER2_AMBARI_HOST
	cluster1_admin_server_host=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER1_AMBARI_HOST | grep admin_server_host | cut -d '"' -f4`
	cluster1_kdc_hosts=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER1_AMBARI_HOST | grep kdc_hosts | cut -d '"' -f4`
	cluster2_admin_server_host=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER2_AMBARI_HOST | grep admin_server_host | cut -d '"' -f4`
	cluster2_kdc_hosts=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER2_AMBARI_HOST | grep kdc_hosts | cut -d '"' -f4`
	
	cat $STAGE_LOC/krb5-conf_complete_$CLUSTER1_AMBARI_HOST | grep content | cut -d '"' -f4 > $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST  
	sed -i.bkp 's/\\n/\'$'\n''/g' $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	cat $STAGE_LOC/krb5-conf_complete_$CLUSTER2_AMBARI_HOST | grep content | cut -d '"' -f4 > $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST  
	sed -i.bkp 's/\\n/\'$'\n''/g' $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	cluster1_realm=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER1_AMBARI_HOST | grep realm | cut -d '"' -f4`
	cluster2_realm=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER2_AMBARI_HOST | grep realm | cut -d '"' -f4`
	cluster1_domain_name=`sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST 'hostname -d'`
	cluster2_domain_name=`sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST 'hostname -d'`

	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=set --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=krb5-conf -k domains -v $cluster1_domain_name"
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=set --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=krb5-conf -k domains -v $cluster2_domain_name"
	
	sed -i.bkp "/\[domain_realm\]/ a\\
\ \ $cluster2_domain_name = $cluster2_realm\\
        " $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST

	sed -i.bkp "/\[domain_realm\]/ a\\
\ \ $cluster1_domain_name = $cluster1_realm\\
        " $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	
	sed -i.bkp "/\[realms\]/ a\\
\ \ $cluster2_realm = {\\
\ \ \ \ admin_server = $cluster2_admin_server_host\\
\ \ \ \ kdc = $cluster2_kdc_hosts\\
\ }\\
        " $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	
	sed -i.bkp "/\[realms\]/ a\\
\ \ $cluster1_realm = {\\
\ \ \ \ admin_server = $cluster1_admin_server_host\\
\ \ \ \ kdc = $cluster1_kdc_hosts\\
\ }\\
        " $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	
	echo "[capaths]" >> $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	echo "  $cluster1_realm = {" >> $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	echo "        $cluster2_realm = ." >> $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	echo "}" >> $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	echo "" >> $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	
	echo "[capaths]" >> $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	echo "  $cluster2_realm = {" >> $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	echo "        $cluster1_realm = ." >> $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	echo "}" >> $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	echo "" >> $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST

		
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=set --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=krb5-conf -k content -v \"`cat $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST`\""
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=set --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=krb5-conf -k content -v \"`cat $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST`\""
	
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "kadmin.local -q 'addprinc -pw $CLUSTER1_KADMIN_PASSWORD krbtgt/$cluster1_realm@$cluster2_realm'"
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "kadmin.local -q 'addprinc -pw $CLUSTER1_KADMIN_PASSWORD krbtgt/$cluster2_realm@$cluster1_realm'"
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "kadmin.local -q 'addprinc -pw $CLUSTER2_KADMIN_PASSWORD krbtgt/$cluster1_realm@$cluster2_realm'"
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "kadmin.local -q 'addprinc -pw $CLUSTER2_KADMIN_PASSWORD krbtgt/$cluster2_realm@$cluster1_realm'"
	echo -e "\n`ts` Modified krb5-conf template for cluster $CLUSTER1_NAME:"
	echo -e "\n`ts` `cat $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST`"
	echo -e "\n`ts` Modified krb5-conf template for cluster $CLUSTER2_NAME:"
	echo -e "\n`ts` `cat $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST`"
}

stopAllServices(){
	echo -e "\n`ts` Stopping all the services for cluster $CLUSTER1_NAME"
        curl -H "X-Requested-By:ambari" -u $CLUSTER1_AMBARI_ADMIN_USER:$CLUSTER1_AMBARI_ADMIN_PASSWORD -i -k -X PUT -d '{"RequestInfo": {"context" :"Stopping All Services (via Squadron)"}, "ServiceInfo": {"state" : "INSTALLED"}}' $CLUSTER1_AMBARI_PROTOCOL://$CLUSTER1_AMBARI_HOST:$CLUSTER1_AMBARI_PORT/api/v1/clusters/$CLUSTER1_NAME/services
	echo -e "\n`ts` Stopping all the services for cluster $CLUSTER2_NAME"
        curl -H "X-Requested-By:ambari" -u $CLUSTER2_AMBARI_ADMIN_USER:$CLUSTER2_AMBARI_ADMIN_PASSWORD -i -k -X PUT -d '{"RequestInfo": {"context" :"Stopping All Services (via Squadron)"}, "ServiceInfo": {"state" : "INSTALLED"}}' $CLUSTER2_AMBARI_PROTOCOL://$CLUSTER2_AMBARI_HOST:$CLUSTER2_AMBARI_PORT/api/v1/clusters/$CLUSTER2_NAME/services
	echo -e "\n`ts` Sleeping for 60 seconds"
        sleep 60
}

startAllServices(){
	echo -e "\n`ts` Starting all services "
        curl -H "X-Requested-By:ambari" -u $CLUSTER1_AMBARI_ADMIN_USER:$CLUSTER1_AMBARI_ADMIN_PASSWORD -i -k -X PUT -d '{"RequestInfo": {"context" :"Starting All Services (via Squadron)"}, "ServiceInfo": {"state" : "STARTED"}}' $CLUSTER1_AMBARI_PROTOCOL://$CLUSTER1_AMBARI_HOST:$CLUSTER1_AMBARI_PORT/api/v1/clusters/$CLUSTER1_NAME/services
        curl -H "X-Requested-By:ambari" -u $CLUSTER2_AMBARI_ADMIN_USER:$CLUSTER2_AMBARI_ADMIN_PASSWORD -i -k -X PUT -d '{"RequestInfo": {"context" :"Starting All Services (via Squadron)"}, "ServiceInfo": {"state" : "STARTED"}}' $CLUSTER2_AMBARI_PROTOCOL://$CLUSTER2_AMBARI_HOST:$CLUSTER2_AMBARI_PORT/api/v1/clusters/$CLUSTER2_NAME/services
	echo -e "\n`ts` Please check Ambari UI\nThank You! :)"
}

restartServicesWithStaleconfigs()
{
	echo -e "\n`ts` Re-starting all services with stale config in both clusters"
	curl  -u $CLUSTER1_AMBARI_ADMIN_USER:$CLUSTER1_AMBARI_ADMIN_PASSWORD -k -H "X-Requested-By: ambari" -X POST  -d '{"RequestInfo":{"command":"RESTART","context":"Restart all required services (via Squadron)","operation_level":"host_component"},"Requests/resource_filters":[{"hosts_predicate":"HostRoles/stale_configs=true&HostRoles/cluster_name='$CLUSTER1_NAME'"}]}' $CLUSTER1_AMBARI_PROTOCOL://$CLUSTER1_AMBARI_HOST:$CLUSTER1_AMBARI_PORT/api/v1/clusters/$CLUSTER1_NAME/requests
	curl  -u $CLUSTER2_AMBARI_ADMIN_USER:$CLUSTER2_AMBARI_ADMIN_PASSWORD -k -H "X-Requested-By: ambari" -X POST  -d '{"RequestInfo":{"command":"RESTART","context":"Restart all required services (via Squadron)","operation_level":"host_component"},"Requests/resource_filters":[{"hosts_predicate":"HostRoles/stale_configs=true&HostRoles/cluster_name='$CLUSTER2_NAME'"}]}' $CLUSTER2_AMBARI_PROTOCOL://$CLUSTER2_AMBARI_HOST:$CLUSTER2_AMBARI_PORT/api/v1/clusters/$CLUSTER2_NAME/requests
	echo -e "\n`ts` Please check Ambari UI\nThank You! :)"

}
mergeEtcHostsAndRedistribute|tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout 2>>/$STAGE_LOC/cross_realm_setup.stderr
mergeAuthToLocalConfigAndReconfigure|tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout 2>>/$STAGE_LOC/cross_realm_setup.stderr
configureKrb5Conf|tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout 2>>/$STAGE_LOC/cross_realm_setup.stderr
restartServicesWithStaleconfigs|tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout 2>>/$STAGE_LOC/cross_realm_setup.stderr
#stopAllServices|tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout 2>>/$STAGE_LOC/cross_realm_setup.stderr
#startAllServices|tee -a $STAGE_LOC/cross_realm_setup.log 1>>/$STAGE_LOC/cross_realm_setup.stdout 2>>/$STAGE_LOC/cross_realm_setup.stderr

