#!/bin/bash
#
# Execute the SUPL client, stream NMEA and RTCM to serial port and log to file.

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

    # Execute GPSD in foreground, read only and in listening mode
    echo "Executing GPSD on ${serial_port}"
    sudo gpsd -N -b -G ${serial_port} &

    # Execute SUPL client stream RTCM to serial port/file, log stdout to file
    # This needs to be executed before gpspipe, as this initialises GPSD on the
    # serial port, which will then hog the serial port
    echo "Executing SUPL LPP Client"
    echo "Logging RTCM to" \
        "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm"
    exec supl-lpp-client \
        -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} \
        -d ${serial_port} -r ${baud_rate} \
        -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.rtcm > \
        ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log &

    # Sleep to allow for the SUPL client to initialise the serial port
    sleep 0.5

    # Save NMEA messages from serial port to file
    echo "Logging NMEA to" \
        "${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea"
    gpspipe -R > ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.nmea &

    # Pipe NMEA messages into TCP server port 6000
    echo "Streaming NMEA to TCP server port 6000"
    socat TCP-LISTEN:6000,fork,reuseaddr EXEC:'gpspipe -R' &
    # Can add TCP servers here if required
fi

# Correction mode
if [ ${mode} = "correction" ]; then
    echo "Starting correction mode"

    # Execute supl client, save RTCM to file and stream RTCM to serial port
    echo "Executing SUPL LPP Client"
    echo "Streaming RTCM to ${serial_port}"
    exec supl-lpp-client \
        -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} \
        -d ${serial_port} -x ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`.rtcm > \
        ${output_dir%/}/`date +"%Y%m%d-%H%M%S"`-$HOSTNAME.log &
fi

# Keep script alive
while :; do
    sleep 5
done

# Kill background jobs on exit
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
