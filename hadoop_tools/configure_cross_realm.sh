#!/bin/bash
#Author - Srinivasu Majeti(smajeti@cloudera.com)
#Script to configure cross real between two MIT KDC enabled kerberized clusters
#Cloudera Inc.
###########################################
set -x

STAGE_LOC="/tmp/stage"
mkdir -p $STAGE_LOC
#User Input Required Mandatory
CLUSTER1_SSH_PASSWORD=smajeti
CLUSTER2_AMBARI_HOST=c2265-node1.labs.support.hortonworks.com

#User Input Required Optional . Assumed to be same as first cluster/defaults if not given input
CLUSTER1_KADMIN_PASSWORD=hadoop
CLUSTER2_KADMIN_PASSWORD=hadoop
CLUSTER1_AMBARI_HOST=c1265-node1.squadron.support.hortonworks.com	
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
CLUSTER1_NAME=
CLUSTER2_NAME=
CLUSTER1_DOMAIN=
CLUSTER2_DOMAIN=

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

init(){
 yum -y install sshpass
	ssh-keygen -R $CLUSTER1_AMBARI_HOST
	ssh-keygen -R $CLUSTER2_AMBARI_HOST
}

initAmbariPorts(){
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

}

initClusterNames(){
	CLUSTER1_NAME="$(curl -u ${CLUSTER1_AMBARI_ADMIN_USER}:${CLUSTER1_AMBARI_ADMIN_PASSWORD} -i -H 'X-Requested-By: ambari'  $CLUSTER1_AMBARI_PROTOCOL://$CLUSTER1_AMBARI_HOST:$CLUSTER1_AMBARI_PORT/api/v1/clusters | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p')"
	CLUSTER2_NAME="$(curl -u ${CLUSTER2_AMBARI_ADMIN_USER}:${CLUSTER2_AMBARI_ADMIN_PASSWORD} -i -H 'X-Requested-By: ambari'  $CLUSTER2_AMBARI_PROTOCOL://$CLUSTER2_AMBARI_HOST:$CLUSTER2_AMBARI_PORT/api/v1/clusters | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p')"
}

mergeEtcHostsAndRedistribute(){
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
                        sed -i '' "s/\b$duplicate_word\b//g" $STAGE_LOC/etc_hosts_merged_uniq_final
                        sed -i '' "s/ $duplicate_word$//g" $STAGE_LOC/etc_hosts_merged_uniq_final
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
}

mergeAuthToLocalConfigAndReconfigure(){
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=get --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=core-site" > $STAGE_LOC/core-site_$CLUSTER1_AMBARI_HOST
	cluster1_auth_to_local=`cat $STAGE_LOC/core-site_$CLUSTER1_AMBARI_HOST | grep hadoop.security.auth_to_local | cut -d '"' -f4`
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=get --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=core-site" > $STAGE_LOC/core-site_$CLUSTER2_AMBARI_HOST
	cluster2_auth_to_local=`cat $STAGE_LOC/core-site_$CLUSTER2_AMBARI_HOST | grep hadoop.security.auth_to_local | cut -d '"' -f4`
	cluster2_auth_to_local=`echo $cluster2_auth_to_local | sed "s/DEFAULT//g"`
	echo "$cluster1_auth_to_local" > $STAGE_LOC/temp_value_cluster1
	echo "$cluster2_auth_to_local" >> $STAGE_LOC/temp_value_cluster1
	sed -i 's/\\n/\n/g' $STAGE_LOC/temp_value_cluster1
	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=set --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=core-site -k hadoop.security.auth_to_local -v "`cat $STAGE_LOC/temp_value_cluster1`"
	
	cluster2_auth_to_local=`cat $STAGE_LOC/core-site_$CLUSTER2_AMBARI_HOST | grep hadoop.security.auth_to_local | cut -d '"' -f4`
	cluster1_auth_to_local=`echo $cluster1_auth_to_local | sed "s/DEFAULT//g"`
	echo "$cluster2_auth_to_local" > $STAGE_LOC/temp_value_cluster2
	echo "$cluster1_auth_to_local" >> $STAGE_LOC/temp_value_cluster2
	sed -i 's/\\n/\n/g' $STAGE_LOC/temp_value_cluster2
	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=set --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=core-site -k hadoop.security.auth_to_local -v "`cat $STAGE_LOC/temp_value_cluster1`"
}

