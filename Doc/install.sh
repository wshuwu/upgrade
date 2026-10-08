#!/bin/sh


#U盘路径
diskpath=$(lsblk -f | grep gold | awk -F ' ' '{print $5}'|grep PDI)
PD=$(date "+%Y%m%d")

#读取版本
packVer='x'
if [ -f /app/aarch64/lems/ver.txt ]
then
	packVer=$(cat  /app/aarch64/lems/ver.txt | grep lemsVer| awk -F'=' '{print $2}')
fi

current_timestamp=$(date +%s)

#设置机器序列号
/app/aarch64/esmu/shell/esccuid-setup.sh

#停止浏览器
ps -ef |grep chromium-browser|grep -v grep| grep -v  $$
if [ $? -eq 0 ]
then
	killall chromium-browser
fi

bell(){
	cnt=0
	while [ $cnt -lt $1 ]
	do
		echo 1  >  /sys/class/gpio/gpio29/value    #蜂鸣
		sleep 0.1
		echo 0  >  /sys/class/gpio/gpio29/value
		sleep 0.1
		cnt=$(expr $cnt + 1)
	done
}

echo "升级脚本exportpack-install.sh版本v1.6"   > /tmp/upgrade.log

cat /etc/update-motd.d/10-help-text | grep ESCCU > /dev/null
if [ $? -eq 1 ];
then
	echo "系统种置中请稍等..."   >> /tmp/upgrade.log
	exit 1
fi


echo "即将执行应用软件更新安装..."   >> /tmp/upgrade.log
bell 1

echo "开始监测硬件版本信息..."   >> /tmp/upgrade.log
bell  1


adc4ver=$(cat /sys/bus/iio/devices/iio:device0/in_voltage3_raw)
HwVer=$(eeprom4esmu t | grep escu.PCBA|awk -F'=' '{print $2}')
oldVer=$(echo $HwVer|cut -c 1)
if [ -n "$HwVer" ] || [ $HwVer="" ];then

	echo "硬件版本信息为空!"   >> /tmp/upgrade.log
	echo "进行硬件特征检测..."  >> /tmp/upgrade.log
	bell 1

	adc4ver=$(cat /sys/bus/iio/devices/iio:device0/in_voltage3_raw)
	if [ $adc4ver -gt 990 ];then
		echo "通过硬件特征判断为第1版硬件"   >> /tmp/upgrade.log

		HwVer='ESCCU2003'		
	fi

	if [ $adc4ver -gt 480 ] && [ $adc4ver -lt 540 ];then
		echo "通过硬件特征判断为第2版硬件"   >> /tmp/upgrade.log
		HwVer='ESCCU201'		
	fi
fi

echo "硬件版本信息:$HwVer"

if [ -n "$HwVer" ];then
	echo "硬件版本:$HwVer"   >> /tmp/upgrade.log
	bell 2
	
	if [ "$HwVer" = 'ESCCU201' ] || [ "$HwVer" = 'ESCCU2003' ]
	then
		echo "确认为可兼容硬件"
	else
		echo "硬件版本不适配,终止升级执行" > /tmp/upgrade.log
		exit 0
	fi
else
	echo "当前升级无法兼容此硬件版本"
	echo "当前升级无法兼容此硬件版本" >> /tmp/upgrade.log
	exit 0
fi


ccu_projId=$(eeprom4esmu t | grep escu.serviceID | awk -F'=' '{print $2}' |  tr '[a-z]' '[A-Z]')

#停止http服务
service lighttpd stop
mkdir -p /app/aarch64


tarFileSums=$(ls *[eE][sS]*offline*.tar.gz | wc -l)
if [ $tarFileSums -gt 1 ]
then
	echo "存在多个离线升级包"   >> /tmp/upgrade.log
	exit 1
else  if [ $tarFileSums -lt 1 ]
	then
		echo "没有项目${ccu_projId}匹配的离线安装包"   >> /tmp/upgrade.log
		exit 1
	fi
fi


tarFile=$(ls *[eE][sS]*offline*.tar.gz -l 2>/dev/null| head -n 1| awk -F' ' '{print $9}')
echo "tarFile=${tarFile}"

packFileName=$(echo ${tarFile%%.*})

