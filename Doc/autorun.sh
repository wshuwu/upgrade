echo "###############################"

diskpath=$(lsblk -f | grep gold | awk -F ' ' '{print $5}')
cd ${diskpath}


export QT5_12_2PATH="/opt/aarch64_qt5.12.2"
export LD_LIBRARY_PATH=$QT5_12_2PATH/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=$QT5_12_2PATH/lib:$LIBRARY_PATH
export C_INCLUDE_PATH=$QT5_12_2PATH/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$QT5_12_2PATH/include:$CPLUS_INCLUDE_PATH
export PATH=$QT5_12_2PATH/bin:$PATH
export PKG_CONFIG_PATH=$QT5_12_2PATH/lib/pkgconfig:$PKG_CONFIG_PATH
export QT_QPA_PLATFORM_PLUGIN_PATH=$QT5_12_2PATH/plugins
export QT_QPA_PLATFORM=xcb
export QT_QPA_EGLFS_INTEGRATION=XCB_EGL
export DISPLAY=:0

rm /home/gold/.config/autostart/HwTest.desktop 


#关闭内部4G模块电源
if [ -f ${diskpath}/OFF4G.txt ]
then
	powerStatus=$(cat /etc/rc.local | grep '/sys/class/gpio/gpio8/value' |awk -F' ' '{print $2}')
	if [ $powerStatus -eq 1 ]  #1-开启执行关闭
	then
		sh /app/aarch64/esmu/shell/set-4g-power-down.sh
	fi
fi

#开启4G模块电源
if [ -f ${diskpath}/ON4G.txt ]
then
	powerStatus=$(cat /etc/rc.local | grep '/sys/class/gpio/gpio8/value' |awk -F' ' '{print $2}')
	if [ $powerStatus -eq 0 ]  #1-开启执行关闭
	then
		sh /app/aarch64/esmu/shell/set-4g-power-up.sh
	fi
fi


killall chromium-browser
service lighttpd stop
rm -Rf /var/cache/lighttpd/compress/*
sync


lsblk -f | grep gold | grep vfat
if [ $? -eq 0 ] && [ -f ${diskpath}/upgrade ]
then
	killall chromium-browser
	rm -Rf /home/gold/install.sh
	cp -av ./upgrade  /tmp/
	chmod +x  /tmp/upgrade
	/tmp/upgrade ${diskpath}/install.sh
else
	lsblk -f | grep gold | grep exfat
	if [ $? -eq 0 ] && [ -f ${diskpath}/upgrade ]
	then
		echo ""
		./upgrade
	else
		sh ./install.sh
	fi
fi




sync
sleep 10
sync
sync
echo "---------------------------OK-----------------------------------"

while [ -d ${diskpath} ]
do
	echo 1  >  /sys/class/gpio/gpio29/value    #蜂鸣
	sleep 0.1
	echo 0  >  /sys/class/gpio/gpio29/value
	sleep 0.1
done
sleep 1
reboot

