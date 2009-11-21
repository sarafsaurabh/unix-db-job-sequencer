#!/usr/bin/ksh

# unix-db-job-sequencer
# Author: Saurabh Saraf
# Version 1.2
# This job control script is used to sequence (schedule) dependent unix shell scripts(Jobs).
# This script uses tables (job, job_dep and job_log) created in Teradata RDBMS.
# Enter user defined job_ids and shell script names in job table and job dependencies in job_dep table.
# Jobs mentioned in job table are executed based on their dependencies defined in job_dep table and log entries are placed in job_log table. 

. env.dat
trap 'ksh bteq.ksh $databasename Interrupted;echo "\n\n! Interrupt signal detected. Cleaning up temporary files..\n";exit' 1 2 3 15


#******* Checking Job Tables ********

clear
echo "UNIX JOB CONTROL SCRIPT v1.2\n\n"
echo "Initializing...please wait...\n"
echo "Checking job tables...\c"
bteq << ! > /dev/null
.logon $servername/$username,$password
sel * from dbc.tables where DatabaseName='$databasename' and TableName in ('Job','Job_dep','Job_log');
.IF ACTIVITYCOUNT!=3 THEN .exit 1
sel * from $databasename.job;
.IF ACTIVITYCOUNT=0 THEN .exit 1
sel * from $databasename.job_dep;
.IF ACTIVITYCOUNT=0 THEN .exit 1
.exit
!

error_flag=`echo $?`
if [ $error_flag -eq 0 ]
then
echo "success"
else
echo "FAILED"
echo "Error: Job Tables do not exist or tables are empty. Check BTEQ Error code $error_flag for details" 
exit
fi

#******* Creating temporary files to be used by script *******

rm -f job_count.dat
rm -f distinct_job.dat
rm -f ready_jobs.dat
rm -f dep_jobs.dat

#******* Extracting rows from job tables ******* 

echo "Extracting rows from job tables...\c"
bteq << ! > /dev/null
.logon $servername/$username,$password
.export file=job_count.dat
sel job_name(TITLE '') from $databasename.job;
.export reset
.export file=distinct_job.dat
sel count(distinct job_id)(TITLE '') from $databasename.job_dep;
.export reset
.export file ready_jobs.dat
sel job.job_id(TITLE ''), job_name(TITLE '') from $databasename.job inner join $databasename.job_dep on job.job_id=job_dep.job_id where job_dep_on is NULL;
.export reset
.export file dep_jobs.dat
sel job_dep.job_id(TITLE ''), job.job_name(TITLE ''), job_dep.job_dep_on(TITLE '') from $databasename.job inner join $databasename.job_dep on job.job_id=job_dep.job_id where job_dep.job_dep_on is not NULL;
.export reset
.exit
!
echo "success"

#******* Cleansing ready jobs and dependent jobs temporary files *******

awk '{print $1" "$2}' ready_jobs.dat > temp.dat
cat temp.dat > ready_jobs.dat
awk '{print $1" "$2" "$3}' dep_jobs.dat > temp.dat
cat temp.dat > dep_jobs.dat
rm temp.dat

#******* Checking job_dep table for proper job entries *******

echo "Checking job tables for proper job entries...\c"
job_count=`wc -l job_count.dat | awk '{print $1}'`
job_distinct_count=`cat distinct_job.dat`
if [ $job_count -ne $job_distinct_count ]
then 
	echo "FAILED"
	echo "Error: Please check job entries in Job_Dep table"
	exit
else
	echo "success"
fi
rm distinct_job.dat

#******* Checking job_dep table for deadlock *******

echo "Checking job_dep table for deadlock...\c"
if [ `wc -l ready_jobs.dat | awk '{print $1}'` -eq 0 ]
then
	echo "FAILED"
	echo "Deadlock!! Cannot start sequencer. Please check job dependencies"
	exit
else
	echo "success"
fi

#******* Checking job files for existence *******

echo "Checking job files for existence...\c"
flag=0
while read line
do
	job_name=`echo $line` 
	if [ ! -e $job_name ]
	then
	echo "$job_name does not exist"
	flag=1
	fi
done < job_count.dat
rm job_count.dat

if [ $flag -eq 1 ]
then
	rm ready_jobs.dat
	rm dep_jobs.dat
	exit
else
	echo "success"
fi

#******* Inserting job status in log table *******

echo "Starting sequencer...\n"
bteq << ! > /dev/null
.logon $servername/$username,$password
insert into $databasename.job_log select job_id, job_name ,NULL,NULL,'Waiting' from $databasename.job;
.exit
!

#******* Creating temporary files to be used by script *******

