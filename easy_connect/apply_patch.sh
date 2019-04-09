#!/bin/bash
set -x
original_jar=$1
target_jar=$2
target_jar_abs_path=$3
just_copy=false

output=`find /usr/hdp -name $target_jar`
if [ ! -z "$output" ]
then
        #already patching jar is available in the cluster , so set this flag to true so that softlinks are not touched later
        just_copy=true
fi

if [ $just_copy == "false" ]
then
        for original_jar_loc in `find /usr/hdp -type f -name  $original_jar`
        do
                base_dir=`echo $(dirname $original_jar_loc)`
                cp -f $original_jar_loc /tmp
                rm -rf $original_jar_loc
                cp -f $target_jar_abs_path/$target_jar $base_dir
        done
else
        for target_jar_loc in `find /usr/hdp -type f -name $target_jar`
        do
                cp -f $target_jar_abs_path/$target_jar $target_jar_loc
        done
fi

if [ -z $base_dir ]
then
        for target_jar_loc in `find /usr/hdp -type f -name  $target_jar`
        do
                base_dir=`echo $(dirname $target_jar_loc)`
        done
fi

if [ $just_copy == "false" ]
then
        for soft_link_jar in `find /usr/hdp -type l -name  $original_jar`
        do
                rm -rf $soft_link_jar
                ln -s $base_dir/$target_jar $soft_link_jar
        done
        gen_soft_link_jar_name=`echo ${original_jar//-[0-9].*/}`.jar
        for gen_soft_link in `find /usr/hdp -type l -name $gen_soft_link_jar_name`
        do
                rm -rf $gen_soft_link
                ln -s $base_dir/$target_jar $gen_soft_link
        done
fi
echo "Post replacement"
find /usr/hdp -name $original_jar -ls
find /usr/hdp -name $target_jar -ls
if [ ! -z $gen_soft_link_jar_name ]
then
        find /usr/hdp -name $gen_soft_link_jar_name -ls
fi
