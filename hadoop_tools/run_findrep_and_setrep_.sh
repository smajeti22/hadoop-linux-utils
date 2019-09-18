#!/bin/bash
#Run as hdfs user. Provide two arguments : ./run_setrep.sh 6 3 (This finds all files of repl=6 and set it to 3 
replication_matched_files=repl_matched_files_`date '+%Y%m%d%H%M%S'`
file_name_out=setrep_log_out_`date '+%Y%m%d%H%M%S'`
touch $file_name_out
touch $replication_matched_files

find_repl=$1
set_rep=$2
hdfs fsck / -files -locations -blocks | grep -B1 repl=$find_repl | grep "block(s):  OK" | cut -d ' ' -f1 >> $replication_matched_files
for file in `cat $replication_matched_files`
do
        echo "hdfs dfs -setrep $set_rep $file" >> $file_name_out
        hdfs dfs -setrep $set_rep $file >> $file_name_out
done
echo "Check out $file_name_out for list of matched replication hdfs files"
echo "Check out $replication_matched_files for log output for setting new replication factor for hdfs files"
