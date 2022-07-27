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

The scripts require `stty` from coreutils and `str2str` from RTKLIB:

```console
sudo apt install coreutils rtklib
```

For OSR positioning, the startup scripts require the [SUPL LPP Client](https://github.com/frontiersi/supl-lpp-client) to connect to a location server and generate RTCM from LPP messages.

Install it by following the instructions in the [GitHub Repository](https://github.com/frontiersi/supl-lpp-client/tree/main#installation).

Ensure that the SUPL LPP Client can be executed from anywhere.

For SSR positioning, the script requires the GMV Positioning Engine (PE) docker image. These scripts don't alter the PE's config, so ensure that it is correctly configured.

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

Determines how the script should operate given the hardware configuration, there are two modes, that can use two types of corrections:

Modes:

1. `positioning`: Outputs positioning solutions in NMEA format to file and TCP server. Use when a RaspberryPi GNSS HAT is connected.
2. `correction`: Outputs RTCM corrections to a file and serial. Use when an independent GNSS receiver is connected by serial port.

Corrections:

1. `osr`: Observation Space Representation correction data is used. In `positioning` mode a GNSS HAT is used to compute positions.
2. `ssr`: State Space Representation correction data is used. In `positioning` mode the GMV PE is used to compute positions.

```text
# Script mode
mode=positioning                # Operation mode (positioning or correction)
correction_type=osr             # The type of corrections to use (osr or ssr)
```

#### GNSS Device

Determines the GNSS device to stream RTCM to, and log NMEA from (if in `positioning` mode and `osr` correction type). Or defines the directory for the GMV PE (if in `positioning` mode and `ssr` corretion type). An optional USB serial port is also provided for SBF (raw GNSS data) logging, comment out if not required.

```text
# GNSS Device
uart_serial_port=/dev/ttyAMA0    # GNSS device UART serial port for NMEA/RTCM
usb_serial_port=/dev/ttyACM0     # (Optional) GNSS device USB serial port for SBF
baud_rate=115200                 # Device baud rate
gmv_pe_dir=/home/pi/5gtb-pe-lpp/ # GMV Positioning Engine directory
```

#### Output Directory

Determines the output directory to log data to.

```text
# Output Directory
output_dir=~/output/            # Directory for output NMEA/RTCM/SBF and log files
```

#### Location Server

Determines the location server network parameters. Sample parameters are provided in the example below.

```text
# Location Server
host=192.0.2.1                  # Location server hostname or IP
port=1000                       # Location server port
mcc=001                         # Location server mobile country code
mnc=1                           # Location server mobile network code
tac=1                           # Location server tracking area code
cell_id=1                       # Location server cell ID - determines the mountpoint
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

The systemd services execute the scripts at startup, so they should work when the RaspberryPi is booted.

Alternatively, the startup script can be run manually, which may be useful for development or debugging:

```console
$HOME/5gtb-rpi/startup/5gtb_startup.sh
```

**Note:** The systemd services should be disabled when running manually, as the serial port will be already in use.

### Accessing Data

NMEA (`.nmea`) and RTCM (`.rtcm`) files logged by the services can be found in the folder set in the [Output Directory](#output-directory) config.

When the services are running, with the `osr` correction type, NMEA messages are also streamed over a TCP server on port `29471`. With the `ssr` correction type, proprietary GMV NMEA is streamed over a TCP server on port `19500`. The stream can be interfaced over the net with `netcat`, `gpsd`, or similar.

### Data Timezone

NMEA (`.nmea`) and RTCM (`.rtcm`) files are named with an ISO time date format (`YYYYMMDD-hhmmss`). These timestamps are in the Australian Eastern Standard Time (AEST) timezone. Please note that the timestamps in the NMEA data is in the Coordinated Universal Time (UTC) timezone.

---

## Diagnostic Scripts

Diagnostic scripts are located in the `scripts/` folder and include the following:

1. `ping_test.sh`: Pings the Google DNS every 200ms and logs to file in the [Output Directory](#output-directory).
2. `temp_test.sh`: Querys the Raspberry Pi temperature every second and logs to file in the [Output Directory](#output-directory).

---

## Troubleshooting

### Accessing Logs

To access the logs of a session, you can do so through `journalctl`:

```console
journalctl -u 5gtb-daemon.service
```

Logs of the SUPL LPP client stdout (`.log`) are also saved to file in the folder set in the [Output Directory](#output-directory) config.

### Disabling systemd services

During development, it may be convenient to stop the startup daemon to halt data logging, and free up resources and serial ports.

To stop the daemon run:

```console
$HOME/5gtb-rpi/disable_services.sh
```
