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

#---------------可修改配置参数------------------
#安装目录
CURRENT_DIR="/springcloudcmp"
#用户名，密码
cmpuser="cmpimuser"
cmppass="Pbu4@123"
#扩容采集节点组，用空格格开
GF_H="10.143.132.189 10.143.132.190"
#主控制节点IP
M_IP="10.143.132.193"
#备控制节点Ip
S_IP="10.143.132.194"
#时间同步服务器IP
NTPIP="10.143.132.188"
#-----------------------------------------------
declare -a GF_HOST=($GF_H)
declare -a SSH_HOST=()

#所有IM节点获取
allnodes_get(){
	cat haiplist > .allnodes
	echo $GF_H >> .allnodes
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
	
	echo "检测新增采集节点"
	for i in "${GF_HOST[@]}"
            do
		echo "安装依赖包到"$i
		local ostype=`check_ostype $i`
		local os=`echo $ostype | awk -F _ '{print $1}'`
		if [ "$os" == "centos" ]; then
        		local iptables=`ssh -n "$i" rpm -qa |grep iptables |wc -l`
       			 if [ "$iptables" -gt 1 ]; then
                		echo "iptables 已安装"
        		else
                		if [ "${ostype}" == "centos_6" ]; then
                        		 scp  ../packages/centos6_iptables/* "$i":/root/
                         		 ssh -n $i rpm -Uvh ~/iptables-1.4.7-16.el6.x86_64.rpm
				elif [ "$ostype" == "centos_7" ]; then
                                        scp -r ../packages/centos7_iptables "$i":/root/
                                        ssh -Tq $i <<EOF
                                        rpm -Uvh --replacepkgs ~/centos7_iptables/*
                                        exit
EOF
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
					 ssh -Tq $i <<EOF
                                             rpm -Uvh --replacepkgs ~/centos6_gcc/*
					     rm -rf ~/centos6_gcc
                                             exit
EOF
                                 elif [ "${ostype}" == "centos_7" ]; then
                                         scp -r ../packages/centos7_gcc "$i":/root/
					 ssh -Tq $i <<EOF
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
                                         scp -r ../packages/centos7_ntp "$i":/root/
                                         ssh -Tq $i <<EOF
                                             rpm -Uvh --replacepkgs ~/centos7_ntp/*
                                             rm -rf ~/centos7_ntp
                                             exit
EOF
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
		
	echo "complete...."
	done
	
	for i in "${GF_HOST[@]}"
	do
                echo "安装jdk1.8到节点"$i
                ssh -n "$i" mkdir -p "$JDK_DIR"

                scp -r ../packages/jdk/* "$i":"$JDK_DIR"
                scp ../packages/jce/* "$i":"$JDK_DIR"/jre/lib/security/
                ssh -Tq "$i"  <<EOF
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
                ssh -Tq "$i" <<EOF
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
	allnodes_get
	for i in $(cat allnodes)
	do
		local hname=`ssh -n $i hostname`
		echo $i" "$hname >> .hosts
	done
	
	for i in $(cat allnodes)
	do
		scp .hosts $i:/root
		ssh -Tq $i <<EOF
		cat ~/.hosts >>/etc/hosts
		rm -rf ~/.hosts
		exit
EOF
	done
		
	echo "配置时间同步"
	for i in "${GF_HOST[@]}"
	do
	scp ./ntp.conf $i:/etc/ntp.conf
	#centos7对于ntpd在/etc/init.d/没有脚本，需单独复制
	local ostype=`check_ostype $i`
	if [ "$ostype" == "centos_7" ]; then
		scp ./ntpd "$i":/etc/init.d/
	fi
	ssh -Tq $i <<EOF
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


#建立对等互信
ssh-interconnect(){
	echo_green "建立对等互信开始..."
	local ssh_init_path=./ssh-init.sh
	allnodes_get
        for line in $(cat allnodes)
        do
		$ssh_init_path $line
		if [ $? -eq 1 ]; then
			exit 1
		fi
	done
	rm -rf allnodes
	echo_green "建立对等互信完成..."
}

#创建普通用户cmpimuser
user-internode(){
	echo_green "建立用户开始..."
	local ssh_pass_path=./ssh-pass.sh
		for i in "${GF_HOST[@]}"
		do
			echo =======$i=======
			ssh -Tq $i <<EOF
			groupadd $cmpuser
 			useradd -m -s  /bin/bash -g $cmpuser $cmpuser
 			usermod -G $cmpuser $cmpuser
			echo "$cmpuser:$cmppass" | chpasswd
EOF
		done
	echo_green "建立用户完成..."
        
}

#复制文件到各节点
copy-internode(){
	echo_green "复制文件到各节点开始..."
	case $nodeplanr in
          [1-4]) #部署
                for i in "${GF_HOST[@]}"
                do
                        echo "复制文件到"$i 
                        #放根目录下
                        ssh -n $i mkdir -p $CURRENT_DIR
                        scp -r ./background ./im ./config startIM.sh startIM_BX.sh stopIM.sh imstart_chk.sh  "$i":$CURRENT_DIR
                        #赋权
                        ssh -Tq $i <<EOF
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
                        chmod 600 "$CURRENT_DIR"/config/*.yml
			chmod 600 "$CURRENT_DIR"/config/license.lic
                        su $cmpuser
                        umask 077
        #               rm -rf "$CURRENT_DIR"/data
                        mkdir  "$CURRENT_DIR"/data
        #               rm -rf "$CURRENT_DIR"/activemq-data
                        mkdir  "$CURRENT_DIR"/activemq-data
                        rm -rf "$CURRENT_DIR"/logs
                        mkdir  "$CURRENT_DIR"/logs
                        rm -rf "$CURRENT_DIR"/temp
                        mkdir  "$CURRENT_DIR"/temp
                        exit
EOF
                echo "complete..."
                done
            ;;
          0)
            echo "nothing to do...."
            ;;
         esac
	echo_green "复制文件到各节点完成..."
}


#配置扩容采集节点环境变量
env_gfnode(){
                echo_green "配置扩容采集节点环境变量开始..."
                for j in "${GF_HOST[@]}"
		do
		echo "配置节点"$j
			
			echo "节点类型，请输入编号："  
			echo "2-----采集节点."    
			echo "3-----控制以及采集节点."    
			read nodetyper 
			


			if [ $nodetyper -eq 2 ] || [ $nodetyper -eq 3 ]; then
			echo "输入采集节点名称，如DC1: "
			read dcnamer
			echo "请输入HA的node名称（主为main,备为rep）："
			read hanoder
			fi
			nodenor=0
			
			echo "设置nodeplan="$nodeplanr
			echo "设置nodetype="$nodetyper
			echo "设置nodeno="$nodenor	
			echo "设置eurekaip="$M_IP
			echo "设置eurekaiprep="$S_IP
			echo "设置dcname="$dcnamer
			echo "设置hanode="$hanoder

			echo "节点："$j
			
			ssh -Tq $j <<EOF
                        sed -i /nodeplan/d /etc/environment
			sed -i /nodetype/d /etc/environment
			sed -i /nodeno/d /etc/environment
			sed -i /eurekaip/d /etc/environment
			sed -i /eurekaiprep/d /etc/environment
			sed -i /dcname/d /etc/environment
			sed -i /hanode/d /etc/environment
			
			echo "nodeplan=$nodeplanr">>/etc/environment
			echo "nodetype=$nodetyper">>/etc/environment
			echo "nodeno=$nodenor">>/etc/environment 
			echo "eurekaip=$M_IP">>/etc/environment
			echo "eurekaiprep=$S_IP">>/etc/environment
			echo "dcname=$dcnamer">>/etc/environment
			echo "hanode=$hanoder">>/etc/environment 			
			echo "export nodeplan nodetype nodeno eurekaip dcname eurekaiprep hanode">>/etc/environment
			source /etc/environment
			su - $cmpuser
			sed -i /nodeplan/d ~/.bashrc
                        sed -i /nodetype/d ~/.bashrc
                        sed -i /nodeno/d ~/.bashrc
                        sed -i /eurekaip/d ~/.bashrc
			sed -i /eurekaiprep/d ~/.bashrc
                        sed -i /dcname/d ~/.bashrc
			sed -i /hanode/d ~/.bashrc
			
			echo "umask 077" >> ~/.bashrc
			echo "CURRENT_DIR=$CURRENT_DIR export CURRENT_DIR" >> ~/.bashrc
			echo "nodeplan=$nodeplanr">>~/.bashrc
                        echo "nodetype=$nodetyper">>~/.bashrc
                        echo "nodeno=$nodenor">>~/.bashrc 
                        echo "eurekaip=$M_IP">>~/.bashrc
			echo "eurekaiprep=$S_IP">>~/.bashrc
                        echo "dcname=$dcnamer">>~/.bashrc 
			echo "hanode=$hanoder">>~/.bashrc
			echo "export nodeplan nodetype nodeno eurekaip dcname eurekaiprep hanode">>~/.bashrc
			source ~/.bashrc
			exit
EOF
		
		echo "complete..." 
		done
		echo_green "配置扩容采集节点环境变量结束..."
}

#配置iptables
iptable_internode(){
        echo_green "配置各节点iptables开始..."
        local iptable_path=./iptablescmp.sh
	allnodes_get
        $iptable_path "$(cat allnodes)"
	echo_green "配置各节点iptables结束..."
}

#启动im
start_internode(){
		echo_green "启动采集开始..."
		for i in "${GF_HOST[@]}"
		do
		echo "启动节点"$i
		ssh -nf $i 'su - '$cmpuser' -c '$CURRENT_DIR'/startIM_BX.sh >/dev/null'
		echo "发启启动指令成功"
		done
		
		for i in "${GF_HOST[@]}"
		do
		echo "启动节点"$i
		 ssh -Tq $i <<EOF
		 su - $cmpuser
		 source /etc/environment
		 umask 077
		 cd "$CURRENT_DIR"
		 ./imstart_chk.sh
		 exit
EOF
		echo "节点启动成功"
		done
		echo_green "启动采集完成..."
}



echo_yellow "-----------一键安装（增量）说明-------------------"
echo_yellow "1、可安装JDK软件;"
echo_yellow "2、可安装有iptables lsof软件;"
echo_yellow "3、初始化时，建议使用root用户安装;"
echo_yellow "4、确保.sh有执行权限，并且使用 ./xxx.sh执行;"
echo_yellow "5、可配置数据库连接,并更新jce;"
echo_yellow "-------------------------------------------"
echo_green "HA方案，请输入编号：" 
sleep 3
clear
echo "1-----3台服务器(每台16G内存.2台控制节点，1台采集节点) + 扩容采集节点N台"  

while read item
do
  case $item in
    [1])
        nodeplanr=2
		ssh-interconnect
		user-internode
		install-interpackage
		copy-internode
		env_gfnode
		iptable_internode
		start_internode
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
