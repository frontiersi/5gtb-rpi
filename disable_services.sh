#!/bin/bash
#
# Disable systemd services on the 5G Testbed RaspberryPi.

# Disable services
echo "Disabling services..."
sudo systemctl disable wait-for-network.service
sudo systemctl disable 5gtb-daemon.service

# Stop services
echo "Stopping services..."
sudo systemctl stop wait-for-network.service
sudo systemctl stop 5gtb-daemon.service

echo "All done!"
