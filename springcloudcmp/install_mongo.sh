#!/bin/bash
#set -x
#set -eo pipefail
shopt -s nullglob
source ./colorecho
MONGDO_DIR="/usr/local/mongodb"
MONGO_IP="10.143.132.185"
MONGO_USER="evuser"
MONGO_PASSWORD="Pbu4@123"

#建立对等互信
ssh-interconnect(){
        echo_green "建立对等互信开始..."
        local ssh_init_path=./ssh-init.sh 
        $ssh_init_path $MONGO_IP
}

#mongodb安装配置
mongo_install(){
        echo_green "安装mongodb开始"
                ssh -n $MONGO_IP mkdir -p "$MONGDO_DIR"
                scp -r ../packages/mongo/* "$MONGO_IP":"$MONGDO_DIR"
                ssh -Tq $MONGO_IP <<EOF
		iptables -P INPUT ACCEPT
		iptables-save > /etc/sysconfig/iptables
		sed -i /31001/d /etc/sysconfig/iptables
		sed -i /"-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"/d /etc/iptables
		iptables-restore < /etc/sysconfig/iptables
                iptables -A INPUT -p tcp --dport 31001 -j ACCEPT
                iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
                echo "创建mongo用户"
                groupadd mongo
                useradd -r -m -g  mongo mongo
                echo "修改文件权限"
                chown -R mongo.mongo $MONGDO_DIR
                chmod 700 $MONGDO_DIR/bin/*
                chmod 600 $MONGDO_DIR/mongo.key
                sed -i /"replSet=dbReplSet"/d $MONGDO_DIR/mongodb.conf
                sed -i /mongo/d ~/.bashrc
                echo export PATH=$MONGDO_DIR/bin:'\$PATH' >> ~/.bashrc
                source ~/.bashrc
                su - mongo
                cd $MONGDO_DIR
                umask 077
                mkdir -p data/logs
                mkdir -p data/db
                echo "start mongodb"
                nohup ./bin/mongod --port=31001 --dbpath=$MONGDO_DIR/data/db --logpath=$MONGDO_DIR/data/logs/mongodb.log  &>/dev/null &
                echo "配置环境变量"
                sed -i /mongo/d ~/.bashrc
                echo export PATH=$MONGDO_DIR/bin:'\$PATH' >> ~/.bashrc
                source ~/.bashrc
                exit
EOF
        sleep 10
        echo "配置monogo"
        declare -a MONGOS=($MONGO_IP $MONGO_USER $MONGO_PASSWORD)
        scp ./init_mongo3.sh "$MONGO_IP":/root/
        ssh -n $MONGO_IP /root/init_mongo3.sh "${MONGOS[@]}"
        echo "设置需验证登录"
        ssh -Tq $MONGO_IP <<EOF
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
        echo_green "安装完成"
}

uninstall_mongodb(){
	echo_green "清除mongodb开始"
	ssh -Tq $MONGO_IP <<EOF
	pkill mongo
	sleep 2
	userdel -f mongo
	rm -rf /home/mongo
	rm -rf $MONGDO_DIR
	iptables -P INPUT ACCEPT
        iptables-save > /etc/sysconfig/iptables
        sed -i /31001/d /etc/sysconfig/iptables
        sed -i /"-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"/d /etc/iptables
        iptables-restore < /etc/sysconfig/iptables
EOF
	echo_green "清除完成"
}

echo "1-----mongodb安装"
echo "2-----mongodb卸载" 

while read item
do
  case $item in
    [1])
	ssh-interconnect
	mongo_install
        break
        ;;
    [2])
	ssh-interconnect
	uninstall_mongodb
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

