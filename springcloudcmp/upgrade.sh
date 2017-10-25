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
KEEPALIVED_DIR="/usr/local/keepalived"
#---------------可修改配置参数------------------
#安装目录
CURRENT_DIR="/springcloudcmp"
#用户名，密码
cmpuser="cmpimuser"
cmppass="Pbu4@123"
#-----------------------------------------------
declare -a SSH_HOST=()

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
	echo "检测节点组"
	for i in $(cat haiplist)
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
		elif [ "$os" == "ubuntu" ]; then
			if [ "$ostype" == "ubuntu_12" ]; then
				echo_red "$ostype"暂不提供安装
				exit
			elif [ "$ostype" == "ubuntu_14" ]; then
				scp  ../packages/ubuntu14/* "$i":/root/
                                ssh -n $i dpkg -i ~/lsof_4.86+dfsg-1ubuntu2_amd64.deb ~/iptables_1.4.21-1ubuntu1_amd64.deb ~/libnfnetlink0_1.0.1-2_amd64.deb ~/libxtables10_1.4.21-1ubuntu1_amd64.deb ~/psmisc_22.20-1ubuntu2_amd64.deb
			elif [ "$ostype" == "ubuntu_16" ]; then
				echo_red "$ostype"暂不提供安装                                
                                exit
			else
				echo_red "$ostype"暂不提供安装
                                exit
			fi
		fi
		
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
	echo_green "检测安装环境完成..."
}

#建立对等互信
ssh-interconnect(){
	echo_green "建立对等互信开始..."
	local ssh_init_path=./ssh-init.sh
        #从文件里读取ip节点组
        for line in $(cat haiplist)
        do
		$ssh_init_path $line
	done
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

#IM文件到各节点
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

#配置各节点环境变量
env_internode(){
        
		echo_green "配置各节点环境变量开始..."
		for j in "${SSH_HOST[@]}"
			do
			echo "配置节点"$j
			ssh $j <<EOF			
			source /etc/environment
			su - $cmpuser
			
			sed -i /nodeplan/d ~/.bashrc
         		sed -i /nodetype/d ~/.bashrc
           	 	sed -i /nodeno/d ~/.bashrc
            		sed -i /eurekaip/d ~/.bashrc
            		sed -i /dcname/d ~/.bashrc
			sed -i /eurekaiprep/d ~/.bashrc
                        sed -i /hanode/d ~/.bashrc
			sed -i /CMP_DIR/d ~/.bashrc
			
			echo "umask 077" >> ~/.bashrc
			echo "CMP_DIR=$CURRENT_DIR" >> ~/.bashrc
			echo "export CMP_DIR">>~/.bashrc
			sed -n /nodeplan/p /etc/environment>>~/.bashrc 
			echo "export nodeplan">>~/.bashrc
			sed -n /nodetype/p /etc/environment>>~/.bashrc
			echo "export nodetype">>~/.bashrc
			sed -n /nodeno/p /etc/environment>>~/.bashrc
			echo "export nodeno">>~/.bashrc
			sed -n /eurekaip/p /etc/environment>>~/.bashrc
			echo "export eurekaip">>~/.bashrc
			sed -n /dcname/p /etc/environment>>~/.bashrc 
			echo "export dcname">>~/.bashrc
			sed -n /eurekaiprep/p /etc/environment>>~/.bashrc 
			echo "export eurekaiprep">>~/.bashrc
			sed -n /hanode/p /etc/environment>>~/.bashrc 
			echo "export hanode">>~/.bashrc
                        source ~/.bashrc
			exit
EOF
		
		echo "complete..." 
		done
		echo_green "配置各节点环境变量结束..."
	
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
		#	ssh $i <<EOF
		#	su - $cmpuser
		#	source /etc/environment
		#	umask 077
		#	cd "$CURRENT_DIR"
		#	./startIM.sh
		#	exit
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

#start_keepalived
start_keepalived(){
echo_green "启动keepalived开始..."
for i in $(cat haiplist)
        do
	echo "启动节点"$i
	local nplan=`ssh -n $i echo \\$nodeplan`
        local ntype=`ssh -n $i echo \\$nodetype`
        local nno=`ssh -n $i echo \\$nodeno`
	if [ "$nplan" = "1" ] || [ "$ntype" = "1" -a "$nplan" = "2" -a "$nno" = "2" ] || [ "$ntype" = "1" -a "$nplan" = "3" -a "$nno" = "2" ] || [ "$ntype" = "1" -a "$nplan" = "4" -a "$nno" = "3" ] || [ "$ntype" = "3" -a "$nplan" = "2" -a "$nno" = "2" ] || [ "$ntype" = "3" -a "$nplan" = "3" -a "$nno" = "2" ] || [ "$ntype" = "3" -a "$nplan" = "4" -a "$nno" = "3" ]; then
	local keepalived=`ssh -n "$i" rpm -qa |grep keepalived |wc -l`
	if [ "$keepalived" -gt 0 ]; then
		scp ./checkZuul.sh "$i":"$KEEPALIVED_DIR"
		ssh $i <<EOF
                setenforce 0
                sed -i '/enforcing/{s/enforcing/disabled/}' /etc/selinux/config
		chmod 740 /usr/local/keepalived/checkZuul.sh
		/etc/init.d/keepalived restart
		exit
EOF
	fi
	fi
done
echo_green "启动keepalived完成..."
}
echo_yellow "--------一键安装（HA增量）说明-------------"
echo_yellow "1、仅支持从原HA版本升级！"
echo_yellow "2、仅支持相同节点数的升级！"
echo_yellow "3、仅只对IM更新文件进行升级！"
echo_yellow "4、非HA版的升级，请直接重新安装部署！"
echo_yellow "-------------------------------------------"
echo_green "HA方案，请输入编号：" 
sleep 3
clear
echo "1-----3台服务器,每台16G内存.2台控制节点，1台采集节点"  

while read item
do
  case $item in
    [1])
        nodeplanr=2
		ssh-interconnect
		user-internode
		install-interpackage
		copy-internode
		env_internode
		iptable_imnode
		start_internode
		start_keepalived
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