echo ${packFileName} | grep '_offline' > /dev/null
if [ $? -eq 0 ] && [ $(echo $packFileName|cut -b 1-7) = "AARCH64" ]
then
	#导出版本AARCH64
	pack_projId=$(echo ${packFileName}|awk -F '_' '{print $1}'|awk -F'-' '{print $7}'|tr '[a-z]' '[A-Z]')
else
	pack_projId=$(echo ${packFileName}|awk -F '_' '{print $1}'|awk -F'-' '{print $3}'|tr '[a-z]' '[A-Z]')
fi



ccu_pml=$(echo ${packFileName}|awk -F'-' '{print $2}'|tr '[A-Z]' '[a-z]')

if [ -z $ccu_projId ] || [ ! -d /app/aarch64/lems ] && [ ! -d /app/aarch64/escu/device ]
then
	echo "在无项目软件的设备上执行安装..."   >> /tmp/upgrade.log
	eeprom4esmu  set.PML ${ccu_pml}
	eeprom4esmu  set.serviceID  ${pack_projId}
else
	
	pack_projId_tolower=$(echo "$pack_projId" | awk '{print tolower($0)}')
	ccu_projId_tolower=$(echo "$ccu_projId" | awk '{print tolower($0)}')
	echo "当前安装包项目号: $pack_projId_tolower 与 设备项目号: $ccu_projId_tolower "   >> /tmp/upgrade.log
	
	#echo "$pack_projId_tolower" | grep -q "$ccu_projId_tolower" >/dev/null
    if [ $pack_projId_tolower != $ccu_projId_tolower ]
	then
		stamp=$(date +"%s")
		etamp=$(expr $stamp + 10)
		while [ 1 ]
		do
			stamp=$(date +"%s")
			diff_t=$(expr $etamp - $stamp)
			
			echo "该设备原有项目编号${ccu_projId},当前升级包适用项目编号${pack_projId}"   > /tmp/upgrade.log	
			if [ -d ${diskpath}/factorymode ];then
				echo "当前升级U盘已经强制为工厂模式,即将在$diff_t秒后进行系统还原"        > /tmp/upgrade.log
				if [ $diff_t -lt 1 ];then					
					bell 3
					#执行系统复位
					eeprom4esmu  set.serviceID  ${pack_projId}
					echo "执行recovery..."
					recovery reset
					sleep 5
				fi
				bell  1
				sleep 1
			else
				echo "软件升级必须在同一项目编号的机器上执行,解决方案:"   >> /tmp/upgrade.log
				echo "1.请确认项目应用软件是否正确"   >> /tmp/upgrade.log
				echo "2.现有设备上通过SD卡初始化系统至纯系统模式"   >> /tmp/upgrade.log
				echo "3.在升级U盘上创建factorymode目录,强制进入工厂升级模式"   >> /tmp/upgrade.log
				bell 30
				exit 1
			fi

		done
	fi
fi



#if [ -d ${diskpath}/recovery_config ]
#then
#	#导出参数配置
#	if [ -f /usr/local/bin/export-proj-pack-dep.sh ]
#	then
#		echo "导出项依赖配置参数..."
#		cd /home/gold/
#		sh /usr/local/bin/export-proj-pack-dep.sh
#		#备份文件至升级U盘
#		if [ -f ${diskpath}/autorun.sh ] && [ $(ls es*-proj-${ccu_projId}*.deb|wc -l) -gt 0 ]
#		then
#			mkdir -p /${diskpath}/${ccu_projId}
#			cp -av es*-proj-${ccu_projId}*.deb  /${diskpath}/${ccu_projId}/
#		fi
#		sleep 3
#		cd -
#	fi
#fi

#tarFile=$(ls es[cm]u-proj-*${ccu_projId}*_offline-pack*.*  -l | head -n 1| awk -F' ' '{print $9}')

echo "离线包${tarFile}开始解压安装"   >> /tmp/upgrade.log
echo "项目离线包${tarFile}开始解压安装"

tar -jxvf ${tarFile} -C /home/gold
cd /home/gold/offline-pack
if [ ! -d /app/aarch64/lems/lib ]
then
	mkdir -p /app/aarch64/lems/lib
