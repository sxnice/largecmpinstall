#!/bin/bash
#set -x
set -eo pipefail
shopt -s nullglob
source ./colorecho

MYSQL_DIR="/usr/local/mysql"
KEEPALIVED_DIR="/usr/local/keepalived"
#---------------可修改配置参数------------------
#MYSQL的主主，仅支持双主
MYSQL_HA="10.143.132.187 10.143.132.190"
VIP="10.143.132.213"
#MYSQL相关密码
MYSQL_ROOT_PASSWORD="Pbu4@123"
MYSQL_EVUSER_PASSWORD="Pbu4@123"
MYSQL_IM_PASSWORD="Pbu4@123"
MYSQL_REPL_PASSWORD="Pbu4@123"
#-----------------------------------------------
declare -a MSYQLHA_HOST=($MYSQL_HA)

#检测操作系统
check_ostype(){
	local ostype=`ssh -n $1 head -n 1 /etc/issue | awk '{print $1}'`
	if [ "$ostype" == "Ubuntu" ]; then
		local version=`ssh -n $1 head -n 1 /etc/issue | awk  '{print $2}'| awk -F . '{print $1}'`
		echo ubuntu_$version
	else
		local centos=`ssh -n $1 rpm -qa | grep sed | awk -F . '{print $4}'`
		if [ "$centos" == "el6" ]; then
			echo centos_6
		elif [ "$centos" == "el7" ]; then
			echo centos_7
		fi
	fi
}

#安装mysql5.7
ssh-mysqlconnect(){
    echo_green "建立对等互信开始..."
        local ssh_init_path=./ssh-init.sh
        $ssh_init_path $MYSQL_HA
        echo_green "建立对等互信完成..."
        sleep 1
}

