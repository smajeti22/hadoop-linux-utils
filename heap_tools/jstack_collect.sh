#!/bin/bash
times=$1
set -x
for count in $(seq 1 $times)
do
pid=`cat /var/run/hadoop/hdfs/hadoop-hdfs-namenode.pid`
        echo $count
        filename=/tmp/jstack_"$count"_"$pid"_`date +%F-%H-%M-%S`
        /usr/jdk64/jdk1.8.0_112/bin/jstack -l $pid > $filename
        sleep 5s
done
