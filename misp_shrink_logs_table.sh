#!/bin/bash

# Create a full backup of your misp database before running this script

set -euxo pipefail
# bash 4.4+ - fail if subcommands fail
shopt -s inherit_errexit

dbname="misp"

dumpfolder="/data/dumps"
mkdir -p $dumpfolder

# delete logentries older than
# cleandate=$(date +'%Y-%m-%d' --date='-3 months')
# cleandate=$(date +'%Y-%m-%d' --date='-1 year')
cleandate=$(date +'%Y-%m-%d' --date='-14 days')
# cleandate=$(date +'%Y-%m-%d' --date='-1 day')

q1='SELECT COUNT(*) as CNT FROM logs' 
q2='SELECT COUNT(*) CNT_TO_DELETE FROM logs WHERE date(created) <"'$cleandate'";'
q3='DELETE FROM logs WHERE date(created) < "'$cleandate'";'

mysql -e "$q1" $dbname

t=$(mysql -N -e "$q2" $dbname)

if [ $t -eq 0 ]
then
	echo "No events to delete"
	exit 0
else
	echo "${t} events to delete"
fi

systemctl stop apache2

now=$(date +'%Y-%m-%d-%H-%M-%S')

# Cowards create a full backup
# dumpfull="${dumpfolder}/misp_full_before_${now}.sql"
# mysqldump $dbname > $dumpfull

# dump logs table
dumpname="${dumpfolder}/misp_logs_${now}.sql"
mysqldump $dbname logs> $dumpname

mysql -e "$q3" $dbname
mysql -e "$q1" $dbname

q4='OPTIMIZE TABLE logs;' 
mysql -e "$q4" $dbname

if [ $? -eq 0 ]
then
	echo "Success"
	systemctl start apache2
	exit 0
fi
	
now=$(date +'%Y-%m-%d-%H-%M-%S')
dumpname="${dumpfolder}/misp_logs_${now}.sql"
mysqldump $dbname logs > $dumpname

set +e
command -v pv
e=$?
set -e

if [ $e -eq 0 ]
then
	pv $dumpname |mysql $dbname
else
	cat $dumpname |mysql $dbname
fi


systemctl start apache2