rm -f executed_jobs.dat
rm -f temp.dat
rm -f success_log.dat
rm -f failed_jobs.dat

#******* Job Control main script starts here *******

while [ $job_count -gt 0 ]
do

	#******* Ready jobs are executed and placed in executed_jobs.dat file for observation *******

	if [ -e ready_jobs.dat ] 
	then
	while read line
	do
		ready_job_name=`echo $line | awk '{print $2}'` 
		ready_job_id=`echo $line | awk '{print $1}'`
		echo "> Starting Job ${ready_job_id}: $ready_job_name"
		ksh $ready_job_name 1> /dev/null 2> error_$ready_job_name &
		ready_job_pid=`echo $!`
		ksh bteq.ksh $databasename Running $ready_job_id $ready_job_name & > /dev/null
		echo "$ready_job_id $ready_job_pid $ready_job_name" >> executed_jobs.dat
	done < ready_jobs.dat
	rm ready_jobs.dat 
	fi

	#******* ps snapshot is taken and executed jobs are checked for completion *******
	#******* dont touch this part unless you know what you are doing *********

	while read line
	do
		executed_job_name=`echo $line | awk '{print $3}'`
		executed_job_id=`echo $line | awk '{print $1}'`
		executed_job_pid=`echo $line | awk '{print $2}'`
		ps -def | grep $executed_job_pid > /dev/null
		error_flag=`echo $?`
		if [ $error_flag -eq 1 ]
		then
			job_errors=`wc -l error_$executed_job_name | awk '{print $1}'`
			if [ $job_errors -ne 0 ]
			then
				echo " !! Job $executed_job_id failed!!. Inserting Job status in log table"
				ksh bteq.ksh $databasename Failed $executed_job_id $executed_job_name error_$executed_job_name $job_errors & > /dev/null
				echo "! Error: Job $executed_job_name Failed with $job_errors error(s). Please check error_$executed_job_name file for details"
				echo $executed_job_id > failed_jobs.dat
				while read failed_job_id
				do
					grep $failed_job_id dep_jobs.dat | awk '{print $1}' > temp.dat
					cat temp.dat >> failed_jobs.dat
					grep -v "$failed_job_id" dep_jobs.dat > temp.dat
					cat temp.dat > dep_jobs.dat
				done < failed_jobs.dat
				sort -u failed_jobs.dat > temp.dat
				cat temp.dat > failed_jobs.dat
				while read failed_job
				do
					ksh bteq.ksh $databasename Not_started $failed_job > /dev/null
					job_count=`expr $job_count - 1`
				done < failed_jobs.dat
			else
				echo ">> Job $executed_job_id is successful!! Inserting Job status in log table"
				ksh bteq.ksh $databasename Success $executed_job_id $executed_job_name & > /dev/null
				echo $executed_job_id >> success_log.dat
				job_count=`expr $job_count - 1`
				rm error_$executed_job_name
			fi
			grep -v "$line" executed_jobs.dat > temp.dat
			cat temp.dat > executed_jobs.dat
		fi
	done < executed_jobs.dat

	#******* Rows from job_log table are checked against dependent jobs ready to be executed *******

	if [ -e success_log.dat ]
	then
	rm -f ready_done.dat
	while read line
	do
		count=0
		dep_job_id=`echo $line | awk '{print $1}'`
		dep_job_name=`echo $line | awk '{print $2}'`
		grep "$dep_job_id $dep_job_name" dep_jobs.dat | awk '{print $3}' > dep_on_jobs.dat
		job_dep_no=`wc -l dep_on_jobs.dat | awk '{print $1}'`
		while read line_dep_on
		do
			success_temp=`grep $line_dep_on success_log.dat | wc -l`
			if [ $success_temp -eq 1 ]
			then
				count=`expr $count + 1`
			fi
		done < dep_on_jobs.dat
		if [ $count -eq $job_dep_no ]
		then
		echo "$dep_job_id $dep_job_name" >> ready_jobs.dat
		echo "$line" >> ready_done.dat
		fi
	done < dep_jobs.dat
	if [ -e ready_jobs.dat ]
	then
		uniq ready_jobs.dat > temp.dat
		cat temp.dat > ready_jobs.dat
		while read line
		do
			grep -v "$line" dep_jobs.dat > temp.dat
			cat temp.dat > dep_jobs.dat
		done < ready_done.dat
	fi
	fi
done

# ******* Sequencer over. Removing temporary files *******

rm dep_jobs.dat
rm executed_jobs.dat
rm -f dep_on_jobs.dat
rm temp.dat
rm -f success_log.dat
rm -f ready_done.dat
rm -f failed_jobs.dat
echo "\nDone !!!\n"
