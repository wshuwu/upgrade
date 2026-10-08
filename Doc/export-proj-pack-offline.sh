#!/bin/bash

# 声明全局关联数组（需要bash 4.0+）
declare -gA processed_packages  # 用于存储已处理的包名

#依赖文件按次序添加
depend_add_file(){

	local packName=$1
	local debVer=$2
	local levelCnt=$3

    # 当层级为0时重置数组（顶层调用）
    if (( levelCnt == 0 )); then
        processed_packages=()  # 清空数组
    fi

    # 检查是否已存在该包名
    if [[ -n "${processed_packages[$packName]}" ]]; then
        echo "跳过重复包: $packName (层级: $levelCnt)"
        return 1
    fi

    # 标记为已处理
    processed_packages["$packName"]=1

	levelCnt=$(expr $levelCnt + 1)
	
	local preTab=''
	i=0
	while [ "$i" -lt "$levelCnt" ];do
		preTab="    ${preTab}"
		i=$(expr $i + 1)
	done

	#版本依赖
	#apt-cache depends ${packName} |awk '{$1=$1; print}'| grep  ^PreDepends: | awk -F ':' '{print $2}' >./dependlist_${packName}
	dpkg -s ${packName}|grep -oP 'Pre-Depends:\s*\K.*' | sed -E 's/\([^)]+\)//g' | tr -d ' ' | tr ',' '\n' >./dependlist_${packName}
	packNum=$(cat ./dependlist_${packName}|wc -l)
	
	if [ -n "$packNum" ] && [ "$packNum" -gt 0 ]
	then
		echo "${preTab}包:${packName}存在依赖"
		
		#依赖列表的版本确认
		dpkg-query -s ${packName} |awk '{$1=$1; print}'| grep ^Pre-Depends | sed 's/Pre-Depends: //' | tr ',' '\n' | awk -F'(' '{print $1 " " $2}' | sed 's/[()]//g' | sed 's/^[[:space:]]*//' > ./dependlist_${packName}_ver
		depNum=$(cat ./dependlist_${packName}_ver|wc -l)
		if [ -n "$depNum" ] && [ "$depNum" -gt 0 ]
		then
			while read dep_line; do
				dep_name=$(echo $dep_line | awk '{print $1}')
				required_version=$(echo $dep_line | awk '{print $3}')
				installed_version=$(dpkg-query -W -f='${Version}' "$dep_name")
				
				if [ -n "$required_version" ] && [ -n "$installed_version" ]
				then
					# 比较版本号，检查安装包版本是否满足要求
					dpkg --compare-versions "$installed_version" "ge" "$required_version"

					# 输出检查结果
					if [ $? -ne 0 ]; then
						echo "$dep_name的当前版本:($installed_version) ,低于${packName}要求版本:($required_version)" >> ./dep_ver_old.list
					fi
				fi
				
			done < ./dependlist_${packName}_ver
		fi
		#依赖列表的版本确认end	
		
		while read depend_Name
		do			

			deb_ver=$(dpkg-query -W -f='${Version}' "$depend_Name")
			echo "${preTab}依赖包名为:${depend_Name},版本:${deb_ver}"
			grep -q "${depend_Name}_${deb_ver}" ./install-deb.list
			if [ $? -eq 0 ]
			then
				echo "${preTab}依赖包:${packName}_${debVer}已存在"
				continue
			fi
			depend_add_file $depend_Name $deb_ver $levelCnt
		done < ./dependlist_${packName}
		
		echo "${preTab}当前包:${packName}_${debVer}依赖添加完成"
		#cat ./install-deb.list|grep ${packName}_${debVer} >/dev/null
		grep -q "${packName}_${debVer}" ./install-deb.list
		if [ $? -eq 1 ]
		then
			echo "${preTab}当前包:${packName}_${debVer}不存在,执行依赖顺序列表添加"
			echo  "包:${packName}_${debVer}追加至install-deb.list"			
			echo  "${packName}_${debVer}"  >>   ./install-deb.list
		else
			echo "${preTab}当前包:${packName}_${debVer}已经存在,无需添加"
		fi
		return 1
	else
		#已经没有依赖
		#cat ./install-deb.list|grep ${packName}_${debVer} >/dev/null
		grep -q "${packName}_${debVer}" ./install-deb.list
		if [ $? -eq 1 ]
		then
			echo "${preTab}依赖包:${packName}_${debVer}不存在,执行依赖顺序列表添加"
			echo  "${packName}_${debVer}"  >>   ./install-deb.list
		fi
	fi
	return 0
	
}

