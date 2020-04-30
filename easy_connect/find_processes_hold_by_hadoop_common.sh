#!/bin/bash
set -x
ps -ef > all_processes
for file_match in `find /usr/hdp -type f -name hadoop-common-2.7.3.2.6.5.0-292.jar`
do
	suffix_filename=`echo $file_match | sed 's/\//_/g'`
	lsof $file_match | cut -d ' ' -f5 | grep -v PID > pids_holding_the_file$suffix_filename
	for pid in `cat pids_holding_the_file$suffix_filename` ; do grep -w $pid all_processes ;done 1> found_processes$suffix_filename
	awk 'NF>1{print $NF}' found_processe$suffix_filename
done
