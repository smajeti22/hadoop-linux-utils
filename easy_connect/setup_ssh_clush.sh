#!/bin/bash
set -x
hostname_prefix=$1
hostname_prefix_other=$2
main=$3
other=$4
init_vars()
{
	host_entries_main=`cat /etc/hosts | grep $hostname_prefix`
	host_entries_other=`cat /etc/hosts | grep $hostname_prefix_other`
	host_ips_main=`cat /etc/hosts | grep $hostname_prefix | cut -d " " -f1`
	host_ips_other=`cat /etc/hosts | grep $hostname_prefix_other | cut -d " " -f1`
	user_password=smajeti
}

setup_ssh_local()
{
	sshpass -V
	if [ $? -gt 0 ]; then	
		echo "installing sshpass"
		brew install http://git.io/sshpass.rb
	fi
	strict_configured=`grep -c "^StrictHostKeyChecking no" /etc/ssh/ssh_config`
	if [ $strict_configured -eq 0 ]; then
		echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
	fi
}
setup_ssh_main()
{
	sshpass -p $user_password ssh root@$hostname_prefix-node1 'echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config'
	if [ -f ~/.ssh/id_rsa.pub ]; then
		echo "key generated already is in place"
	else
		ssh-keygen -p -N "" -f ~/.ssh/id_rsa
	fi
	for main_ip in $host_ips_main
        do
		ssh-keygen -R $main_ip
		sshpass -p $user_password ssh-copy-id root@$main_ip
		sshpass -p $user_password ssh-copy-id root@`cat /etc/hosts | grep -w $main_ip | cut -d " " -f1`
        done
	ssh-keygen -R $hostname_prefix-node1
	sshpass -p $user_password ssh-copy-id root@$hostname_prefix-node1
	sshpass -p $user_password ssh-copy-id root@`cat /etc/hosts | grep -w $hostname_prefix-node1 | cut -d " " -f1`
}

setup_ssh_other()
{
	sshpass -p $user_password ssh root@$hostname_prefix_other-node1 'echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config'
	if [ -f ~/.ssh/id_rsa.pub ]; then
		echo "key generated already is in place"
	else
		ssh-keygen -p -N "" -f ~/.ssh/id_rsa
	fi
	for other_ip in $host_ips_other
        do
		ssh-keygen -R $other_ip
		sshpass -p $user_password ssh-copy-id root@$other_ip
		sshpass -p $user_password ssh-copy-id root@`cat /etc/hosts | grep -w $other_ip | cut -d " " -f1`
        done
	ssh-keygen -R $hostname_prefix_other-node1
	sshpass -p $user_password ssh-copy-id root@$hostname_prefix_other-node1
	sshpass -p $user_password ssh-copy-id root@`cat /etc/hosts | grep -w $hostname_prefix_other-node1 | cut -d " " -f1`
}

setup_clush()
{
	sshpass -p $user_password ssh root@$hostname_prefix-node1 'yum clean all'
	sshpass -p $user_password ssh root@$hostname_prefix-node1 'yum -y install clustershell'
	sshpass -p $user_password ssh root@$hostname_prefix-node1 'echo all: `cat /etc/hosts | grep '$hostname_prefix' | cut -d " " -f1` >> /etc/clustershell/groups'
}

add_etc_hosts_from_other_cluster()
{
	temp_hosts_file="$hostname_prefix"_hosts
	temp_hosts_file_other="$hostname_prefix_other"_hosts
	echo "$host_entries_other" > /tmp/$temp_hosts_file_other
	echo "$host_entries_main" > /tmp/$temp_hosts_file	
	if [ $main == "true" ]; then
		for main_ip in $host_ips_main
		do
			sftp root@$main_ip:/etc <<< $'put /tmp/'$temp_hosts_file_other''
			sshpass -p $user_password ssh root@$main_ip 'cat /etc/'$temp_hosts_file_other' ''>> /etc/hosts' 
		done
	fi
	if [ $other == "true" ]; then
		for other_ip in $host_ips_other
		do
			sftp root@$other_ip:/etc <<< $'put /tmp/'$temp_hosts_file''
			sshpass -p $user_password ssh root@$other_ip 'cat /etc/'$temp_hosts_file' ''>> /etc/hosts' 
		done
	fi
}

configure_cross_realm()
{
	sshpass -p $user_password ssh root@$hostname_prefix-node1 'kadmin.local -q "addprinc -pw hadoop krbtgt/HWX.COM@SUPPORT.COM"'
	sshpass -p $user_password ssh root@$hostname_prefix-node1 'kadmin.local -q "addprinc -pw hadoop krbtgt/SUPPORT.COM@HWX.COM"'
	sshpass -p $user_password ssh root@$hostname_prefix_other-node1 'kadmin.local -q "addprinc -pw hadoop krbtgt/HWX.COM@SUPPORT.COM"'
	sshpass -p $user_password ssh root@$hostname_prefix_other-node1 'kadmin.local -q "addprinc -pw hadoop krbtgt/SUPPORT.COM@HWX.COM"'
	for main_ip in $host_ips_main
        do
        	sftp root@$main_ip:/etc/ <<< $'put support.com.krb5_append'
		sshpass -p $user_password ssh root@$main_ip 'cp -f /etc/support.com.krb5_append /etc/krb5.conf'
        done
	for other_ip in $host_ips_other
        do
        	sftp root@$other_ip:/etc/ <<< $'put hwx.com.krb5_append'
		sshpass -p $user_password ssh root@$other_ip 'cp -f /etc/hwx.com.krb5_append /etc/krb5.conf'
        done
}

create_hdfs_admin_user()
{
	sshpass -p $user_password ssh root@$hostname_prefix-node1 "clush -a 'groupadd -g 510 operator'"
	sshpass -p $user_password ssh root@$hostname_prefix-node1 "clush -a 'useradd -u 1050 -g operator noprinc'"
	sshpass -p $user_password ssh root@$hostname_prefix-node1 'kadmin.local -q "addprinc -pw noprinc noprinc"'
	#sshpass -p $user_password ssh root@$hostname_prefix_other-node1 "clush -a 'groupadd -g 510 operator'"
	#sshpass -p $user_password ssh root@$hostname_prefix_other-node1 "clush -a 'useradd -u 1030 -g operator diffp'"
	#sshpass -p $user_password ssh root@$hostname_prefix_other-node1 'kadmin.local -q "addprinc -pw hadoop2 diffp"'
}
init_vars
#setup_clush
if [ $main == "true" ]; then
	echo "setup ssh main"
	setup_ssh_main
fi
if [ $other == "true" ]; then
	echo "setup ssh other"
	#setup_ssh_other
fi
#add_etc_hosts_from_other_cluster
#configure_cross_realm
#create_hdfs_admin_user