fi
if [ ! -d /app/aarch64/escu/device/data/api/lib ]
then
	mkdir -p /app/aarch64/escu/device/data/api/lib
fi

#sh install-deb.sh
while read txt_line
do
        proj_deb=$(ls ./pack/${txt_line}_*.deb  -lr | head -n 1| awk -F' ' '{print $9}')
        echo "安装包:${proj_deb}"
        dpkg -i ${proj_deb}
		if [ $? -eq 1 ]
		then
			echo "软件包:$proj_deb安装异常"  >> /tmp/upgrade.log
		fi
		
done  < /home/gold/offline-pack/install-deb.list



#删除格式化的脚本
if [ -f /app/aarch64/esmu/shell/install-ssd.sh ]
then
	rm  /app/aarch64/esmu/shell/install-ssd.sh   #引起ssd格式化
fi

#删除外部看门狗
if [ -f /app/aarch64/esmu/shell/extwdt.sh ]
then
	rm  /app/aarch64/esmu/shell/extwdt.sh
fi


#注释exit语句
sed -i 's/^exit/#&/'  /etc/rc.local

rm -Rf  /home/gold/.cache/chromium/     #清除缓存
rm -Rf  /home/gold/.config/chromium/     #清除浏览器配置,否则可能首页白屏

delFileSums=$(ls /var/cache/lighttpd/compress/ | wc -l)
if [ $delFileSums -gt 0 ]
then
	rm -r /var/cache/lighttpd/compress/*    #开机白屏清除缓存
fi


#从机配置差异文件升级-北人电表从机从主机读取
if [ -f ${diskpath}/SlaveESCCU.txt ]
then
	echo "这是一个从设备...准备开始复制从设备参数"
    	cp -r ${diskpath}/uart.json  /app/aarch64/lems/config/protocol_conf/
	chmod 775 /app/aarch64/lems/config/protocol_conf/uart.json
	cat  /app/aarch64/lems/config/protocol_conf/uart.json
else
	echo "当前是主设备模式..."
fi

if [ -f /app/aarch64/lems/config/lcd_backlight.ini ]
then
	cat  /app/aarch64/lems/config/lcd_backlight.ini|grep weburl|grep http >/dev/null
	if [ $? -eq 1 ]
	then
		rm -f /app/aarch64/lems/config/lcd_backlight.ini
	fi
fi

sync
sync
sync

cat /etc/security/limits.conf | grep 'soft nofile'
if [ $? -eq 1 ]
then
	echo "* soft nofile 65535"  >> /etc/security/limits.conf
	echo "* hard nofile 65535"  >> /etc/security/limits.conf
fi

if [ "$HwVer" = "ESCCU201" ];then

	echo "#ttyS9ttyS5"   > /tmp/Hw2.0.1.patch
	echo "HwVer=\$(eeprom4esmu t | grep escu.PCBA|awk -F'=' '{print \$2}')"  >> /tmp/Hw2.0.1.patch
	echo "if [ -c /dev/ttyS9 ] &&  [ \"\$HwVer\" = \"ESCCU201\" ];" >> /tmp/Hw2.0.1.patch
	echo "then" >> /tmp/Hw2.0.1.patch
	echo "	ln -s /dev/ttyS9 /dev/ttyS5" >> /tmp/Hw2.0.1.patch
	echo "fi" >> /tmp/Hw2.0.1.patch
	echo "####" >> /tmp/Hw2.0.1.patch

	echo "ttyS9转ttyS5..."
	cat /etc/rc.local|grep ttyS9ttyS5 > /dev/null		
	if [ $? -eq 1 ] && [ -f /tmp/Hw2.0.1.patch ];then
		echo "2.0.1串口问题创建软链接..."
		sed -i '2r /tmp/Hw2.0.1.patch' /etc/rc.local
	else
		echo "不需处理ttyS9转ttyS5"
	fi

fi


if [ -f  /app/aarch64/lems/config/ifup-eth0.sh  ]
then 
	cp  -r /app/aarch64/lems/config/ifup-eth0.sh  /app/aarch64/esmu/shell/
fi


sync
sync
sync

echo "软件安装结束,即将进行系统重启!"   >> /tmp/upgrade.log
bell 5
sleep 1
