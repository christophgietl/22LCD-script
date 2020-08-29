#!/bin/bash
CONFIG="/boot/config.txt"
CMDLINE="/boot/cmdline.txt"
FONT="ProFont6x11"
FBCP="/usr/local/bin/fbcp"
SPEED="80000000"
ROTATE="90"
FPS="60"
RESOLUTION="320x240"
RESOLUTION_TEMP="640x480"
HDMIGROUP="2"
HDMIMODE="4"
HDMICVT=""
OUTPUT_DEVICE="TFT"
SCREEN_BLANKING="No"
DEVICE="2.4"
SOFTWARE_LIST="xserver-xorg-input-evdev xserver-xorg-input-libinput python-dev python-pip python-smbus python-wxgtk3.0 matchbox-keyboard"
FILE_FBTURBO="/etc/X11/xorg.conf.d/99-fbturbo.conf"
XRANDRSETTINGS="/etc/X11/Xsession.d/45-custom_xrandr-settings"

function check_sysreq(){
	SOFT=$(dpkg -l $SOFTWARE_LIST | grep "un  ")
	if [ -n "$SOFT" ]; then
		apt update
		apt -y install $SOFTWARE_LIST
	fi
}

# Enable tft in config.txt
function enable_tft_config(){
	echo "dtparam=i2c_arm=on" >> $CONFIG
	echo "dtparam=spi=on" >> $CONFIG
	if [ "$DEVICE" == "2.2" ]; then
		echo "dtoverlay=pitft22,speed=$SPEED,rotate=$ROTATE,fps=$FPS" >> $CONFIG
	elif [ "$DEVICE" == "2.4" ]; then
		echo "dtoverlay=pitft28-resistive,speed=$SPEED,rotate=$ROTATE,fps=$FPS" >> $CONFIG
	fi
	if [ -n "$HDMIGROUP" ]; then
		echo "hdmi_group=$HDMIGROUP" >> $CONFIG
	fi
	if [ -n "$HDMIMODE" ]; then
		echo "hdmi_mode=$HDMIMODE" >> $CONFIG
	fi
	if [ -n "$HDMICVT" ]; then
		echo "hdmi_cvt=$HDMICVT" >> $CONFIG
	fi
	echo "hdmi_force_hotplug=1" >> $CONFIG
	
}

function enable_tft_cmdline(){
	FBONCONFIGED=$(cat /boot/cmdline.txt | grep "fbcon=map:10")
	if [ -z "$FBONCONFIGED" ]; then
		sed -i -e 's/rootwait/rootwait fbcon=map:10 fbcon=font:'$FONT'/' $CMDLINE
	fi
}

function enable_blanking(){
	disable_blanking
	sed -i '/^sh -c "TERM=linux/d' /etc/rc.local
	sed -i -e 's/^xserver-command=X -s 0 dpms/#xserver-command=X/' /etc/lightdm/lightdm.conf
}

function disable_blanking(){
	sed -i '/exit 0/ish -c "TERM=linux setterm -blank 0 >/dev/tty0"' /etc/rc.local
	sed -i -e 's/^#xserver-command=X/xserver-command=X -s 0 dpms/' /etc/lightdm/lightdm.conf
}

function enable_tft_x(){
	if [ -e "$FILE_FBTURBO" ] ; then
		rm $FILE_FBTURBO
	fi
	touch $FILE_FBTURBO
	cat << EOF > $FILE_FBTURBO
Section "Device"
  Identifier "Adafruit PiTFT"
  Driver "fbdev"
  Option "fbdev" "/dev/fb1"
EndSection
EOF
}

function disable_tft_x(){
	if [ -e "$FILE_FBTURBO" ] ; then
		rm $FILE_FBTURBO
	fi
}

function enable_both_x(){
	echo "xrandr --output HDMI-1 --mode \"$RESOLUTION_TEMP\"" > $XRANDRSETTINGS
}

function disable_fbcp(){
	sed -i '/^\/usr\/local\/bin\/fbcp/d' /etc/rc.local
}

function enable_fbcp(){
	if [ ! -f "$FBCP" ]; then
		if [ -f "bin/fbcp" ]; then
			chmod +x bin/fbcp
			sudo cp -a bin/fbcp $FBCP
		else
			wget https://github.com/howardqiao/zpod/raw/master/zpod_res/fbcp -O $FBCP
			chmod +x $FBCP
		fi
	else
		chmod +x $FBCP
	fi
	disable_fbcp
	sed -i '/exit 0/i\/usr\/local\/bin\/fbcp &' /etc/rc.local
}

function apply_tft_22_24(){
	sys_reset
	enable_tft_cmdline
	if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
		HDMICVT="240 320 60 1 0 0 0"
	else
		HDMICVT="320 240 60 1 0 0 0"
	fi
	enable_tft_config
	if [ ! -d "/etc/X11/xorg.conf.d" ]; then
		mkdir /etc/X11/xorg.conf.d
	fi
	enable_tft_x
	enable_both_x
	if [ "$DEVICE" == "2.4" ]; then
		generate_touch_24
	fi
	disable_fbcp
}

function apply_tft_hdmi(){
	sys_reset
	enable_tft_config
	enable_both_x
	generate_touch_24
	disable_tft_x
	enable_fbcp
}

function apply(){
	check_sysreq
	HDMIGROUP=2
	HDMIMODE=87
	if [ "$RESOLUTION" == "1024x768" ]; then
		if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
			HDMICVT="768 1024 60 1 0 0 0"
			RESOLUTION_TEMP="768x1024"
		else
			HDMICVT="1024 768 60 1 0 0 0"
			RESOLUTION_TEMP="1024x768"
		fi
	elif [ "$RESOLUTION" == "800x600" ]; then
		if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
			HDMICVT="600 800 60 1 0 0 0"
			RESOLUTION_TEMP="600x800"
		else
			HDMICVT="800 600 60 1 0 0 0"
			RESOLUTION_TEMP="800x600"
		fi
	elif [ "$RESOLUTION" == "640x480" ]; then
		if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
			HDMICVT="480 640 60 1 0 0 0"
			RESOLUTION_TEMP="480x640"
		else
			HDMICVT="640 480 60 1 0 0 0"
			RESOLUTION_TEMP="640x480"
		fi
	else
		if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
			HDMICVT="240 320 60 1 0 0 0"
			RESOLUTION_TEMP="240x320"
		else
			HDMICVT="320 240 60 1 0 0 0"
			RESOLUTION_TEMP="320x240"
		fi
	fi
	case $OUTPUT_DEVICE in
		"TFT")
		apply_tft_22_24
		;;
		"BOTH")
		apply_tft_hdmi
		;;
	esac
	case $SCREEN_BLANKING in 
		"Yes")
		enable_blanking
		;;
		"No")
		disable_blanking
		;;
	esac
	echo "Please reboot."
}

# Permission detection
if [ $UID -ne 0 ]; then
    printf "Superuser privileges are required to run this script.\ne.g. \"sudo %s\"\n" "$0"
    exit 1
fi

apply
