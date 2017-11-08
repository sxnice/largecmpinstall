#!/bin/bash
source ./colorecho
hosts="$@"
for i in $hosts
do
echo "配置控制节点"$i 
ostype=`ssh $i head -n 1 /etc/issue | awk '{print $1}'`
#开放端口外部访问
ssh  $i <<EOF
		iptables -P INPUT ACCEPT
		iptables-save >/etc/iptables
		sed -i /cmp/d /etc/iptables
		sed -i /'--dport 22 -j ACCEPT'/d /etc/iptables
		iptables-restore </etc/iptables
		iptables -A INPUT -p tcp --dport 22 -j ACCEPT
		iptables --new cmp
		iptables -A cmp -m state --state ESTABLISHED,RELATED -j ACCEPT
		iptables -A cmp -p icmp --icmp-type any -j ACCEPT
		iptables -A cmp -p tcp --dport 80 -j ACCEPT
		iptables -A cmp -p tcp --dport 20892 -j ACCEPT
		iptables -A cmp -p tcp --dport 8443 -j ACCEPT
		iptables -A cmp -p tcp --dport 3306 -j ACCEPT
		iptables -A INPUT -j cmp
		iptables -P INPUT DROP
		exit
EOF
#内部通讯端口矩阵
for k in $hosts
do
ssh $i <<EOF
		iptables -A cmp -s 127.0.0.1 -p tcp --dport 8761 -j ACCEPT
		iptables -A cmp -s 127.0.0.1 -p tcp --dport 8888 -j ACCEPT
		iptables -A cmp -s 127.0.0.1 -p tcp --dport 61626 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 8761 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 8888 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20881 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20882 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20883 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20884 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20885 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20886 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20887 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20888 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20889 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20890 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20891 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20893 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20894 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 20895 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 28084 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 28085 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 28086 -j ACCEPT
		iptables -A cmp -s $k -p tcp --dport 61626 -j ACCEPT
		exit

EOF
done
if [ "$ostype" == "Ubuntu" ]; then
        ssh  $i <<EOF
                iptables-save > /etc/iptables
                sed -i /iptables/d /etc/rc.local
                sed -i /exit/d /etc/rc.local
                echo "iptables-restore < /etc/iptables" >>/etc/rc.local
                chmod u+x /etc/rc.local
		exit
EOF
else
        ssh  $i <<EOF
                iptables-save > /etc/sysconfig/iptables
                sed -i /iptables/d /etc/rc.d/rc.local
                echo "iptables-restore < /etc/sysconfig/iptables" >>/etc/rc.d/rc.local
                chmod u+x /etc/rc.d/rc.local
		exit
EOF
fi
echo "complete..."
done

exit 0
