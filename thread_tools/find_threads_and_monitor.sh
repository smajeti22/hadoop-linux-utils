#!/bin/bash
file_name_out=/root/log_file_`date '+%Y%m%d%H%M%S'`
touch $file_name_out
for count in {1..3000}
do
 date >> $file_name_out
 echo "======================" >> $file_name_out
 for pid in `find /var/run/ -name "*.pid"`
 do
        pid_num=`cat $pid`
	echo "Number of threads for pid $pid : $pid_num ->" `top -H -b -n 1 -p $pid_num | grep java | wc -l` >> $file_name_out
	#top -H -b -n 1 -p $pid_num >> $file_name_out
 done
 free -m >> $file_name_out
 sleep 5s
done
