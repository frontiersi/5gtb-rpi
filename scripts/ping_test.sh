#!/bin/bash
#
# Ping Google DNS (8.8.8.8) every 200ms, log to file

# Get this scripts absolute path
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Get variables from config file
source ${SCRIPT_DIR}/../config.cfg

FILENAME=`date +"%Y%m%d-%H%M%S"`-$HOSTNAME-ping.log
HOST="8.8.8.8"

trap '' INT
ping $HOST -i 0.2 | while read pong;
do
    echo "$(date +'%Y%m%d-%H%M%S.%3N') | $pong";
done | tee ${output_dir%/}/$FILENAME
