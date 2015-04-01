### Introduction ###

  * Lightweight Unix job control script used to sequence (schedule) dependent Unix shell scripts (Jobs).

  * Especially useful for running long lasting ETL and Data Warehousing jobs.

  * Uses tables viz. `job`, `job_dep` and `job_log` created in a RDBMS. (currently supports only Teradata RDBMS using native BTEQ CLI)

  * Uses user defined `job` ids and shell script names in `job` table and job dependencies in `job_dep` table to execute dependent jobs in Unix shell.

  * Jobs mentioned in `job` table are executed based on their dependencies defined in `job_dep` table and log entries are placed in `job_log` table.

  * See the documentation here: http://code.google.com/p/unix-db-job-sequencer/wiki/Documentation

### Usage ###

  * The required database tables can be created by executing tables.sql script in Teradata bteq.

  * There are in all three files "jcl.ksh", "bteq.ksh" and database information file "env.dat"

  * Information for database viz. server name, database name, username and password is entered in env.dat file.

  * These scripts are placed in a single folder along with the Unix scripts (Jobs) to be executed.

  * NOTE: The main sequencer scripts and Job scripts need to placed in the same folder or else the PATH of the folder containing the job scripts is required to be entered manually in “.profile” file.

  * The sequencer is started by executing the "jcl.ksh" script directly (execute access required) or by prefixing it with the shell name.