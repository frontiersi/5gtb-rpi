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
    echo "Configuring serial port ${uart_serial_port}"
    stty -F ${uart_serial_port} ${baud_rate} -echo

    # Stream RTCM to serial port/file, log stdout to file
    echo "Executing SUPL LPP Client"
    echo "Logging RTCM to" \
        "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm"
    supl-lpp-client \
        -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} \
        -d ${uart_serial_port} -r ${baud_rate} \
        -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm |
        # Prepend UTC timestamps to log file
        while IFS= read -r line; do 
            printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$line";
        done > ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log &

    # If set, save SBF to file
    if [ ! -z ${usb_serial_port} ]; then
        echo "Executing str2str on ${usb_serial_port}"
        echo "Logging SBF to" \
            "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.sbf"
        stty -F ${usb_serial_port} ${baud_rate} -echo

        str2str -in serial://${usb_serial_port##*/}:${baud_rate} \
            -out file://${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.sbf &
    fi

    # Save NMEA to file, start TCP server
    echo "Executing str2str on ${uart_serial_port}"
    echo "Logging NMEA to" \
        "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea"
    # Remove '/dev/' from the serial_port variable
    str2str -in serial://${uart_serial_port##*/}:${baud_rate} \
        -out file://${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea \
        -out tcpsvr://:29471
        # Can add another output here if required
fi

# Correction mode
if [ ${mode} = "correction" ]; then
    echo "Starting correction mode"

    # Configure serial port
    echo "Configuring serial port ${uart_serial_port}"
    stty -F ${uart_serial_port} ${baud_rate} -echo

    # Execute supl client, save RTCM to file and stream RTCM to serial port
    echo "Executing SUPL LPP Client"
    echo "Streaming RTCM to ${uart_serial_port}"
    echo "Logging RTCM to" \
        "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm"
    supl-lpp-client \
        -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} \
        -d ${uart_serial_port} -r ${baud_rate} \
        -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm |
        # Prepend UTC timestamps to log file
        while IFS= read -r line; do 
            printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$line";
        done | tee ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log
fi
