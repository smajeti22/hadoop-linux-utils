#!/bin/bash
#set -x
#grep 70b51000-fade-41e5-b1ad-1cc3e83a7b8e 2019-05-23-09:00:02_TO_2019-05-23-10:00:01.txt | grep "Opening new Tez Session" | cut -d ':'  -f4 | cut -d ']' -f1 | tr -d ' '
while IFS= read -r line; do
	thread_ids=`grep $line 2019-05-23-09:00:02_TO_2019-05-23-10:00:01.txt | grep "Opening new Tez Session" | cut -d ':'  -f4 | cut -d ']' -f1 | tr -d ' '`
	for thread_id in `echo $thread_ids`
	do
		echo One Thread: $thread_id
		thread_id=`echo $thread_id | tr -d ' '`
	grep "$thread_id""] tez.TezSessionState: Closing Tez Session" 2019-05-23-09:00:02_TO_2019-05-23-10:00:01.txt && echo Closed "#"$line"#" || grep "$thread_id""] tez.TezSessionState: Closing Tez Session" 2019-05-23-10:00:02_TO_2019-05-23-11:00:01.txt && echo Closed "#"$line"#"||  grep "$thread_id""] tez.TezSessionState: Closing Tez Session" 2019-05-23-11:00:02_TO_2019-05-23-11:28:56.txt && echo Closed "#"$line"#"|| echo Not closed $line
	done
#done < new_session_during_prob_hour
done < new_session_during_prob_hour_uniq
#-rw-r--r--   1 smajeti  staff    107103969 May 30 13:01 2019-05-23-09:00:02_TO_2019-05-23-10:00:01.txt
#-rw-r--r--   1 smajeti  staff    102223268 May 30 13:01 2019-05-23-10:00:02_TO_2019-05-23-11:00:01.txt
#-rw-r--r--   1 smajeti  staff     37451149 May 30 13:02 2019-05-23-11:00:02_TO_2019-05-23-11:28:56.txt
