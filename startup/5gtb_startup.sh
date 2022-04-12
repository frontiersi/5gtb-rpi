#!/bin/bash
#
# Execute the SUPL client, stream NMEA and RTCM to serial port and log to file.

# Set timezone for date command
export TZ=Australia/Sydney

# Kill script if a command returns a non-zero status (error)
set -e

# Kill child processes on exit
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# Get this scripts absolute path
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Make the data output directory if it doesn't exist
mkdir -p $HOME/output

# Get variables from config file
source ${SCRIPT_DIR}/../config.cfg

# Check that mode is correctly formatted
if !([ ${mode} = "positioning" ] || [ ${mode} = "correction" ]) ; then
    echo "Invalid mode"
fi

# Positioning mode
if [ ${mode} = "positioning" ]; then
    echo "Starting positioning mode"
    
    # Configure serial port
    echo "Configuring serial port ${serial_port}"
    stty -F ${serial_port} ${baud_rate} -echo

    # Stream RTCM to serial port/file, log stdout to file
    echo "Executing SUPL LPP Client"
    echo "Logging RTCM to" \
        "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm"
    supl-lpp-client \
        -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} \
        -d ${serial_port} -r ${baud_rate} \
        -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm |
        # Prepend UTC timestamps to log file
        while IFS= read -r line; do 
            printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line";
        done > ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log &

    # Save NMEA to file, start TCP server
    echo "Execute str2str on ${serial_port}"
    echo "Logging NMEA to" \
        "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea"
    # Remove '/dev/' from the serial_port variable
    str2str -in serial://${serial_port##*/}:${baud_rate} \
        -out file://${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea \
        -out tcpsvr://:29471
        # Can add another output here if required
fi

# Correction mode
if [ ${mode} = "correction" ]; then
    echo "Starting correction mode"

    # Execute supl client, save RTCM to file and stream RTCM to serial port
    echo "Executing SUPL LPP Client"
    echo "Streaming RTCM to ${serial_port}"
    echo "Logging RTCM to" \
        "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm"
    supl-lpp-client \
        -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} \
        -d ${serial_port} \
        -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm |
        # Prepend UTC timestamps to log file
        while IFS= read -r line; do 
            printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line";
        done > ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log &
fi
