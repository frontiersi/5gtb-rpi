# 5G Testbed RaspberryPi

Startup scripts, systemd services, and supporting scripts and config files that deploy the systemd services for the 5G Testbed RaspberryPi hardware.

---

## Installation

Instructions tested on RaspberryPi OS 64bit, on a RaspberryPi 4B.

### 1. Clone repository

Clone this repository to the RaspberryPi's home directory.

```console
cd $HOME
git clone https://github.com/frontiersi/5gtb-rpi.git
```

### 2. Install dependencies

The startup scripts require the [SUPL LPP Client](https://github.com/frontiersi/supl-lpp-client) to connect to a location server and generate RTCM from LPP messages.

Install it by following the instructions in the [GitHub Repository](https://github.com/frontiersi/supl-lpp-client/tree/main#installation).

Ensure that the SUPL LPP Client can be executed from anywhere.

### 3. Update config file

Make a copy of `config_sample.cfg` called `config.cfg`.

```console
cp $HOME/5gtb-rpi/config_sample.cfg $HOME/5gtb-rpi/config.cfg
```

In the `config.cfg` file add arguments for each parameter. The following explains each parameter:

#### Username

The username of the current user on the Raspberry Pi is required to properly configure the user that executes the startup script on boot. This simplifies path names in the startup script.

```text
# Username
user=pi                     # Username for executing as user in service
```

#### Script mode

Determines how the script should operate given the hardware configuration, there are two modes:

1. `positioning`: Executes the SUPL LPP Client which outputs RTCM corrections to the serial port and a file, and logs NMEA from the serial port to a file. Use when a RaspberryPi GNSS HAT is connected.
2. `correction`: Executes the SUPL LPP Client which outputs RTCM corrections to a serial port, and saves output RTCM messages to a file. Use when an independent GNSS receiver is connected by serial port.

```text
# Script mode
mode=positioning            # Operation mode (positioning or correction)
```

#### Output Device

Determines the output device to stream RTCM to, and log NMEA from (if in `positioning` mode).

```text
# Output Device
serial_port=/dev/ttyAMA0    # Device serial port
baud_rate=115200            # Device baud rate
```

#### Location Server

Determines the location server network parameters. Sample parameters are provided in the example below.

```text
# Location Server
host=192.0.2.1              # Location server hostname or IP
port=1000                   # Location server port
mcc=001                     # Location server mobile country code
mnc=1                       # Location server mobile network code
tac=1                       # Location server tracking area code
cell_id=1                   # Location server cell ID - determines the mountpoint
```

### 4. Deploy systemd services

Two systemd services are deployed:

1. `wait-for-network.service`: Pings a server on the internet until it becomes reachable.
2. `5gtb-daemon.service`: Executes the 5G Testbed script (`5gtb_startup.sh`) on startup, executed once `wait-for-network.service` is successful.

Deploy the systemd service by running:

```console
$HOME/5gtb-rpi/deploy_services.sh
```

---

## Usage

The scripts are executed at startup, so they should work when the RaspberryPi is booted.

Alternatively, the startup script can be run manually, which may be useful for development or debugging.

**Note:** The systemd services should be disabled if running manually, as the output NMEA stream from the serial port will be partially populating multiple files, making the output NMEA files unreadable.

```console
$HOME/5gtb-rpi/startup/5gtb_startup.sh
```

### Accessing Data

NMEA (`.nmea`) and RTCM (`.rtcm`) files can be found in the `$HOME/output` folder.

---

## Troubleshooting

### Accessing Logs

To access the logs of a session, you can do so through `journalctl`:

```console
journalctl -u 5gtb-daemon.service
```

### Disabling systemd services

During development, it may be convenient to stop the startup daemon to halt data logging, and free up resources and serial ports.

To stop the daemon run:

```console
$HOME/5gtb-rpi/disable_services.sh
```

### Modifying startup scripts

The daemon should be pre-configured for your specific demonstrator project. However, if you need to modify how the daemon initialises the startup script you can do so by ...
