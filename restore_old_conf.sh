#!/bin/bash

if ! grep -q "Raspberry Pi" /proc/device-tree/model; then
	echo "This script is only compatible with Raspberry Pi"
	exit 1
fi

old='#_OLD_CONF_'
bootconfig=/boot/config.txt

# Remove our config
sed -i '/^hdmi_force_hotplug=1$/d' $bootconfig
sed -i '/^config_hdmi_boost=7$/d' $bootconfig
sed -i '/^hdmi_drive=1$/d' $bootconfig
sed -i '/^hdmi_group=2$/d' $bootconfig
sed -i '/^hdmi_mode=87$/d' $bootconfig
sed -i '/^hdmi_cvt 480 320 60 6 0 0 0$/d' $bootconfig
sed -i '/^dtoverlay=ads7846,cs=1,penirq=25,penirq_pull=2,speed=50000,keep_vref_on=0,swapxy=0,pmax=255,xohms=150,xmin=200,xmax=3900,ymin=200,ymax=3900$/d' $bootconfig
sed -i '/^display_rotate=0$/d' $bootconfig

# Restore old config
sed -i "s/$old//" $bootconfig