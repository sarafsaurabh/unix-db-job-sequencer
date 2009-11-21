#!/usr/bin/ksh
. env.dat

# Unix Job Control Scipt (bteq)
# Author: Saurabh Saraf
# version 1.2
# This script is used along with job sequencer jcl.ksh

#******* Inserting Job status in job_log table *******

if [ $2 == Failed ]
then
bteq << ! > /dev/null
.logon $servername/$username,$password
update $databasename.job_log set job_end_time=CURRENT_TIMESTAMP(0), job_status='Failed: $6 error(s). Please check $5 for details' where job_id='$3' and job_name='$4' and job_end_time is NULL;
database $databasename;
.exit
!
elif [ $2 == Running ]
then
bteq << ! > /dev/null
.logon $servername/$username,$password
update $databasename.job_log set job_strt_time=CURRENT_TIMESTAMP(0), job_status='Running' where job_id=$3 and job_name='$4' and job_end_time is NULL and job_strt_time is null and job_status='Waiting';
.exit
!
elif [ $2 == Not_started ]
then
bteq << ! > /dev/null
.logon $servername/$username,$password
update $databasename.job_log set job_status='Not started. Reason: Parent job either not started or Failed' where job_id=$3 and job_end_time is NULL and job_strt_time is null and job_status='Waiting';
.exit
!
elif [ $2 == Interrupted ]
then
bteq << ! > /dev/null
.logon $servername/$username,$password
update $databasename.job_log set job_status='Interrupted' where job_status='Running';
update $databasename.job_log set job_status='Not started. Reason: Parent job either not started or interrupted' where job_status='Waiting';
.exit
!
rm -f ready_jobs.dat
rm -f dep_jobs.dat
rm -f success_log.dat
rm -f executed_jobs.dat
rm -f dep_on_jobs.dat
rm -f temp.dat
rm -f distinct_job.dat
rm -f failed_jobs.dat
rm -f ready_done.dat
else
bteq << ! > /dev/null
.logon $servername/$username,$password
update $databasename.job_log set job_end_time=CURRENT_TIMESTAMP(0), job_status='Success' where job_id=$3 and job_name='$4' and job_end_time is NULL and job_status='Running';
.exit
!
fi
