#!/bin/bash
#set -x
#grep 70b51000-fade-41e5-b1ad-1cc3e83a7b8e 2019-05-23-09:00:02_TO_2019-05-23-10:00:01.txt | grep "Opening new Tez Session" | cut -d ':'  -f4 | cut -d ']' -f1 | tr -d ' '
echo "" > full_log_threads_closing_status.txt
while IFS= read -r line; do
	grep "$line""] tez.TezSessionState: Closing Tez Session" full_log_closing_session_lines.txt && (echo Closed "#"$line"#" >> full_log_threads_closing_status.txt 2>&1) || (echo Not closed $line >> full_log_threads_closing_status.txt 2>&1)
done < full_log_threads.txt
#-rw-r--r--   1 smajeti  staff    107103969 May 30 13:01 2019-05-23-09:00:02_TO_2019-05-23-10:00:01.txt
#-rw-r--r--   1 smajeti  staff    102223268 May 30 13:01 2019-05-23-10:00:02_TO_2019-05-23-11:00:01.txt
#-rw-r--r--   1 smajeti  staff     37451149 May 30 13:02 2019-05-23-11:00:02_TO_2019-05-23-11:28:56.txt
