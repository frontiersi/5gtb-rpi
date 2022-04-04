#!/bin/bash
#
# Execute the SUPL LPP client, stream NMEA and RTCM to serial port and log to file.

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
    echo "Configuring ${serial_port}"
    stty -F ${serial_port} ${baud_rate} -echo

    # Save NMEA messages from serial port to file
    echo "Logging ${serial_port} to $HOME/output/`date +"%Y%m%d-%H%M%S"`.nmea"
    exec cat "${serial_port}" > $HOME/output/`date +"%Y%m%d-%H%M%S"`.nmea &

    # Execute supl client, get corrections from location server and stream RTCM to serial port
    echo "Executing SUPL LPP Client"
    exec supl-lpp-client -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} -d ${serial_port} -r ${baud_rate} -x $HOME/output/`date +"%Y%m%d-%H%M%S"`.rtcm
fi

# Correction mode
if [ ${mode} = "correction" ]; then   
    echo "Starting correction mode"

    # Execute supl client, save RTCM to file and stream RTCM to serial port
    echo "Executing SUPL LPP Client"
    exec supl-lpp-client -h ${host} -p ${port} -c ${mcc} -n ${mnc} -t ${tac} -i ${cell_id} -d ${serial_port} -x $HOME/output/`date +"%Y%m%d-%H%M%S"`.rtcm
fi

# Kill background jobs on exit
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
