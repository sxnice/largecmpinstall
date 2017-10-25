#!/bin/bash
#set -x
#set -eo pipefail
shopt -s nullglob
source ./colorecho
nodetyper=1
nodeplanr=1
nodenor=1
eurekaipr=localhost
dcnamer="DC1"
eurekaiprepr=localhost
hanoder="main"
JDK_DIR="/usr/java"
MONGDO_DIR="/usr/local/mongodb"
REDIS_DIR="/usr/local/redis"
KEEPALIVED_DIR="/usr/local/keepalived"

#---------------可修改配置参数------------------
#安装目录
CURRENT_DIR="/springcloudcmp"
#用户名，密码
cmpuser="cmpimuser"
cmppass="Pbu4@123"
#REDISIP 主IP，从IP，仲裁IP 空格格开(仅支持配置三个节点IP)
REDIS_H="10.143.132.187 10.143.132.190 10.143.132.196"
#MONGOIP 主IP,从IP，仲裁IP 空格格开(仅支持配置三个节点IP)
MONGO_H="10.143.132.187 10.143.132.190 10.143.132.196"
MONGO_USER="evuser"
MONGO_PASSWORD="Pbu4@123"
#haiplist文件存放HA节点ip组
#IM浮动IP
VIP="10.143.132.168"
#时间同步服务器IP
NTPIP="10.143.132.188"
#-----------------------------------------------
declare -a SSH_HOST=()
declare -a REDIS_HOST=($REDIS_H)
declare -a MONGO_HOST=($MONGO_H)
declare -a nodes=()

#所有节点获取
allnodes_get(){
	cat haiplist > .allnodes
	echo $REDIS_H >> .allnodes
	echo $MONGO_H >> .allnodes
	ip_regex="[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}"
	cat .allnodes | egrep -o "$ip_regex" | sort | uniq > allnodes
	rm -rf .allnodes
}

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

