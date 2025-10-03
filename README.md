# Klipper Can Update

This script is used to update your current MCU along with Can Bus devices.

## Requirements:
-Katapult <pre>cd ~ && git clone https://github.com/Arksine/katapult</pre>
-MCUs must already be flashed with Katapult and connected.

## Installation:

SSH into the Pi and run the following commands:<pre>cd ~ && git clone https://github.com/Turge08/klipper_can_update</pre>

## Screenshot

<img width="615" height="372" alt="image" src="https://github.com/user-attachments/assets/191c6ec3-09d0-4a75-8056-9427b4875994" />

## Script Functions

1. Upgrade Firmware on MCU(s) - Recompile klipper.bin for the specific board and flash the MCU
2. Add MCU - Scans your printer.cfg (and any includes) for MCUs with UUIDs and adds it to the list of devices to update
3. Remove MCU - Remove MCU from the list of devices to update
4. Maintenance - Remove existing configs, Add new config for your specific MCU
5. Debug Mode - Toggle to display additional information

## Usage

After installing, run the following:

<pre>~/flash.sh</pre>

### Supported MCUs

- octopus: Octopus v1.1/Pro with 446 Processor
- ebb36v11: BigTreeTech EBB 36 v1.1 (1M bus speed)
- sb2040: Mellow FLY-SB2040 (1M bus speed)
- sht36v2: Mellow FLY-SHT36 (1M bus speed)
- Kraken - BTT Kraken (1M buf speed)

### Adding MCU

- A new MCU config can be added through the Maintenance menu. in the "make menuconfig" screen, select the options for your board