mysql_install(){
	echo_green "安装mysql5.7开始"
	local k=1
	for i in "${MSYQLHA_HOST[@]}"
	do
		echo "安装数据库节点"$i
		local ostype=`check_ostype $i`
		local os=`echo $ostype | awk -F _ '{print $1}'`
			if [ "$os" == "centos" ]; then
			local result=`ssh -n $i ps -ef | grep mysql | wc -l`
			if [ "$result" -gt 1 ]; then
				local mysql_v=`ssh -n $i mysql --version | sed -n '/5.7/p' | wc -l`
				if [ "$mysql_v" -eq 1 ]; then
					echo_yellow "mysql 5.7已安装"
					exit
				else
					echo_red "请删除低版本备份好数据后，再执行最新版本的mysql安装"
					exit
				fi
			fi
			echo_yellow "安装依赖包"
			local libaio=`ssh -n "$i" rpm -qa |grep libaio |wc -l`
			if [ "$libaio" -eq 1 ]; then
				echo "libaio 已安装"
			else
				if [ "$ostype" == "centos_6" ]; then
					scp  ../packages/centos6_libaio/* "$i":/root/
					ssh -n $i rpm -Uvh ~/libaio-0.3.107-10.el6.x86_64.rpm
				elif [ "$ostype" == "centos_7" ]; then
						scp ../packages/centos7_libaio/* "$i":/root/
						ssh -n $i rpm -Uvh ~/libaio-0.3.109-13.el7.x86_64.rpm
				fi
			fi
			local numactl=`ssh -n "$i" rpm -qa |grep numactl |wc -l`
			if [ "$numactl" -gt 0 ]; then
						echo "numactl 已安装"
				else
						if [ "$ostype" == "centos_6" ]; then
							scp ../packages/centos6_numactl/* "$i":/root/
							ssh -n $i rpm -Uvh ~/numactl-2.0.9-2.el6.x86_64.rpm
						elif [ "$ostype" == "centos_7" ]; then
							scp ../packages/centos7_numactl/* "$i":/root/
							ssh -n $i rpm -Uvh ~/numactl-2.0.9-6.el7_2.x86_64.rpm ~/numactl-libs-2.0.9-6.el7_2.x86_64.rpm
						fi
				fi
			local openssl=`ssh -n "$i" rpm -qa |grep openssl |wc -l`
			if [ "$openssl" -gt 0 ]; then
				echo "openssl 已安装"
			else
				if [ "$ostype" == "centos_6" ]; then
					scp ../packages/centos6_openssl/* "$i":/root/
					ssh -n $i rpm -Uvh ~/openssl-1.0.1e-57.el6.x86_64.rpm            
				elif [ "$ostype" == "centos_7" ]; then
					scp ../packages/centos7_openssl/* "$i":/root/
					ssh -n $i rpm -Uvh ~/make-3.82-23.el7.x86_64.rpm  ~/openssl-1.0.1e-60.el7_3.1.x86_64.rpm  ~/openssl-libs-1.0.1e-60.el7_3.1.x86_64.rpm
				fi
			fi
			local iptables=`ssh -n "$i" rpm -qa |grep iptables |wc -l`
			if [ "$iptables" -gt 0 ]; then
				echo "iptables 已安装"
			else
				if [ "$ostype" == "centos_6" ]; then
					scp  ../packages/centos6_iptables/* "$i":/root/
					ssh -n $i rpm -Uvh ~/iptables-1.4.7-16.el6.x86_64.rpm
				elif [ "$ostype" == "centos_7" ]; then
					scp ../packages/centos7_iptables/* "$i":/root/
					ssh -n $i rpm -Uvh ~/iptables-1.4.21-17.el7.x86_64.rpm ~/libnetfilter_conntrack-1.0.6-1.el7_3.x86_64.rpm ~/libmnl-1.0.3-7.el7.x86_64.rpm ~/libnfnetlink-1.0.1-4.el7.x86_64.rpm
				fi
			fi
			local keepalived=`ssh -n "$i" rpm -qa |grep keepalived |wc -l`
			if [ "$keepalived" -gt 0 ]; then
				echo "keepalived 已安装"
			else
				if [ "$ostype" == "centos_6" ]; then
					scp -r ../packages/centos6_keepalived "$i":/root/
					ssh $i <<EOF
                                        rpm -Uvh --replacepkgs ~/centos6_keepalived/*
                                        exit
EOF
				elif [ "$ostype" == "centos_7" ]; then
					scp -r ../packages/centos7_keepalived "$i":/root/
					ssh $i <<EOF
					rpm -Uvh --replacepkgs ~/centos7_keepalived/*
					exit
EOF
								
				fi
			fi
		elif [ "$os" == "ubuntu" ]; then
			local result=`ssh -n $i ps -ef | grep mysql | wc -l`
			if [ "$result" -gt 1 ]; then
				local mysql_v=`ssh -n $i mysql --version | sed -n '/5.7/p' | wc -l`
				if [ "$mysql_v" -eq 1 ]; then
					echo_yellow "mysql 5.7已安装"
					exit
				else
					echo_red "请删除低版本备份好数据后，再执行最新版本的mysql安装"
					exit
				fi
			fi
			if [ "$ostype" == "ubuntu_12" ]; then
				echo_red "$ostype"暂不提供安装
				exit
			elif [ "$ostype" == "ubuntu_14" ]; then
				scp  ../packages/ubuntu14/* "$i":/root/
				ssh -n $i dpkg -i ~/libaio1_0.3.109-4_amd64.deb  ~/libnuma1_2.0.9~rc5-1ubuntu3.14.04.2_amd64.deb  ~/openssl_1.0.1f-1ubuntu2.22_amd64.deb ~/iptables_1.4.21-1ubuntu1_amd64.deb ~/libnfnetlink0_1.0.1-2_amd64.deb ~/libxtables10_1.4.21-1ubuntu1_amd64.deb ~/keepalived_1.a1.2.7-1ubuntu1_amd64.deb ~/libsnmp30_5.7.2~dfsg-8.1ubuntu3.2_amd64.deb ~/ipvsadm_1.a1.26-2ubuntu1_amd64.deb ~/libperl5.18_5.18.2-2ubuntu1.1_amd64.deb ~/libsnmp-base_5.7.2~dfsg-8.1ubuntu3.2_all.deb ~/libnl-3-200_3.2.21-1ubuntu4.1_amd64.deb ~/libnl-genl-3-200_3.2.21-1ubuntu4.1_amd64.deb ~/libsensors4_1%3a3.3.4-2ubuntu1_amd64.deb ~/iproute_1.3.12.0-2ubuntu1_all.deb
			elif [ "$ostype" == "ubuntu_16" ]; then
				echo_red "$ostype"暂不提供安装
				exit
			else
				echo_red "$ostype"暂不提供安装
				exit
			fi
		fi
		echo_green "复制文件"
		ssh -n "$i" mkdir -p "$MYSQL_DIR"
		scp ./*.sh "$i":/root/
		scp -r ../packages/mysql/* "$i":"$MYSQL_DIR"
		if [ "$k" -eq 1 ]; then
			ssh -n "$i" cp "$MYSQL_DIR"/support-files/my-master.cnf /etc/my.cnf
		else
			ssh -n "$i" cp "$MYSQL_DIR"/support-files/my-slave.cnf /etc/my.cnf
		fi
		#获取节点内存大小
		local MEMTOTAL=$(ssh $i free -b | sed -n '2p' | awk '{print $2}')
		#配置70%
		local memgbyte=`expr $MEMTOTAL \* 70 / 100 / 1024 / 1024 / 1024`
		ssh $i <<EOF
			echo "关闭selinux防火墙"
			setenforce 0
                	sed -i '/enforcing/{s/enforcing/disabled/}' /etc/selinux/config
			echo "创建mysql用户"
			groupadd mysql
			useradd -r -g mysql -s /bin/false mysql
			echo "修改文件权限"
			chown -R mysql.mysql /usr/local/mysql
			chmod 744 /usr/local/mysql/bin/*
			cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql
			sed -i 's/server_id=1/server_id=$k/g' /etc/my.cnf
			sed -i 's/innodb_buffer_pool_size=1G/innodb_buffer_pool_size=$memgbyte/g' /etc/my.cnf
			chmod 744 /etc/init.d/mysql
			echo "初始化MYSQL"
			cd /usr/local/mysql/bin
			./mysqld --initialize-insecure --user=mysql --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data
			echo "给数据库加密"
			./mysql_ssl_rsa_setup --user=mysql --datadir=/usr/local/mysql/data
			chmod 644 /usr/local/mysql/data/server-key.pem
			echo "第一次启动MYSQL"
			/etc/init.d/mysql start
			echo "配置开机启动"
			chkconfig --add mysqld
			chkconfig --level 2345 mysqld on
			echo "配置环境变量"
			sed -i /mysql/d ~/.bashrc
			echo export PATH=/usr/local/mysql/bin:'\$PATH' >> ~/.bashrc
			source ~/.bashrc
			exit
EOF

	#分别为ROOT密码，EVUSER密码，IM密码，REP密码。
	MYSQL_PASS=("$MYSQL_ROOT_PASSWORD" "$MYSQL_EVUSER_PASSWORD" "$MYSQL_IM_PASSWORD" "$MYSQL_REPL_PASSWORD")
	ssh -n $i /root/init_mysqlha.sh "${MYSQL_PASS[@]}"
	echo "安装完成..."
	let k=k+1
	done 
	echo_green "全部安装完成"
}

#mysql主从配置
mysqlha_settings(){
	echo_green "配置mysql主主开始"
	local k=1
	for i in "${MSYQLHA_HOST[@]}"
	do
		echo "配置数据库节点"$i
		#创建repl帐号
		MYSQL_PASS=("$MYSQL_ROOT_PASSWORD" "$MYSQL_EVUSER_PASSWORD" "$MYSQL_IM_PASSWORD" "$MYSQL_REPL_PASSWORD")
		ssh -n "$i" /root/create-repl-account.sh "${MYSQL_PASS[@]}"
		#双主HA相互建立帐户连接
		if [ "$k" -eq 1 ]; then
			MYSQL_PASS=("$MYSQL_ROOT_PASSWORD" "$MYSQL_EVUSER_PASSWORD" "$MYSQL_IM_PASSWORD" "$MYSQL_REPL_PASSWORD" "${MSYQLHA_HOST[1]}")
			ssh -n "$i" /root/change-master.sh "${MYSQL_PASS[@]}"
		else
			MYSQL_PASS=("$MYSQL_ROOT_PASSWORD" "$MYSQL_EVUSER_PASSWORD" "$MYSQL_IM_PASSWORD" "$MYSQL_REPL_PASSWORD" "${MSYQLHA_HOST[0]}")
			ssh -n "$i" /root/change-master.sh "${MYSQL_PASS[@]}"
		fi
		echo "配置完成..."
		let k=k+1
	done
	
}

#mysql主从数据导入
mysqlha_createdb(){
	echo_green "导入数据到mysql主节点开始"
	
	for i in "${MSYQLHA_HOST[@]}"
	do
		echo "配置主库节点"$i
		MYSQL_PASS=("$MYSQL_ROOT_PASSWORD" "$MYSQL_EVUSER_PASSWORD" "$MYSQL_IM_PASSWORD" "$MYSQL_REPL_PASSWORD")
		#创建repl帐号
		ssh -n "$i" /root/create_db.sh "${MYSQL_PASS[@]}"
		ssh -n "$i" rm -rf /root/*.sh
		break
	done
	echo_green "建库完成..."
	
}

#mysql服务器iptables配置
iptables-mysql(){
  	echo_green "配置iptables开始..."
        local iptable_path=./iptablesmysql.sh
        $iptable_path $MYSQL_HA
	echo_green "配置iptables完成..."
}

#keeplived配置
keeplived_settings(){
	echo_green "配置keeplived配置开始..."
	k=100
	for i in "${MSYQLHA_HOST[@]}"
	do
	echo "配置节点"$i
	#centos7对于keepalived在/etc/init.d/没有脚本，需单独复制
	local ostype=`check_ostype $i`
	if [ "$ostype" == "centos_7" ]; then
		scp ./keepalived "$i":/etc/init.d/
	fi
	scp ./keepalived.conf "$i":/etc/keepalived/
	scp ./checkmysql.sh "$i":/usr/local/mysql/bin

	ssh $i <<EOF
		setenforce 0
                sed -i '/enforcing/{s/enforcing/disabled/}' /etc/selinux/config
		chmod 740 /usr/local/mysql/bin/checkmysql.sh
		chmod 740 /etc/init.d/keepalived
		sed -i '/prioweight/{s/prioweight/$k/}' /etc/keepalived/keepalived.conf
		sed -i '/vip/{s/vip/$VIP/}' /etc/keepalived/keepalived.conf
		sed -i '/rip/{s/rip/$i/}' /etc/keepalived/keepalived.conf
		/etc/init.d/keepalived restart
		exit
EOF
	let k=k-10;
	echo "complete..."
	done
	echo_green "配置keeplived配置完成..."
}

echo "1-----安装数据库主备mysql5.7"
while read item
do
  case $item in
    [1])
		ssh-mysqlconnect
		mysql_install	
		mysqlha_settings
		mysqlha_createdb
		keeplived_settings
		iptables-mysql
        break
        ;;
     0)
        echo "退出"
        exit 0
        ;;
     *)
        echo_red "输入有误，请重新输入！"
        ;;
  esac
done
