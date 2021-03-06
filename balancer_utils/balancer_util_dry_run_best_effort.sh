### Assumptions: 
#1. input file is output of hdfs dfsadmin -report
#2. units are same across all nodes , all should be in GB or TB
#3. Considering same type of storage type
#!/bin/bash
#set -x
cluster_dfs_avg_usage=0
first_time_match=true
balancer_threshold=$1
one_node_info_available=false
data_copy_out_of_node_total=0
data_copy_into_node_total=0
#hdfs dfsadmin -report > dfsadmin_report
while IFS='' read -r line || [[ -n "$line" ]]; do
    	#echo "Text read from file: $line"
	if [[ $line =~ .*"DFS Used%".* ]] && [ "$first_time_match" == "true" ]
	then
		cluster_dfs_avg_usage=`echo $line | cut -d ":" -f2 | cut -d '%' -f1 | tr -d ' '`
		first_time_match=false
		echo "CLUSTER DFS AVG:$cluster_dfs_avg_usage"
		continue
	fi
	if [[ $line =~ .*"Hostname".* ]]; then
		curr_hostname=`echo $line | cut -d ":" -f2 | tr -d ' '`
		echo "---------------------------------"
		echo "Hostname ->$curr_hostname"
		echo "---------------------------------"
	fi
	if [[ $line =~ .*"Rack".* ]]; then
		curr_rack=`echo $line | cut -d ":" -f2 | tr -d ' '`
		echo "Rack ->$curr_rack"
	fi
	if [[ $line =~ ^"DFS Used:".* ]]; then
		curr_host_dfs_usage_size=`echo $line | grep "DFS Used:" | cut -d '(' -f2 | cut -d ')' -f1 | cut -d ' ' -f1`
		echo "DFS Used Size -> $curr_host_dfs_usage_size"
	fi
	if [[ $line =~ .*"DFS Used%".* ]]; then
		curr_host_dfs_usage=`echo $line | cut -d ":" -f2 | cut -d '%' -f1 | tr -d ' '`
		echo "DFS Used% -> $curr_host_dfs_usage"
		one_node_info_available=true
	fi
	if [[ $line =~ .*"Configured Capacity:".* ]]; then
		curr_host_config_capacity=`echo $line | grep "Configured Capacity:" | cut -d '(' -f2 | cut -d ')' -f1 | cut -d ' ' -f1`
		echo "Configured Capacity -> $curr_host_config_capacity"
	fi
	if [ "$one_node_info_available" == "true" ]; then
		deviation=`bc -l <<< "$curr_host_dfs_usage - $cluster_dfs_avg_usage"`
		abs_deviation=${deviation#-}
		if (( $(echo "$abs_deviation > $balancer_threshold" |bc -l) )); then
			echo "Deviation ---> $deviation"
			manipulation=`bc -l <<<  "$abs_deviation - $balancer_threshold"`
			data_movement=`bc -l <<< "scale=2;$curr_host_config_capacity * $manipulation/100"`
			if (( $(echo "$deviation > 0" |bc -l) )); then
				data_movement=`bc -l <<< "scale=2;(0 - $data_movement)"`
				data_copy_out_of_node_total=`bc -l <<< "$data_copy_out_of_node_total + $data_movement"`
			else
				data_copy_into_node_total=`bc -l <<< "$data_copy_into_node_total + $data_movement"`
			fi
			echo "Manipulation ---> $manipulation (Data movement size:$data_movement (TB))"
			new_dfs_util=`bc -l <<< "scale=2;($curr_host_dfs_usage_size + $data_movement)*100/$curr_host_config_capacity"`			
			echo "New Util -> $new_dfs_util"
		else
			echo "Not enough Deviation($abs_deviation) and no balancer impact"
		fi
		one_node_info_available=false
	fi
	
done < "dfsadmin_report"
echo data_copy_out_of_node_total:$data_copy_out_of_node_total
echo data_copy_into_node_total:$data_copy_into_node_total