#安装脚本文件
gc_install_shell(){	
	echo "#!/bin/bash"   >./install-deb.sh
	echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib'  >>./install-deb.sh

	echo '[ -f /app/aarch64/lems/config/export_offline_history.txt ] && cp -av /app/aarch64/lems/config/export_offline_history.txt /home/gold/offline-pack/'  >>./install-deb.sh
	echo '[ -f /app/aarch64/lems/config/offline-pack-file.txt ] &&  cp -av /app/aarch64/lems/config/offline-pack-file.txt /app/aarch64/lems/config/'  >>./install-deb.sh

	#安装后执行脚本
	echo '[ -f /home/gold/offline-pack/pre_install.sh ] && bash /home/gold/offline-pack/pre_install.sh '  >>./install-deb.sh
	#备份参数文件
	echo '[ -d /app/aarch64/lems/config ] && mkdir -p /home/gold/config_bak;cp -av /app/aarch64/lems/config/* /home/gold/config_bak'     >>./install-deb.sh

	#忽略备份参数文件
	echo '#忽略备份参数文件清单'     >>./install-deb.sh
	echo 'if [ -f /app/aarch64/lems/config/backup_ignore.list ]'     >>./install-deb.sh
	echo 'then'     >>./install-deb.sh
	echo '	busybox dos2unix /app/aarch64/lems/config/backup_ignore.list'     >>./install-deb.sh
	echo '	while read txt_line'     >>./install-deb.sh
	echo '	do'     >>./install-deb.sh
	echo '		echo "忽略备份参数文件:$txt_line"'     >>./install-deb.sh
	echo '		if [ -n "$txt_line" ]'     >>./install-deb.sh
	echo '		then'     >>./install-deb.sh
	echo '			#非空才可以执行删除'     >>./install-deb.sh
	echo '			rm -Rf /home/gold/config_bak/$txt_line'     >>./install-deb.sh
	echo '		fi'     >>./install-deb.sh
	echo '	done  < /app/aarch64/lems/config/backup_ignore.list'     >>./install-deb.sh
	
	echo 'else'     >>./install-deb.sh
	#EDA策略执行配置默认不备份
	echo '  #EDA策略执行配置默认不备份'     >>./install-deb.sh
	echo '	[ -d /home/gold/config_bak/eventTriggeredSrv_conf ] && rm -Rf /home/gold/config_bak/eventTriggeredSrv_conf'     >>./install-deb.sh
	echo 'fi'     >>./install-deb.sh

	#安装包要求本次忽略
	echo '#安装包要求本次忽略清单'     >>./install-deb.sh
	echo 'if [ -f /home/gold/offline-pack/backup_ignore_once.list ]'     >>./install-deb.sh
	echo 'then'     >>./install-deb.sh
	echo '	busybox dos2unix /home/gold/offline-pack/backup_ignore_once.list'     >>./install-deb.sh
	echo '	while read txt_line'     >>./install-deb.sh
	echo '	do'     >>./install-deb.sh
	echo '		echo "忽略备份参数文件:$txt_line"'     >>./install-deb.sh
	echo '		if [ -n "$txt_line" ]'     >>./install-deb.sh
	echo '		then'     >>./install-deb.sh
	echo '			#非空才可以执行删除'     >>./install-deb.sh
	echo '			rm -Rf /home/gold/config_bak/$txt_line'     >>./install-deb.sh
	echo '		fi'     >>./install-deb.sh
	echo '	done  < /home/gold/offline-pack/backup_ignore_once.list'     >>./install-deb.sh
	echo 'fi'     >>./install-deb.sh

	echo 'while read txt_line'  >>./install-deb.sh
	echo 'do'                             >>./install-deb.sh
	echo "	proj_deb=\$(ls ./pack/\${txt_line}_*.deb  -lr | head -n 1| awk -F' ' '{print \$9}')" >>./install-deb.sh
	echo '	echo "安装包:${proj_deb}"' >>./install-deb.sh
	echo '	dpkg -i ${proj_deb}' >>./install-deb.sh
	
	echo '	if [ $? -eq 1 ]' >>./install-deb.sh
	echo '	then' >>./install-deb.sh
	echo '		if  [ -f /tmp/upgrade.log ]' >>./install-deb.sh
	echo '		then' >>./install-deb.sh
	echo '			echo "软件包:$proj_deb安装异常"  >> /tmp/upgrade.log' >>./install-deb.sh
	echo '		fi' >>./install-deb.sh
	echo '	fi' >>./install-deb.sh
	
	echo 'done  < ./install-deb.list'     >>./install-deb.sh
	echo '' >>./install-deb.sh

	#执行项目配置切换
	echo 'if [ -f /home/gold/offline-pack/project_config.sh ]; then'     >>./install-deb.sh
	echo '	sh /home/gold/offline-pack/project_config.sh'     >>./install-deb.sh
	echo 'fi'     >>./install-deb.sh

	#恢复前执行脚本
	echo '[ -f /home/gold/offline-pack/pre_recovery.sh ] && bash /home/gold/offline-pack/pre_recovery.sh '  >>./install-deb.sh



	#恢复参数文件
	echo '[ -d /home/gold/config_bak ] && python3 /usr/local/bin/copy_json_file_content.py /home/gold/config_bak /app/aarch64/lems/config'     >>./install-deb.sh
	
	#本次安装强制定位内容覆盖
	echo '#本次安装强制定位内容覆盖'     >>./install-deb.sh
	echo '[ -d /home/gold/offline-pack/config_force ] && python3 /usr/local/bin/copy_json_file_content.py /home/gold/offline-pack/config_force /app/aarch64/lems/config'     >>./install-deb.sh
	
	#安装后执行脚本
	echo '[ -f /home/gold/offline-pack/post_install.sh ] && bash /home/gold/offline-pack/post_install.sh '  >>./install-deb.sh

	#复制历史信息文件
	echo '[ -f /home/gold/offline-pack/export_offline_history.txt ] && cp -av /home/gold/offline-pack/export_offline_history.txt /app/aarch64/lems/config/'  >>./install-deb.sh
	echo '[ -f /home/gold/offline-pack/offline-pack-file.txt ] && cp -av /home/gold/offline-pack/offline-pack-file.txt /app/aarch64/lems/config/'  >>./install-deb.sh

}

