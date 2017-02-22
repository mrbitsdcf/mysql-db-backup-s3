#!/bin/bash
#===============================================================================
# IDENTIFICATION DIVISION
#          FILE:  mysql_backup.sh
#         USAGE:  ./mysql_backup.sh
#   DESCRIPTION:  Full MySQL Backup Script with S3 copy
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#          TODO:  ---
#        AUTHOR:  MrBiTs, mrbits.dcf@gmail.com
#       COMPANY:  PsychoSoft Inc
#       VERSION:  0.2
#       CREATED:  09/11/2012 01:47:28 PM BRT
#      REVISION:  10/05/2014 01:26:32 PM BRT
#===============================================================================

# ENVIRONMENT DIVISION

# CONFIGURATION SECTION
USELOGFILE=1 # Set to 1 to log script into a file
. /root/.mysql_backup.conf

# DATA DIVISION

# PROCEDURE DIVISION
# Do not edit from this point
if [ "${USELOGFILE}" -eq 1 ] ; then
    SCRIPTNAME=$(basename $0 .sh)
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    TRACEFILE=${BKPDIR}/trc/z2_${SCRIPTNAME}.trc
    if [ -f "${TRACEFILE}" ]; then
        # Moving log and error to backup. Nice to use with diff.
        mv ${TRACEFILE} ${TRACEFILE}_${TIMESTAMP}
    fi
    echo "LOG: ${TRACEFILE}"
    exec 1>> ${TRACEFILE} 2>&1
fi
# Start coding here

cd ${BKPDIR}

AdvPrint "Starting database backup"

for Key in "${!DBLIST[@]}" ; do
    DBHOST=$Key
    for DB in ${DBLIST[$Key]} ; do
        AdvPrint "Starting Backup from ${DB}"
        if [ ! -d ${DB} ]; then
            mkdir ${DB}
        else
            rm -f ${DB}/*
        fi
        for TBL in $(mysql -h ${DBHOST} -u ${DBUSER} -p${DBPWD} -N -e "SHOW TABLES" ${DB}) ; do
            AdvPrint "--- Executing Backup from ${TBL}"
            mysqldump -eq -h ${DBHOST} -u ${DBUSER} -p${DBPWD} ${DB} ${TBL} > ${DB}/$TBL.sql
        done
        AdvPrint "--- Compressing ${DB} data"
	    TARNAME=${DB}_${DATENAME}.tar.gz
        tar cfz ${TARNAME} ${DB}
        rm -rf ${DB}
	    AdvPrint "Copying backup to S3"
	    s3cmd put ${TARNAME} s3://emidia_backup/mysql/
        AdvPrint "Finishing Backup from ${DB}"
        AdvLine70 "="
    done
done

AdvPrint "Database backup finished with success (0)"

AdvPrint "Removing backup files older than ${RET} days"
find . -type f -mtime +${RET} -exec rm -vf {} \;

mutt -s "Backup administrator: Database backup of ${DATEPROC}" ${MAILADM} -a ${TRACEFILE} < <(echo -e "Sending database report of ${DATEPROC}.")
