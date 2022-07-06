#!/bin/bash
#
# Execute the SUPL client, stream NMEA and RTCM to serial port and log to file.

# Set timezone for date command
export TZ=Australia/Sydney

# Kill script if a command returns a non-zero status (error)
set -e

# Stop docker container and kill child processes on exit
trap "docker ps -q --filter "name=PE_AUS_5GTB" | grep -q . && \
      docker stop PE_AUS_5GTB && trap - SIGTERM && \
      kill -- -$$" SIGINT SIGTERM EXIT

# Get this scripts absolute path
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Get variables from config file
source ${SCRIPT_DIR}/../config.cfg

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
    echo "Starting positioning mode"
    
    # Configure serial port
    echo "Configuring serial port ${uart_serial_port}"
    stty -F ${uart_serial_port} ${baud_rate} -echo

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
    fi

    # For SSR corrections direct RTCM corrections from the SUPL client to a TCP server
    if [ ${correction_type} = "ssr" ]; then

        # Deploy Docker container with GMV's Positioning Engine
        # Within the Docker entrypoint, a RTKLIB TCP server is instantiated that
        # takes the SUPL Client's RTCM as input and outputs them to the GMV PE
        echo "Executing Positioning Engine"
        docker run -itd --rm -v /home/pi/5gtb-pe/Docker_5GTB/:/opt/magic/RT_PE \
            -p 19500:19500 -p 60001:60001 --device=/dev/ttyAMA0 \
            --name PE_AUS_5GTB rtpe_aus:latest &

        # Execute supl client, save RTCM to file and stream RTCM to TCP Server
        echo "Executing SUPL LPP Client"
        echo "Logging RTCM to" \
            "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm"
        supl-lpp-client \
            -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} \
            -k 127.0.0.1 -o 60001 \
            -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm |
            # Prepend UTC timestamps to log file
            while IFS= read -r line; do
                printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$line";
            done > ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log &

        # Log NMEA to file
        echo "Logging NMEA to" \
            "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea"
        str2str -in tcpcli://127.0.0.1:19500 \
            -out file://${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea
    fi

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
        -d ${uart_serial_port##*/} -r ${baud_rate} \
        -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm |
        # Prepend UTC timestamps to log file
        while IFS= read -r line; do
            printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$line";
        done | tee ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log
fi
