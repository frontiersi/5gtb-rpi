#!/bin/bash
#
# Execute the SUPL client, stream NMEA and RTCM to serial port and log to file.

# Kill script if a command returns a non-zero status (error)
set -e

# Set timezone for date command
export TZ=Australia/Sydney

# Get this scripts absolute path
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Get variables from config file
source ${SCRIPT_DIR}/../config.cfg

# Stop docker container and kill child processes on exit
trap "trap - SIGTERM && \
      docker-compose -f ${gmv_pe_dir%/}/docker-compose.yml stop && \
      kill -- -$$" SIGINT SIGTERM EXIT

# Check that mode is correctly formatted
if !([ ${mode} = "positioning" ] || [ ${mode} = "correction" ]) ; then
    echo "Invalid mode"
fi

# Check that correcetion type is correctly formatted
if !([ ${correction_type} = "osr" ] || [ ${correction_type} = "ssr" ]) ; then
    echo "Invalid positioning type"
fi

# Positioning mode
if [ ${mode} = "positioning" ]; then
    echo "Starting Positioning Mode [${correction_type}]"
    echo "Configuring serial port ${uart_serial_port}"

    # If set, save SBF to file
    if [ ! -z ${usb_serial_port} ]; then
        echo "Executing str2str on ${usb_serial_port}"
        echo "Logging SBF to" \
            "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.sbf"

        str2str -in serial://${usb_serial_port##*/}:${baud_rate} \
            -out file://${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.sbf &
    fi

    # For OSR corrections direct RTCM corrections from the SUPL client to the GNSS HAT
    if [ ${correction_type} = "osr" ]; then
        # Stream RTCM to serial port/file, log stdout to file
        echo "Executing SUPL LPP Client"
        echo "Logging RTCM to" \
            "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm"
        supl-lpp-client \
            -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} \
            -d ${uart_serial_port##*/} -r ${baud_rate} \
            -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm |
            # Prepend UTC timestamps to log file
            while IFS= read -r line; do 
                printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$line";
            done > ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log &

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

    # For SSR corrections execute the GMV Positioning Engine
    if [ ${correction_type} = "ssr" ]; then
        # Deploy Docker container with GMV's Positioning Engine and the SUPL LPP Client
        echo "Executing Positioning Engine"
        echo "Logging NMEA to" \
            "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea"
        exec docker-compose -f ${gmv_pe_dir%/}/docker-compose.yml up -d &
        str2str -in tcpcli://127.0.0.1:19500 \
            -out file://${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea
    fi
fi

# Correction mode
if [ ${mode} = "correction" ]; then
    echo "Starting Correction Mode [${correction_type}]"

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
        -d ${uart_serial_port##*/} -r ${baud_rate} \
        -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm |
        # Prepend UTC timestamps to log file
        while IFS= read -r line; do
            printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$line";
        done | tee ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log
fi
