#!/bin/bash

if ! grep -q "Raspberry Pi" /proc/device-tree/model; then
	echo "This script is only compatible with Raspberry Pi"
	exit 1
fi

old='#_OLD_CONF_'
bootconfig=/boot/config.txt

#Save old config
#sed -i -r "s/^(disable_overscan=1)/$old\1/" $bootconfig #If overscan is disabled, enable it
sed -i -r "s/^(hdmi_force_hotplug)/$old\1/" $bootconfig
sed -i -r "s/^(config_hdmi_boost)/$old\1/" $bootconfig
sed -i -r "s/^(hdmi_drive)/$old\1/" $bootconfig
sed -i -r "s/^(hdmi_group)/$old\1/" $bootconfig
sed -i -r "s/^(hdmi_mode)/$old\1/" $bootconfig
sed -i -r "s/^(hdmi_cvt)/$old\1/" $bootconfig
sed -i -r "s/^(dtoverlay)/$old\1/" $bootconfig
sed -i -r "s/^(display_rotate)/$old\1/" $bootconfig

# Write new config
echo 'hdmi_force_hotplug=1' >> $bootconfig
echo 'config_hdmi_boost=7' >> $bootconfig
echo 'hdmi_drive=1' >> $bootconfig
echo 'hdmi_group=2' >> $bootconfig
echo 'hdmi_mode=87' >> $bootconfig
echo 'hdmi_cvt 480 320 60 6 0 0 0' >> $bootconfig
echo 'dtoverlay=ads7846,cs=1,penirq=25,penirq_pull=2,speed=50000,keep_vref_on=0,swapxy=0,pmax=255,xohms=150,xmin=200,xmax=3900,ymin=200,ymax=3900' >> $bootconfig
echo 'display_rotate=0' >> $bootconfig