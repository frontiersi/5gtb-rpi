#!/bin/bash
#
# Deploy systemd services on the 5G Testbed RaspberryPi.

# Get this scripts absolute path
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Get variables from config file
source ${SCRIPT_DIR}/config.cfg

# Check if the services are already active and disable if they are
if (systemctl -q is-active wait-for-network.service) || (systemctl -q is-active 5gtb-daemon.service); then
    # Disable services
    sudo systemctl disable wait-for-network.service
    sudo systemctl disable 5gtb-daemon.service

    # Stop services
    sudo systemctl stop wait-for-network.service
    sudo systemctl stop 5gtb-daemon.service
fi

# Copy systemd services
echo "Copying systemd services to /lib/systemd/system/..."
sudo cp $SCRIPT_DIR/services/5gtb-daemon.service /lib/systemd/system/
sudo cp $SCRIPT_DIR/services/wait-for-network.service /lib/systemd/system/

# Write username into the absolute path of the startup script in the service
echo "Writing username into services..."
sudo sed -i "s/<USER>/${user}/g" /lib/systemd/system/5gtb-daemon.service

# Restart systemd-daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable services
echo "Enabling services..."
sudo systemctl enable wait-for-network.service
sudo systemctl enable 5gtb-daemon.service

# Start services
echo "Starting services..."
sudo systemctl start wait-for-network.service
sudo systemctl start 5gtb-daemon.service

echo "All done!"
