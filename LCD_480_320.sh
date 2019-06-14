#!/bin/bash
# Part of raspi-lcd 
# https://github.com/fschlaef/raspi-lcd
#
# See LICENSE file for copyright and license details

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

usage() {
    echo "usage: $0 [-ufh]"
    echo "  -u | --uninstall  uninstall driver"
    echo "  -f | --force      force"
    echo "  -h 				  display help"
    exit 1
}

# New boot config for LCD display
declare -A boot_config
boot_config=(
	[disable_overscan]="0"
	[hdmi_force_hotplug]="1"
	[config_hdmi_boost]="7"
	[hdmi_drive]="1"
	[hdmi_group]="2"
	[hdmi_mode]="87"
	[hdmi_cvt]="480 320 60 6 0 0 0"
	[dtoverlay]="ads7846,cs=1,penirq=25,penirq_pull=2,speed=50000,keep_vref_on=0,pmax=255,xohms=150"
	[display_rotate]="0"
)

FORCE=0
UNINSTALL=0

# Parsing arguments
while [ "$1" != "" ]; do
    case $1 in
        -f | --force)
			FORCE=1
			;;
		-u | --uninstall)
			UNINSTALL=1
			;;
        -h | --help )
			usage
			exit
			;;
        * )     
			echo "Invalid parameter $1"
			usage
			exit 1
    esac
    shift
done

# Testing if machine is a Raspberry Pi or not
machine_is_raspi=$(grep -c "Raspberry Pi" /proc/device-tree/model)
if (( ! machine_is_raspi )) && (( $FORCE == 0 )); then
	echo "This script is only compatible with Raspberry Pi. Use -f to ignore this warning and proceed anyway."
	exit 1
fi

query_reboot() {
	read -p "Reboot now ? [Y/N/q] : " -n 1 -r choice
	case "$choice" in 
		y|Y) 
			echo -e "\nRebooting ..."
			reboot
			;;
		n|N|q|Q)
			echo ""
			exit 1
			;;
		*)
			echo -e "\nInvalid input"
			query_reboot
			;;
	esac
}

old='#OLD_CONFIG_'
new='#LCD_CUSTOM_CONFIG'
bootconfig=/boot/config.txt

restore_boot_config() {
	echo "Restoring $bootconfig values ..."
	
	# Remove our config
	sed -i "/$new$/d" $bootconfig

	# Restore old config
	sed -i "s/$old//" $bootconfig
}

if (( $UNINSTALL == 1 )); then
	echo "Uninstalling ..."
	restore_boot_config
	echo "Uninstalling evdev ..."
	apt-get remove --yes xserver-xorg-input-evdev
	echo "Uninstall done. A reboot is needed."
	query_reboot
	exit 0
fi

do_not_change_boot_config=0

test_boot_config() {
	if grep -q $old $bootconfig; then
		read -p "LCD configuration found in $bootconfig. Do you want to restore config ? [Y/N/q] : " -n 1 -r choice
		case "$choice" in 
			y|Y) 
				echo ""
				restore_boot_config
				;;
			n|N)
				echo -e "\nBoot config unchanged."
				do_not_change_boot_config=1
				;;
			q|Q)
				echo ""
				exit 1
				;;
			*)
				echo -e "\nInvalid input"
				test_boot_config
				;;
		esac
	fi
}

test_boot_config

install_evdev() {
	evdev_installed=$(dpkg-query -W -f='${Status}\n' xserver-xorg-input-evdev | grep -c "install ok installed")
	if (( $evdev_installed == 1 )); then
		# If evdev is already installed, we assume the user knows what they are doing and don't change anything
		echo "evdev already installed. Nothing to do."
	else
		echo "evdev not installed. Installing now ..."
		apt-get install --yes xserver-xorg-input-evdev
		
		echo "Removing default evdev config and installing touchscreen-only config"
		rm /usr/share/X11/xorg.conf.d/10-evdev.conf
		cat > /usr/share/X11/xorg.conf.d/45-evdev-touchscreen.conf <<EOM
# evdev match for touchscreen only

Section "InputClass"
	Identifier "evdev touchscreen catchall"
	MatchIsTouchscreen "on"
	MatchDevicePath "/dev/input/event*"
	Driver "evdev"
	EndSection
EOM
	fi
}

install_evdev

set_calibration_conf() {
	# Look for existing calibration config file
	calibration_conf_file=(/usr/share/X11/xorg.conf.d/*calibration.conf)

	write_calibration_conf() {
		cat > "$calibration_conf_file" <<EOM
Section "InputClass"
	Identifier      "calibration"
	MatchProduct    "ADS7846 Touchscreen"
	Option  "Calibration"   "3945 233 3939 183"
	Option  "SwapAxes"      "1"
EndSection
EOM
	}
	
	if [ -f "$calibration_conf_file" ]; then
		read -p "$calibration_conf_file already exists. Overwrite ? [Y/N/q] : " -n 1 -r choice
		case "$choice" in 
			y|Y) 
				echo -e "\nOwerwriting calibration config ..."
				write_calibration_conf
				;;
			n|N)
				echo -e "\nCalibration config unchanged."
				;;
			q|Q)
				echo ""
				exit 1
				;;
			*) 
				echo -e "\nInvalid input"
				set_calibration_conf
				;;
		esac
	else
		# If file doesn't exist, create it
		calibration_conf_file=/usr/share/X11/xorg.conf.d/99-calibration.conf
		echo "Calibration config file doesn't exists. Creating it ..."
		write_calibration_conf
	fi
}

set_calibration_conf

write_boot_config() {
	if (( $do_not_change_boot_config == 1 )); then
		echo "Boot config already set. Nothing to do"
	else
		echo "Saving $bootconfig current values and writing new config ..."
		
		# Backup old config and write new one
		for i in "${!boot_config[@]}"
		do
			key=$i
			value=${boot_config[$i]}
			sed -i -r "s/^($key)/$old\1/" $bootconfig
			echo "$key=$value $new" >> "$bootconfig"
		done
	fi
}

write_boot_config

echo "Install done. A reboot is needed to start using your touchscreen"
query_reboot