#安装脚本文件
projconf_install_shell(){
	echo "#!/bin/bash"   >./project_config.sh
	echo '' >>./project_config.sh
	echo 'if [ -f /home/gold/offline-pack/project_config/projConfigPackage.json ]; then'     >>./project_config.sh
	echo '	mkdir -p /app/aarch64/lems/config/projConfigPackage/'     >>./project_config.sh
	echo '	rm -Rf /app/aarch64/lems/config/projConfigPackage/*'     >>./project_config.sh
	echo '	cp -av /home/gold/offline-pack/project_config/* /app/aarch64/lems/config/projConfigPackage/'     >>./project_config.sh
	echo "	installSrvId=\$(eeprom4esmu t| grep  escu.serviceID | awk -F '=' '{print \$2}'| tr 'a-z' 'A-Z')"   >>./project_config.sh
	echo '	bash /usr/local/bin/projectConfigActive.sh $installSrvId'     >>./project_config.sh
	echo 'fi'     >>./project_config.sh
}

#项目编号
projSrvId=$(eeprom4esmu t| grep  escu.serviceID | awk -F '=' '{print $2}'| tr 'A-Z' 'a-z')
PML=$(eeprom4esmu t| grep  escu.PML | awk -F '=' '{print $2}'| tr 'A-Z' 'a-z')
	
mkdir -p /home/gold/offline-pack/pack/

chmod 777 /home/gold/offline-pack/pack

cd /home/gold/offline-pack/
rm -Rf ./install-deb.list
rm -Rf ./download_failed.list
rm -Rf ./dep_ver_old.list 

ls /home/gold/offline-pack/pack | grep -E ^"libesmu|libescu"| awk -F'_arm64' '{ print $1 }' >> /home/gold/offline-pack/install-deb.list
dpkg -l | grep '^ii'|grep libtirpc|awk -F':' '{ print $1 }' | awk -F' ' '{ print $2 }' >> /home/gold/offline-pack/install-deb.list
dpkg -l | grep '^ii'|grep rpcbind |awk -F':' '{ print $1 }' | awk -F' ' '{ print $2 }' >> /home/gold/offline-pack/install-deb.list
dpkg -l | grep '^ii' | grep -E 'esccu|escmu|esmu' | grep ii | awk -F ' arm64 ' '{ print $1 }' > /tmp/esccu-deb-list.txt