#configureKrb5Conf(){
#	sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=get --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=krb5-conf" > $STAGE_LOC/krb5-conf_complete_$CLUSTER1_AMBARI_HOST
#	sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=get --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=krb5-conf" > $STAGE_LOC/krb5-conf_complete_$CLUSTER2_AMBARI_HOST
	#sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=get --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=kerberos-env" > $STAGE_LOC/kerberos-env_complete_$CLUSTER1_AMBARI_HOST
	#sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=get --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=kerberos-env" > $STAGE_LOC/kerberos-env_complete_$CLUSTER2_AMBARI_HOST
	#cluster1_admin_server_host=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER1_AMBARI_HOST | grep admin_server_host | cut -d '"' -f4`
	#cluster1_kdc_hosts=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER1_AMBARI_HOST | grep kdc_hosts | cut -d '"' -f4`
	#cluster2_admin_server_host=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER2_AMBARI_HOST | grep admin_server_host | cut -d '"' -f4`
	#cluster2_kdc_hosts=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER2_AMBARI_HOST | grep kdc_hosts | cut -d '"' -f4`
	#
	#cat $STAGE_LOC/krb5-conf_complete_$CLUSTER1_AMBARI_HOST | grep content | cut -d '"' -f4 > $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST  
	#sed -i.bkp 's/\\n/\n/g' $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	#cat $STAGE_LOC/krb5-conf_complete_$CLUSTER2_AMBARI_HOST | grep content | cut -d '"' -f4 > $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST  
	#sed -i.bkp 's/\\n/\n/g' $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	#cluster1_realm=`cat $STAGE_LOC/krb5-conf_complete_CLUSTER1_AMBARI_HOST | grep realm | cut -d '"' -f4`
	#cluster2_realm=`cat $STAGE_LOC/kerberos-env_complete_$CLUSTER1_AMBARI_HOST | grep realm | cut -d '"' -f4`
	#cluster1_domain_name=`sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST 'hostname -d'`
	#cluster2_domain_name=`sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST 'hostname -d'`
#
	#sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=set --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=krb5-conf -k domains -v $cluster1_domain_name"
	#sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=set --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=krb5-conf -k domains -v $cluster2_domain_name"
	#
	#sed -i.bkp "/\[domain_realm\]/a   $cluster2_domain_name = $cluster2_realm" $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	#sed -i.bkp "/\[domain_realm\]/a   $cluster1_domain_name = $cluster1_realm" $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	#
	#sed -i.bkp "/\[realms\]/a $cluster2_realm = {\n    admin_server = $cluster2_admin_server_host\n    kdc = $cluster2_kdc_hosts\n}\n' $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	#sed -i.bkp "/\[realms\]/a $cluster1_realm = {\n    admin_server = $cluster1_admin_server_host\n    kdc = $cluster1_kdc_hosts\n}\n' $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	#
	#echo "[capaths]" >> $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	#echo "  $cluster1_realm = {" >> $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	#echo "        $cluster2_realm = ." >> $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	#echo "}" >> $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST
	
	#echo "[capaths]" >> $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	#echo "  $cluster2_realm = {" >> $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	#echo "        $cluster1_realm = ." >> $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	#echo "}" >> $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST
	#
	#sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER1_AMBARI_PROTOCOL --user=$CLUSTER1_AMBARI_ADMIN_USER --password=$CLUSTER1_AMBARI_ADMIN_PASSWORD --port=$CLUSTER1_AMBARI_PORT --action=set --host=$CLUSTER1_AMBARI_HOST --cluster=$CLUSTER1_NAME --config-type=krb5-conf -k content -v `cat $STAGE_LOC/krb5-conf_content_$CLUSTER1_AMBARI_HOST`"
	#sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "/var/lib/ambari-server/resources/scripts/configs.py --protocol=$CLUSTER2_AMBARI_PROTOCOL --user=$CLUSTER2_AMBARI_ADMIN_USER --password=$CLUSTER2_AMBARI_ADMIN_PASSWORD --port=$CLUSTER2_AMBARI_PORT --action=set --host=$CLUSTER2_AMBARI_HOST --cluster=$CLUSTER2_NAME --config-type=krb5-conf -k content -v `cat $STAGE_LOC/krb5-conf_content_$CLUSTER2_AMBARI_HOST`"
	#
	#sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "kadmin.local -q 'addprinc -pw $CLUSTER1_KADMIN_PASSWORD krbtgt/$cluster1_realm@$cluster2_realm'"
	#sshpass -p $CLUSTER1_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER1_AMBARI_HOST "kadmin.local -q 'addprinc -pw $CLUSTER1_KADMIN_PASSWORD krbtgt/$cluster2_realm@$cluster1_realm'"
	#sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "kadmin.local -q 'addprinc -pw $CLUSTER2_KADMIN_PASSWORD krbtgt/$cluster1_realm@$cluster2_realm'"
	#sshpass -p $CLUSTER2_SSH_PASSWORD ssh -o StrictHostKeyChecking=no root@$CLUSTER2_AMBARI_HOST "kadmin.local -q 'addprinc -pw $CLUSTER2_KADMIN_PASSWORD krbtgt/$cluster2_realm@$cluster1_realm'"
#}

#init
initAmbariPorts
initClusterNames
mergeEtcHostsAndRedistribute
#mergeAuthToLocalConfigAndReconfigure
#configureKrb5Conf
