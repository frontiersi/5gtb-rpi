#!/bin/bash
#
# Ping a host every 200ms, log to file

while getopts ":h:" o; do
    case "${o}" in
        h)
            h=${OPTARG}
            ;;
    esac
done

# Get this scripts absolute path
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Get variables from config file
source ${SCRIPT_DIR}/../config.cfg

FILENAME=`date +"%Y%m%d-%H%M%S"`-$HOSTNAME-ping.log

trap '' INT
ping $h -i 0.2 | while read pong;
do
    echo "$(date +'%Y%m%d-%H%M%S.%3N') | $pong";
done | tee ${output_dir%/}/$FILENAME