while read txt_line
do
    pack_name=$(echo $txt_line|tr -d '\n')
	#echo "ESCCU相关安装包:${pack_name}"

	#包的名称
	dep_name=$(echo ${pack_name} | awk -F':' '{ print $1 }' | awk -F' ' '{ print $2 }')
	echo "\n>>>需导出包:${dep_name}"
	#版本
	deb_ver=$(echo ${pack_name} | awk -F':' '{ print $2 }' | awk -F' ' '{ print $2 }')	
	#echo "deb_ver:${deb_ver}"
	cd /home/gold/offline-pack/pack

	result=$(echo ${dep_name}|grep -E 'esccu-proj|escmu-proj')
	if [ "$result" != "" ]
	then
		echo "依赖项去除当前项目包:${result}"
		sleep 1
		continue
	fi
	
	#删除重复文件
	dirFiles=$(ls -l  ${dep_name}_*_arm64.deb|awk -F' ' '{print $NF}')
	for file in ${dirFiles}
	do
			if [ "$file" != "${dep_name}_${deb_ver}_arm64.deb" ];
			then
				echo "删除重复文件:$file"
				rm -Rf "$file"
			fi
	done

	if [ -f "${dep_name}_${deb_ver}_arm64.deb" ]
	then
		echo "\e[33m安装包${dep_name}_${deb_ver}_arm64.deb已经存在\e[0m"
	else
		echo "\e[34m准备从仓库下载安装包${dep_name}_${deb_ver}_arm64.deb\e[0m"
		
		apt-get download ${dep_name}=${deb_ver}
		if [ $? -ne 0 ]
		then
			echo  "${dep_name}_${deb_ver}_arm64.deb"  >>  ../download_failed.list
			echo "\e[31m    下载文件失败,${dep_name}_${deb_ver}_arm64.deb   \e[0m"
			#echo -e -n "\x07"
			sleep 1
		fi
	fi
	cd /home/gold/offline-pack/

	#echo ">>>"
	levelCnt=0
	depend_add_file ${dep_name}  ${deb_ver} ${levelCnt}

done  < /tmp/esccu-deb-list.txt

#生成安装脚本
cd /home/gold/offline-pack
gc_install_shell
projconf_install_shell

echo "---------清除临时文件---------"
rm -Rf ./dependlist_*


#查看是否存在降级的版本
if [ -f ./dep_ver_old.list ]
then
	echo "\e[31m版本依赖关系,降级安装可能导致软件不可预料的数据错误\e[0m"
	cat ./dep_ver_old.list
	exit 0
fi

if [ -f ./download_failed.list ]
then
	echo "\e[31m需处理下载失败文件,通常情况下本地dpkg安装,包无法从仓库下载所致\e[0m"
	echo "\e[31m失败文件清单download_failed.list内容:\e[0m"
	echo "\e[31m$(cat ./download_failed.list)\e[0m"
	
	echo "\e[33m以上不存在的安装包可直接复制到/home/gold/offline-pack/pack目录,再次执行本脚本命令\e[0m"
	
else
	echo "准备导出配置文件..."
	cd /home/gold/
	
	mkdir -p /home/gold/bak_proj
	if [ $(ls ${PML}-proj*.deb|wc -l) -gt 0 ]
	then
		echo "备份proj项目配置文件..."
		mv ${PML}-proj*.deb /home/gold/bak_proj
	fi

	#导出项目配置包
	export-proj-pack-dep.sh
	
	# 项目编号
	projSrvId=$(eeprom4esmu t | grep escu.serviceID | awk -F '=' '{print $2}' | tr 'A-Z' 'a-z')
	PML=$(eeprom4esmu t | grep escu.PML | awk -F '=' '{print $2}' | tr 'A-Z' 'a-z')

	proj_deb=$(ls ${PML}-proj*.deb -lr | head -n 1 | awk -F' ' '{print $9}' | grep -v offline)
	if [ -n "$proj_deb" ]; then
		# 删除旧的proj文件
		rm -f /home/gold/offline-pack/pack/*-proj-*.deb
		# 复制当前生成的proj文件
		cp -av "$proj_deb" /home/gold/offline-pack/pack/
		listName=$(echo "$proj_deb" | awk -F'_arm64' '{print $1}')
		echo "$listName" >> /home/gold/offline-pack/install-deb.list
		offline_deb=${listName}
		
		# 项目软件版本
		proj_packver=$(echo "$listName" | awk -F '.' '{print $3}')
	else
		echo "项目参数包缺失,请确认export-proj-pack-offline.sh命令正确运行!"
		exit 1
	fi
	
	bash /usr/local/bin/create-offline-pack.sh
fi

#esccu-proj-sj202303072_1.0.72_offline-pack_20240124213424.tar.gz
#AARCH64-LEMS-G01-BR-V265-R20230608111447-SJ20230205.tar
