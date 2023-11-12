# klipper_flash

This script is used to update your current MCU along with Can Bus devices.

## Installation:

SSH into the Pi and run the following commands:<pre>cd ~
git clone https://github.com/Turge08/klipper_can_update</pre>

## Script Functions:

- flash_can <config_name> <uuid>
Flashes a can bus device
- flash_usbtocan <config_name> <uuid> <string_in_serial_path>
Flashes a Can To USB device

<string_in_serial_path>: This is part of the /dev/serial path  the script should look for to identify your MCU in Katapult mode. example: For "/dev/serial/by-id/usb-katapult_stm32f446xx_36003A000A5053424E363420-if00", use "stm32f446xx"

## Configuration:

To configure the script, edit flash.sh using <pre>nano ~/klipper_can_update/update.sh</pre>

### Using an existing config:

To use the existing configs, uncomment one of the lines and add your UUID.

The current list of configs are:

- octopus: Octopus v1.1/Pro with 446 Processor
- ebb36v11: BigTreeTech EBB 36 v1.1 (1M bus speed)
- sb2040: Mellow FLY-SB2040 (1M bus speed)
- sht36v2: Mellow FLY-SHT36 (1M bus speed)

### Using your own config:

- To create your own config, run the following command: <pre>make menuconfig KCONFIG_CONFIG=~/klipper_can_update/<your_config_name>.config</pre> where "<your_config_name>" is the name of the config you'd like to create.

- Add a new line to the script:
Example (if your new config is "ebb36v10": <pre>flash_can ebb36v10 <your_uuid></pre>
