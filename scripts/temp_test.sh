#!/bin/bash
#
# Query temperature every second, log to file

# Get this scripts absolute path
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Get variables from config file
source ${SCRIPT_DIR}/../config.cfg

FILENAME=`date +"%Y%m%d-%H%M%S"`-$HOSTNAME-temp.log

while true
do
  echo -n "$(date +'%Y%m%d-%H%M%S.%3N') | "
  vcgencmd measure_temp | grep -o '[0-9]*\.[0-9]*'
  sleep 1s
done | tee ${output_dir%/}/$FILENAME
