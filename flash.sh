#!/bin/bash

SRCDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ~/klipper

function flash_usbtocan() {
   echo "Flashing $1 with UUID $2"
   config=$SRCDIR/$1.config
   if test -f $config; then
      path=$(ls /dev/serial/by-id/*$3*)
      if [ ! -n "${path}" ]; then
         python3 ~/katapult/scripts/flash_can.py -u $2 -r
         sleep 1
         path=$(ls /dev/serial/by-id/*$3*)
      fi
      if [ -n "${path}" ]; then
         echo "Found MCU path: $path"
         make clean
         make -j4 KCONFIG_CONFIG=$config
         path=$(ls /dev/serial/by-id/*$3*)
         echo "Flashing Klipper to $path"
         python3 ~/katapult/scripts/flash_can.py -d $path
      else
         echo "Couldn't find serial device $serialpath"
      fi
   else
      echo "Couldn't find $config"
   fi
}

function flash_can() {
   echo "Flashing $1 with UUID $2"
   config=$SRCDIR/$1.config
   if test -f $config; then
      make clean
      make -j4 KCONFIG_CONFIG=$config
      python3 ~/katapult/scripts/flash_can.py -u $2
   else
      echo "Couldn't find $config"
   fi
}


sudo service klipper stop

flash_usbtocan octopus 1391e320e300 stm32f446xx
#flash_can ebb36v11 <your_uuid>
#flash_can sb2040 <your_uuid>
#flash_can sb2209 <your_uuid>
flash_can sht36v2 44f73d603f57

# ** Add new entries above here **

sudo service klipper restart