#检测安装软件
install-interpackage(){
	echo_green "环境检测开始..."
	#从文件里读取ip节点组
	allnodes_get
	for line in $(cat allnodes)
	do
	SSH_HOST=($line)
	echo "检测节点组"
	for i in "${SSH_HOST[@]}"
            do
		echo "安装依赖包到"$i
		local ostype=`check_ostype $i`
		local os=`echo $ostype | awk -F _ '{print $1}'`
		if [ "$os" == "centos" ]; then
        		local iptables=`ssh -n "$i" rpm -qa |grep iptables |wc -l`
       			 if [ "$iptables" -gt 0 ]; then
                		echo "iptables 已安装"
        		else
                		if [ "${ostype}" == "centos_6" ]; then
                        		 scp  ../packages/centos6_iptables/* "$i":/root/
                         		 ssh -n $i rpm -Uvh ~/iptables-1.4.7-16.el6.x86_64.rpm
               			 elif [ "${ostype}" == "centos_7" ]; then
                        		 scp ../packages/centos7_iptables/* "$i":/root/
                        		 ssh -n $i rpm -Uvh ~/iptables-1.4.21-17.el7.x86_64.rpm ~/libnetfilter_conntrack-1.0.6-1.el7_3.x86_64.rpm ~/libmnl-1.0.3-7.el7.x86_64.rpm ~/libnfnetlink-1.0.1-4.el7.x86_64.rpm ~/iptables-services-1.4.21-17.el7.x86_64.rpm
               			 fi
        		fi
	        	local lsof=`ssh -n "$i" rpm -qa |grep lsof |wc -l`
                	 if [ "$lsof" -gt 0 ]; then
                        	echo "lsof 已安装"
               		 else
                		if [ "${ostype}" == "centos_6" ]; then
                        		 scp  ../packages/centos6_lsof/* "$i":/root/
                         		 ssh -n $i rpm -Uvh ~/lsof-4.82-5.el6.x86_64.rpm
               			 elif [ "${ostype}" == "centos_7" ]; then
                        		 scp ../packages/centos7_lsof/* "$i":/root/
                         		 ssh -n $i rpm -Uvh ~/lsof-4.87-4.el7.x86_64.rpm
               			 fi
               		 fi
			 local psmisc=`ssh -n "$i" rpm -qa |grep psmisc |wc -l`
                         if [ "$psmisc" -gt 0 ]; then
                                echo "psmisc 已安装"
                         else
                                if [ "${ostype}" == "centos_6" ]; then
                                         scp  ../packages/centos6_psmisc/* "$i":/root/
                                         ssh -n $i rpm -Uvh ~/psmisc-22.6-24.el6.x86_64.rpm
                                 elif [ "${ostype}" == "centos_7" ]; then
                                         scp ../packages/centos7_psmisc/* "$i":/root/
                                         ssh -n $i rpm -Uvh ~/psmisc-22.20-11.el7.x86_64.rpm
                                 fi
                         fi
			 local gcc=`ssh -n "$i" rpm -qa |grep gcc |wc -l`
                         if [ "$gcc" -gt 1 ]; then
                                echo "gcc 已安装"
                         else
                                if [ "${ostype}" == "centos_6" ]; then
                                         scp -r  ../packages/centos6_gcc "$i":/root/
					 ssh $i <<EOF
                                             rpm -Uvh --replacepkgs ~/centos6_gcc/*
					     rm -rf ~/centos6_gcc
                                             exit
EOF
                                 elif [ "${ostype}" == "centos_7" ]; then
                                         scp -r ../packages/centos7_gcc "$i":/root/
					 ssh $i <<EOF
                                             rpm -Uvh --replacepkgs ~/centos7_gcc/*
					     rm -rf ~/centos7_gcc
                                             exit
EOF
                                 fi
                         fi
                         local tcl=`ssh -n "$i" rpm -qa |grep tcl |wc -l`
                         if [ "$tcl" -gt 0 ]; then
                                echo "tcl 已安装"
                         else
                                if [ "${ostype}" == "centos_6" ]; then
                                         scp  ../packages/centos6_tcl/* "$i":/root/
                                         ssh -n $i rpm -Uvh --replacepkgs ~/tcl-8.5.7-6.el6.x86_64.rpm
                                 elif [ "${ostype}" == "centos_7" ]; then
                                         scp ../packages/centos7_tcl/* "$i":/root/
                                         ssh -n $i rpm -Uvh --replacepkgs  ~/tcl-8.5.13-8.el7.x86_64.rpm
                                 fi
                         fi
			local ntp=`ssh -n "$i" rpm -qa |grep ntp |wc -l`
                         if [ "$ntp" -gt 0 ]; then
                                echo "ntp 已安装"
                         else
                                if [ "${ostype}" == "centos_6" ]; then
                                         scp  ../packages/centos6_ntp/* "$i":/root/
                                         ssh -n $i rpm -Uvh --replacepkgs ~/ntpdate-4.2.6p5-10.el6.centos.2.x86_64.rpm ~/ntp-4.2.6p5-10.el6.centos.2.x86_64.rpm
                                 elif [ "${ostype}" == "centos_7" ]; then
                                         scp ../packages/centos7_ntp/* "$i":/root/
                                         ssh -n $i rpm -Uvh --replacepkgs  ~/ntp-4.2.6p5-25.el7.centos.2.x86_64.rpm
                                 fi
                         fi
		elif [ "$os" == "ubuntu" ]; then
			if [ "$ostype" == "ubuntu_12" ]; then
				echo_red "$ostype"暂不提供安装
				exit
			elif [ "$ostype" == "ubuntu_14" ]; then
				scp  ../packages/ubuntu14/* "$i":/root/
                                ssh -n $i dpkg -i ~/lsof_4.86+dfsg-1ubuntu2_amd64.deb ~/iptables_1.4.21-1ubuntu1_amd64.deb ~/libnfnetlink0_1.0.1-2_amd64.deb ~/libxtables10_1.4.21-1ubuntu1_amd64.deb ~/psmisc_22.20-1ubuntu2_amd64.deb ntp_4.2.6.p5_dfsg-3ubuntu2.14.04.12_amd64.deb
			elif [ "$ostype" == "ubuntu_16" ]; then
				echo_red "$ostype"暂不提供安装                                
                                exit
			else
				echo_red "$ostype"暂不提供安装
                                exit
			fi
		fi
		done
		
	echo "complete...."
	done
	
	for i in $(cat haiplist)
	do
                echo "安装jdk1.8到节点"$i
                ssh -n "$i" mkdir -p "$JDK_DIR"

                scp -r ../packages/jdk/* "$i":"$JDK_DIR"
                scp ../packages/jce/* "$i":"$JDK_DIR"/jre/lib/security/
                ssh "$i"  <<EOF
                    chmod 755 "$JDK_DIR"/bin/*
                    sed -i /JAVA_HOME/d /etc/profile
                    echo JAVA_HOME="$JDK_DIR" >> /etc/profile
                    echo PATH='\$JAVA_HOME'/bin:'\$PATH' >> /etc/profile
                    echo CLASSPATH='\$JAVA_HOME'/jre/lib/ext:'\$JAVA_HOME'/lib/tools.jar >> /etc/profile
                    echo export JAVA_HOME CLASSPATH PATH>> /etc/profile
                    source /etc/profile
                    su - $cmpuser
                    sed -i /JAVA_HOME/d ~/.bashrc
                    echo JAVA_HOME="$JDK_DIR" >> ~/.bashrc
                    echo PATH='\$JAVA_HOME'/bin:'\$PATH' >> ~/.bashrc
                    echo CLASSPATH='\$JAVA_HOME'/jre/lib/ext:'\$JAVA_HOME'/lib/tools.jar >> ~/.bashrc
                    echo export JAVA_HOME CLASSPATH PATH>> ~/.bashrc
                    exit
                
EOF
                echo "系统配置节点"$i
                ssh "$i" <<EOF
                    sed -i /$cmpuser/d /etc/security/limits.conf
                    echo $cmpuser soft nproc unlimited >>/etc/security/limits.conf
                    echo $cmpuser hard nproc unlimited >>/etc/security/limits.conf
                    sed -i /limits/d /etc/security/limits.conf
                    echo session required pam_limits.so >>/etc/pam.d/login
                    exit
EOF
		
                echo "complete..." 
	done
	
	echo "配置hosts"
	for i in $(cat haiplist)
	do
		local hname=`ssh -n $i hostname`
		echo $i" "$hname >> .hosts
	done
	for i in $(cat haiplist)
	do
		scp .hosts $i:/root
		ssh $i <<EOF
		cat ~/.hosts >>/etc/hosts
		rm -rf ~/.hosts
		exit
EOF
	done
		
	echo "配置时间同步"
	for i in $(cat haiplist)
	do
	scp ./ntp.conf $i:/etc/ntp.conf
	#centos7对于ntpd在/etc/init.d/没有脚本，需单独复制
	local ostype=`check_ostype $i`
	if [ "$ostype" == "centos_7" ]; then
		scp ./ntpd "$i":/etc/init.d/
	fi
	ssh $i <<EOF
		sed -i '/ntpip/{s/ntpip/$NTPIP/}' /etc/ntp.conf
		chmod u+x /etc/init.d/ntpd
		/etc/init.d/ntpd restart
		exit
EOF
	done

	rm -rf .hosts
	rm -rf allnodes

	echo_green "检测安装环境完成..."
}

#安装redis 1主2从3哨兵
install_redis(){
	echo_green "安装redis开始..."
	local k=1
	local mip="${REDIS_HOST[0]}"
	local mport=7000
	local rport=7000
	local sport=7001
	for i in "${REDIS_HOST[@]}"
                do
                echo "安装节点..."$i
		ssh -n "$i" mkdir -p "$REDIS_DIR"
                scp -r ../packages/redis/* "$i":"$REDIS_DIR"
                #编译安装
		ssh $i <<EOF
		cd $REDIS_DIR
		make 
		make install
EOF
		#1主1哨，2从2哨
		if [ "$k" -eq 1 ]; then
                        scp ./redismaster.conf "$i":"$REDIS_DIR"/redismaster.conf
			ssh $i <<EOF
			sed -i 's/redismport/$mport/g' "$REDIS_DIR"/redismaster.conf
			sed -i 's/redismip/$i/g' "$REDIS_DIR"/redismaster.conf
			redis-server "$REDIS_DIR"/redismaster.conf
			sed -i /redismaster/d /etc/rc.d/rc.local
			echo redis-server "$REDIS_DIR"/redismaster.conf >>/etc/rc.d/rc.local
                        chmod u+x /etc/rc.d/rc.local
EOF
                elif [ "$k" -gt 1 ]; then
			scp ./redisslave.conf "$i":"$REDIS_DIR"/redisslave.conf
			ssh $i <<EOF
                        sed -i 's/redisrport/$rport/g' "$REDIS_DIR"/redisslave.conf
			sed -i 's/redismport/$mport/g' "$REDIS_DIR"/redisslave.conf
                        sed -i 's/redisrip/$i/g' "$REDIS_DIR"/redisslave.conf
			sed -i 's/redismip/$mip/g' "$REDIS_DIR"/redisslave.conf
                        redis-server "$REDIS_DIR"/redisslave.conf
			sed -i /redisslave/d /etc/rc.d/rc.local
			echo redis-server "$REDIS_DIR"/redisslave.conf >>/etc/rc.d/rc.local
                	chmod u+x /etc/rc.d/rc.local
EOF
                fi
			scp ./redissentinel.conf "$i":"$REDIS_DIR"/redissentinel.conf
                        ssh $i <<EOF
                        sed -i 's/redismport/$mport/g' "$REDIS_DIR"/redissentinel.conf
			sed -i 's/redissport/$sport/g' "$REDIS_DIR"/redissentinel.conf
                        sed -i 's/redissip/$i/g' "$REDIS_DIR"/redissentinel.conf
			sed -i 's/redismip/$mip/g' "$REDIS_DIR"/redissentinel.conf
                        redis-sentinel "$REDIS_DIR"/redissentinel.conf
			sed -i /redis-sentinel/d /etc/rc.d/rc.local
			echo redis-sentinel "$REDIS_DIR"/redissentinel.conf >>/etc/rc.d/rc.local
                	chmod u+x /etc/rc.d/rc.local
EOF
		echo "complete..."
	let k=k+1
	done
	echo_green "安装redis完成..."
}

#建立对等互信
ssh-interconnect(){
	echo_green "建立对等互信开始..."
	local ssh_init_path=./ssh-init.sh
        #从文件里读取ip节点组
	allnodes_get
        for line in $(cat allnodes)
        do
		$ssh_init_path $line
	done
	rm -rf allnodes
	echo_green "建立对等互信完成..."
}

#创建普通用户cmpimuser
user-internode(){
	echo_green "建立用户开始..."
	local ssh_pass_path=./ssh-pass.sh
        #从文件里读取ip节点组，一行为一个组
        for line in $(cat haiplist)
        do
        	SSH_HOST=($line)
		for i in "${SSH_HOST[@]}"
		do
			echo =======$i=======
			ssh $i <<EOF
			groupadd $cmpuser
 			useradd -m -s  /bin/bash -g $cmpuser $cmpuser
 			usermod -G $cmpuser $cmpuser
			echo "$cmpuser:$cmppass" | chpasswd
EOF
		done
	done
	echo_green "建立用户完成..."
        
}

#复制IM文件到各节点
copy-internode(){
     echo_green "复制IM文件开始..."
     
     case $nodeplanr in
	  [1-4]) #部署
            #从文件里读取ip节点组，一行为一个组
            for line in $(cat haiplist)
            do
		SSH_HOST=($line)
		for i in "${SSH_HOST[@]}"
		do
			echo "复制文件到"$i 
			#放根目录下
			ssh -n $i mkdir -p $CURRENT_DIR
			scp -r ./background ./im ./config startIM.sh startIM_BX.sh stopIM.sh im.config imstart_chk.sh "$i":$CURRENT_DIR
			#赋权
			ssh $i <<EOF
			rm -rf /tmp/spring.log
			rm -rf /tmp/modelTypeName.data
			chown -R $cmpuser.$cmpuser $CURRENT_DIR
			chmod 740 "$CURRENT_DIR"
 	        	chmod 740 "$CURRENT_DIR"/*.sh
			chmod 740 "$CURRENT_DIR"/background
			chmod 640 "$CURRENT_DIR"/background/*.jar
			chmod 740 "$CURRENT_DIR"/config
			chmod 740 "$CURRENT_DIR"/im
			chmod 640 "$CURRENT_DIR"/im/*.jar
			chmod 740 "$CURRENT_DIR"/background/*.sh
			chmod 740 "$CURRENT_DIR"/im/*.sh
			chmod 640 "$CURRENT_DIR"/im/*.war
			chmod 600 "$CURRENT_DIR"/im.config
			chmod 600 "$CURRENT_DIR"/config/*.yml
			su $cmpuser
			umask 077
	#		rm -rf "$CURRENT_DIR"/data
			mkdir -p "$CURRENT_DIR"/data
	#		rm -rf "$CURRENT_DIR"/activemq-data
			mkdir -p "$CURRENT_DIR"/activemq-data
			rm -rf "$CURRENT_DIR"/logs
			mkdir  "$CURRENT_DIR"/logs
			rm -rf "$CURRENT_DIR"/temp
			mkdir  "$CURRENT_DIR"/temp
			exit
EOF
		echo "complete..."
		done
	   done
	    ;;
	  0) 
	    echo "nothing to do...."
	    ;;
	 esac
	echo_green "复制IM文件完成..."
}

#配置各节点IM参数
env_internode(){
        
		echo_green "配置IM参数开始..."
		#从文件里读取ip节点组，一行为一个组
		local k=0
		cat haiplist | while read line
            	do
                echo "节点组配置开始"
		local t=1
		SSH_HOST=($line)
		for j in "${SSH_HOST[@]}"
			do
			
			echo "配置节点"$j
			
			if [ "$k" -eq 0 ]; then
				hanoder="main"
			else 
				hanoder="rep"
				
			fi
			lines=`sed -n "$t"p ./im.config`
                        nodes=($lines)
                        nodeplanr=${nodes[0]}
                        nodetyper=${nodes[1]}
                        nodenor=${nodes[2]}
                        dcnamer=${nodes[3]}
			eurekaipr=${nodes[4]}
                        eurekaiprepr=${nodes[5]}
			
			
			echo_yellow "设置nodeplan="$nodeplanr
			echo_yellow "设置nodetype="$nodetyper
			echo_yellow "设置nodeno="$nodenor	
			echo_yellow "设置eurekaip="$eurekaipr
			echo_yellow "设置dcname="$dcnamer
			echo_yellow "设置eurekaiprep="$eurekaiprepr
			echo_yellow "设置hanode="$hanoder

			
			ssh $j <<EOF
            		sed -i /nodeplan/d /etc/environment
			sed -i /nodetype/d /etc/environment
			sed -i /nodeno/d /etc/environment
			sed -i /eurekaip/d /etc/environment
			sed -i /dcname/d /etc/environment
			sed -i /eurekaiprep/d /etc/environment
                        sed -i /hanode/d /etc/environment
			sed -i /CMP_DIR/d /etc/environment
			
			echo "nodeplan=$nodeplanr">>/etc/environment
			echo "nodetype=$nodetyper">>/etc/environment
			echo "nodeno=$nodenor">>/etc/environment 
			echo "eurekaip=$eurekaipr">>/etc/environment
			echo "dcname=$dcnamer">>/etc/environment
			echo "eurekaiprep=$eurekaiprepr">>/etc/environment
                        echo "hanode=$hanoder">>/etc/environment
			echo "CMP_DIR=$CURRENT_DIR">>/etc/environment
			echo "export CMP_DIR" >> /etc/environment
                        echo "export nodeplan nodetype nodeno eurekaip dcname eurekaiprep hanode">>/etc/environment
			source /etc/environment

			su - $cmpuser
			sed -i /nodeplan/d ~/.bashrc
                        sed -i /nodetype/d ~/.bashrc
                        sed -i /nodeno/d ~/.bashrc
                        sed -i /eurekaip/d ~/.bashrc
                        sed -i /dcname/d ~/.bashrc
			sed -i /umask/d ~/.bashrc
			sed -i /eurekaiprep/d ~/.bashrc
                        sed -i /hanode/d ~/.bashrc
			sed -i /CMP_DIR/d ~/.bashrc
			echo "umask 077" >> ~/.bashrc

			echo "CMP_DIR=$CURRENT_DIR" >> ~/.bashrc
			echo "export CMP_DIR" >> ~/.bashrc
			echo "nodeplan=$nodeplanr">>~/.bashrc
                        echo "nodetype=$nodetyper">>~/.bashrc
                        echo "nodeno=$nodenor">>~/.bashrc 
                        echo "eurekaip=$eurekaipr">>~/.bashrc
                        echo "dcname=$dcnamer">>~/.bashrc
			echo "eurekaiprep=$eurekaiprepr">>~/.bashrc
                        echo "hanode=$hanoder">>~/.bashrc
                        echo "export nodeplan nodetype nodeno eurekaip dcname eurekaiprep hanode">>~/.bashrc
                        source ~/.bashrc
			exit
EOF
		echo "complete..." 
		let t=t+1
		done
		echo "节点组配置完成..."
		let k=k+1
	    done
		echo_green "配置IM参数结束..."
	
}

#配置im的iptables
iptable_imnode(){
        echo_green "配置im--iptables开始..."
        local iptable_path=./iptablescmp.sh
	local im_iplists=""
        #从文件里读取ip节点组，一行为一个组
        for line in $(cat ./haiplist)
	do
		im_iplists=${im_iplists}" "${line}
	done
	$iptable_path $im_iplists
	echo_green "配置im--iptables结束..."
}

#配置redis的iptables
iptable_redisnode(){
        echo_green "配置redis--iptables开始..."
        ./iptablesredis.sh $REDIS_H
        echo_green "配置redis--iptables结束..."
}

#配置mongo的iptables
iptable_mongonode(){
        echo_green "配置mongodb--iptables开始..."
        ./iptablesmongo.sh $MONGO_H
        echo_green "配置mongodb--iptables结束..."
}

#keeplived安装配置
keeplived_settings(){
	echo_green "配置keeplived开始..."
	k=100

	for i in $(cat ./haiplist)
        do
	echo "配置节点"$i
	#需在满足条件下才能安装
	local nplan=`ssh -n $i echo \\$nodeplan`
        local ntype=`ssh -n $i echo \\$nodetype`
        local nno=`ssh -n $i echo \\$nodeno`
	if [ "$nplan" = "1" ] || [ "$ntype" = "1" -a "$nplan" = "2" -a "$nno" = "2" ] || [ "$ntype" = "1" -a "$nplan" = "3" -a "$nno" = "2" ] || [ "$ntype" = "1" -a "$nplan" = "4" -a "$nno" = "3" ] || [ "$ntype" = "3" -a "$nplan" = "2" -a "$nno" = "2" ] || [ "$ntype" = "3" -a "$nplan" = "3" -a "$nno" = "2" ] || [ "$ntype" = "3" -a "$nplan" = "4" -a "$nno" = "3" ]; then
	#centos7对于keepalived在/etc/init.d/没有脚本，需单独复制
	local ostype=`check_ostype $i`
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
			scp ./keepalived "$i":/etc/init.d/
			ssh $i <<EOF
			rpm -Uvh --replacepkgs ~/centos7_keepalived/*
			exit
EOF
					
		fi
	fi
	ssh -n $i mkdir -p "$KEEPALIVED_DIR"
	scp ./keepalived.conf "$i":/etc/keepalived/
	scp ./checkZuul.sh "$i":"$KEEPALIVED_DIR"

	ssh $i <<EOF
                setenforce 0
                sed -i '/enforcing/{s/enforcing/disabled/}' /etc/selinux/config
		chmod 740 /usr/local/keepalived/checkZuul.sh
		chmod 740 /etc/init.d/keepalived
		sed -i '/prioweight/{s/prioweight/$k/}' /etc/keepalived/keepalived.conf
		sed -i '/vip/{s/vip/$VIP/}' /etc/keepalived/keepalived.conf
		sed -i '/rip/{s/rip/$i/}' /etc/keepalived/keepalived.conf
		/etc/init.d/keepalived restart
		exit
EOF
	let k=k-10
	echo "complete..."
	fi
	done
	echo_green "配置keeplived配置完成..."
}

#启动cmp
start_internode(){
	echo_green "启动IM开始..."
	#启动主控节点1或集中式启动串行启动！
	local k=0
	#从文件里读取ip节点组，一行为一个组
	cat haiplist | while read line
        do
                SSH_HOST=($line)
                echo "启动节点组"
		for i in "${SSH_HOST[@]}"
		do
			echo "启动节点"$i
			ssh -n $i 'su - '$cmpuser' -c '$CURRENT_DIR'/startIM.sh'
	#		ssh $i <<EOF
	#		su - $cmpuser
	#		source /etc/environment
	#		umask 077
	#		cd "$CURRENT_DIR"
	#		./startIM.sh
	#		exit
#EOF
			echo "节点"$i"启动完成"
			break
		done
		
		#启动其他节点!
		for i in "${SSH_HOST[@]}"
		do
		if [ "$k" -eq 0 ];then
			let k=k+1
			continue
		fi
		echo "启动节点"$i
	#	 ssh $i <<EOF
	#	 su - $cmpuser
	#	 source /etc/environment
	#	 umask 077
	#	 cd "$CURRENT_DIR"
	#	 ./startIM_BX.sh
	#	 exit
#EOF
		ssh -nf $i 'su - '$cmpuser' -c '$CURRENT_DIR'/startIM_BX.sh > /dev/null'
		let k=k+1
		echo "发启启动指令成功"
		done
		
		#检测其他节点服务是否成功!
		k=0
		for i in "${SSH_HOST[@]}"
		do
		if [ "$k" -eq 0 ];then
			let k=k+1
			continue
		fi
		echo "检测节点"$i
		 ssh $i <<EOF
		 su - $cmpuser
		 source /etc/environment
		 umask 077
		 cd "$CURRENT_DIR"
		 ./imstart_chk.sh
		 exit
EOF
		let k=k+1
		echo "节点检测成功"
		done
	done
	echo_green "启动IM完成..."
}

#关闭cmp
stop_internode(){
	echo_green "关闭IM开始..."
	for i in $(cat haiplist)
	do
		echo "关闭节点"$i
		#local user=`ssh -n $i cat /etc/passwd | sed -n /$cmpuser/p |wc -l`
		local user=`ssh -n $i cat /etc/passwd | awk -F : '{print \$1}' | grep -w $cmpuser |wc -l`
		if [ "$user" -eq 1 ]; then
			local jars=`ssh -n $i ps -u $cmpuser | grep -v PID | wc -l`
			if [ "$jars" -gt 0 ]; then
				ssh $i <<EOF
				killall -9 -u $cmpuser
				exit
EOF
				echo "complete"
			else
				echo "CMP已关闭"
			fi
		else
			echo_yellow "尚未创建$cmpuser用户,请手动关闭服务!"
		#	exit
		fi
	done
	echo_green "所有节点IM关闭完成..."
}

#清空安装
uninstall_internode(){
	echo_green "清空安装开始..."
	for i in $(cat haiplist)
	do
		echo "删除节点"$i
		ssh $i <<EOF
		rm -rf "$CURRENT_DIR"
		rm -rf /home/$cmpuser/
		rm -rf /usr/java/
		rm -rf /tmp/*
		userdel $cmpuser
		iptables -P INPUT ACCEPT
		iptables -D INPUT -j cmp
		iptables -F cmp
		iptables -X cmp
		iptables-save > /etc/iptables
		iptables-save > /etc/sysconfig/iptables
		exit
EOF
		echo "complete..."
	done
	echo_green "清空安装完成..."
}


#mongodb安装配置
mongo_install(){
	echo_green "安装mongodb开始"
	local k=1
	for i in "${MONGO_HOST[@]}"
        do
                echo "安装节点..."$i
		ssh -n "$i" mkdir -p "$MONGDO_DIR"
		scp -r ../packages/mongo/* "$i":"$MONGDO_DIR"
		ssh  $i <<EOF
		echo "创建mongo用户"
		groupadd mongo
		useradd -r -m -g  mongo mongo
		echo "修改文件权限"
		chown -R mongo.mongo $MONGDO_DIR
		chmod 700 $MONGDO_DIR/bin/*
		chmod 600 $MONGDO_DIR/mongo.key
		sed -i /mongo/d ~/.bashrc
                echo export PATH=$MONGDO_DIR/bin:'\$PATH' >> ~/.bashrc
                source ~/.bashrc
		su - mongo
		cd $MONGDO_DIR
		umask 077
		mkdir -p data/logs
		mkdir -p data/db
		echo "start mongodb"
		nohup ./bin/mongod --port=31001 --dbpath=$MONGDO_DIR/data/db --logpath=$MONGDO_DIR/data/logs/mongodb.log --replSet dbReplSet  &>/dev/null &
		echo "配置环境变量"
		sed -i /mongo/d ~/.bashrc
		echo export PATH=$MONGDO_DIR/bin:'\$PATH' >> ~/.bashrc
		source ~/.bashrc
		exit
EOF
	echo "complete..."
	done
	sleep 20
	echo "配置monogo"
	for i in "${MONGO_HOST[@]}"
	do
		if [ "$k" -eq 1 ]; then
		scp ./init_mongo.sh "$i":/root/
		#设置mongdodb密码	
		declare -a MONGOS=($MONGO_H $MONGO_USER $MONGO_PASSWORD) 
		ssh -n $i /root/init_mongo.sh "${MONGOS[@]}"
	fi
	let k=k+1
	echo "设置需验证登录"
	ssh $i <<EOF
		echo "配置开机启动"
		sed -i /mongo/d /etc/rc.d/rc.local
        	echo "su - mongo -c '$MONGDO_DIR/bin/mongod --config $MONGDO_DIR/mongodb.conf'" >> /etc/rc.d/rc.local
        	chmod u+x /etc/rc.d/rc.local
		
		pkill mongod
		sleep 10
		su - mongo
		cd $MONGDO_DIR
		echo "restart mongodb"
		nohup ./bin/mongod --config mongodb.conf  &>/dev/null &
EOF
	echo "complete..."
	done
	echo_green "安装完成"
}


echo_yellow "-----------一键安装说明-------------------"
echo_yellow "1、可安装mysql5.7;"
echo_yellow "2、可安装mongodb3;"
echo_yellow "3、可安装redisHA;"
echo_yellow "4、可安装keepalived;"
echo_yellow "5、可安装IM;"
echo_yellow "6、可清空部署环境。"

echo_yellow "-------------------------------------------"
echo_green "HA版方案，请输入编号："
sleep 3
clear
echo "1-----3台服务器,每台16G内存.2台控制节点，1台采集节点(无mongodb安装)"
echo "2-----3台服务器,每台16G内存.2台控制节点，1台采集节点(有mongodb安装)" 
echo "3-----清空部署(mysql,redis,mongo不受影响，但升级环境禁止使用)"

while read item
do
  case $item in
    [1])
        nodeplanr=2
		ssh-interconnect
		user-internode
		install-interpackage
		install_redis
	#	mongo_install
		copy-internode
		env_internode
		iptable_imnode
		iptable_redisnode
		start_internode
		keeplived_settings
        break
        ;;
    [2])
        nodeplanr=2
		ssh-interconnect
		user-internode
		install-interpackage
		install_redis
		mongo_install
		copy-internode
		env_internode
		iptable_imnode
                iptable_redisnode
		iptable_mongonode
		start_internode
		keeplived_settings
        break
        ;;
     [5])
		ssh-interconnect
		stop_internode
		uninstall_internode
	break;
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
