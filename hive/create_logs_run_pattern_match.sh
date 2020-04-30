#!/bin/bash
set -x
echo > overall_open_close_sessions.txt
log_file_name_abs_path=$1
while IFS= read -r line; do
    echo "Text read from file: $line"
	start_pattern=`echo $line | cut -d ',' -f1`
	end_pattern=`echo $line | cut -d ',' -f2`
	result_filename=`echo $start_pattern | sed -e "s/ /-/g"`"_TO_"`echo $end_pattern | sed -e 's/ /-/g'`".txt"
	line_number_start=`grep -n "$start_pattern" $log_file_name_abs_path | head -1 | cut -d ':' -f1`
	line_number_end=`grep -n "$end_pattern" $log_file_name_abs_path | head -1 | cut -d ':' -f1`
	sed -n "$line_number_start,$line_number_end""p" $log_file_name_abs_path > $result_filename
	echo Starting time stamp: $start_pattern Ending time stamp: $end_pattern >> overall_open_close_sessions.txt
	echo "Opening new Tez Session:" `grep -c "Opening new Tez Session" $result_filename` >> overall_open_close_sessions.txt
	echo "Closing Tez Session:" `grep -c "Closing Tez Session" $result_filename` >> overall_open_close_sessions.txt
done < "patterns_for_line_numbers_input.txt"
