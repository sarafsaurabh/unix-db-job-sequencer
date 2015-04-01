## 1. Introduction ##


  * unix-db-job-sequencer is a lightweight script used to sequence (schedule) dependent Unix shell scripts (Jobs) especially useful for running long lasting ETL and Data Warehousing jobs.

  * This script uses tables viz. `job`, `job_dep` and `job_log` created in RDBMS (currently supports only Teradata RDBMS using native BTEQ CLI). It has been tested on Teradata V2R5 and V2R6

  * This script uses user defined `job` ids and shell script names in `job` table and job dependencies in `job_dep` table to execute dependent jobs in Unix shell.

  * Jobs mentioned in job table are executed based on their dependencies defined in `job_dep` table and log entries are placed in `job_log` table.


## 2. Job Tables Architecture ##

### 2.1 job Table ###

  * `job` table consists of a unique user defined job id which identifies a particular Unix Script to be considered for sequencing and job name which specifies the name of the script file.

  * `job` table can consist of duplicate (non-unique) job names. (This functionality is provided to allow same Unix script (job) to be executed more than once in a single sequence.)


  * The possible stages in which a job can exist are:

![http://lh3.ggpht.com/_f-88X0uUHrw/SwhhdxC7PpI/AAAAAAAACZA/XTs-BdlkHP8/Unix%20JCL_html_m1e582c53.png](http://lh3.ggpht.com/_f-88X0uUHrw/SwhhdxC7PpI/AAAAAAAACZA/XTs-BdlkHP8/Unix%20JCL_html_m1e582c53.png)

### 2.2 job\_dep Table ###


  * `job_dep` table consists of job ids and their dependence on other jobs identified in `job_dep_on` column.

  * A dependant job is executed only if all of its predecessors are successfully executed without any errors.

  * A null in `job_dep_on` column signifies that the job is ready to be executed and is independent of any other jobs defined in `job` table.

  * <font color='red'>NOTE: The sequencer will only start if all the jobs defined in <code>job</code> table are present in <code>job_dep</code> table. Independent jobs are added in <code>job_dep</code> table by providing nulls in <code>job_dep_on</code> column</font>

![http://lh6.ggpht.com/_f-88X0uUHrw/Swhhd7xegJI/AAAAAAAACY4/HW-RkJKy9xA/Unix%20JCL_html_6cf7204b.png](http://lh6.ggpht.com/_f-88X0uUHrw/Swhhd7xegJI/AAAAAAAACY4/HW-RkJKy9xA/Unix%20JCL_html_6cf7204b.png)

### 2.3 job\_log table ###

  * `job_log` table consists status of currently executing jobs as well as history.

  * This table includes information pertaining to every single execution of a job in the sequencer. Apart form the job name and job id, it provides start and end time for a job.

  * The possible stages in which a job can exist are:
    1. **Success:** Job is successfully executed without any errors.
    1. **Waiting:** Sequencer has withheld this job from execution until all its predecessors are successfully executed.
    1. **Running:** Job is currently executing.
    1. **Failed:** Job has finished with errors. The status mentions the number of errors and the error file in which all the errors encountered during execution are logged.
    1. **Interrupted:** The job is interrupted either by the user or it has been abandoned due to session disconnection.
    1. **Not started:** Job cannot be executed due to its predecessor failing, being interrupted or not started.

![http://lh3.ggpht.com/_f-88X0uUHrw/SwhheDLKpMI/AAAAAAAACZE/HU1XOQgLPOg/Unix%20JCL_html_m4e22f2f6.png](http://lh3.ggpht.com/_f-88X0uUHrw/SwhheDLKpMI/AAAAAAAACZE/HU1XOQgLPOg/Unix%20JCL_html_m4e22f2f6.png)

## 3. Error Handling ##

### 3.1 Job Failure Handling ###

  * If any errors are encountered during job execution, the status of the job is updated as “Failed” along with the number of errors. Any dependant jobs are updated into “Not Started due to parent job failure” state.

![http://lh3.ggpht.com/_f-88X0uUHrw/Swhhd7d3rjI/AAAAAAAACY8/4HLqAZVLVnE/Unix%20JCL_html_m1a37e8cf.png](http://lh3.ggpht.com/_f-88X0uUHrw/Swhhd7d3rjI/AAAAAAAACY8/4HLqAZVLVnE/Unix%20JCL_html_m1a37e8cf.png)

### 3.2 Job Interruption Handling ###

  * The sequencer stops its execution on encountering following signals and updates the status of currently executing jobs as “Interrupted” and its dependent jobs as “Not started due to parent job Interruption”:
    1. **SIGHUP:** Hangup
    1. **SIGINT:** Interrupt
    1. **SIGQUIT:** Quit
    1. **SIGTERM:** Terminated

![http://lh4.ggpht.com/_f-88X0uUHrw/Swhhdzj0I-I/AAAAAAAACY0/zAM3iRZFOJg/Unix%20JCL_html_2e78591b.png](http://lh4.ggpht.com/_f-88X0uUHrw/Swhhdzj0I-I/AAAAAAAACY0/zAM3iRZFOJg/Unix%20JCL_html_2e78591b.png)

### 3.3 Other Initial error handlers ###

  * There are few other error handlers incorporated in the script:
    1. Checking existence of job tables
    1. Checking proper job entries in `job_dep` table
    1. Checking existence of job files in the same folder
    1. Checking existence of a global deadlock of dependent jobs(This scenario will occur when there are no initially ready jobs. i.e.aAbsence of a null in `job_dep_on` column in `job_dep` table)

  * For any of the above mentioned errors the sequencer will not start and will specify an error message on the prompt.

## 4. Script Execution ##

  * The required database tables can be created by executing tables.sql script in Teradata bteq.

  * There are in all three files "jcl.ksh", "bteq.ksh" and database information file "env.dat"

  * Information for database viz. server name, database name, username and password is entered in env.dat file.

  * These scripts are placed in a single folder along with the Unix scripts (Jobs) to be executed.

  * <font color='red'>NOTE: The main sequencer scripts and Job scripts need to placed in the same folder or else the PATH of the folder containing the job scripts is required to be entered manually in “.profile” file.</font>

  * The sequencer is started by executing the "jcl.ksh" script directly (execute access required) or by prefixing it with the shell name.