#!/bin/bash
source ./colorecho
hosts="$@"
for i in $hosts
do
echo "配置节点"$i 
ostype=`ssh $i head -n 1 /etc/issue | awk '{print $1}'`

#开放端口外部访问
ssh  $i <<EOF

                iptables -P INPUT ACCEPT
                iptables-save >/etc/iptables
                sed -i /"-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT"/d /etc/iptables
                sed -i /redisdb/d /etc/iptables
                iptables-restore </etc/iptables
                iptables --new redisdb
                iptables -A INPUT -p tcp --dport 22 -j ACCEPT
                iptables -A redisdb -p tcp --dport 7000 -j ACCEPT
                iptables -A redisdb -p tcp --dport 7001 -j ACCEPT
                iptables -A redisdb -p tcp --dport 7002 -j ACCEPT
                iptables -A redisdb -m state --state ESTABLISHED,RELATED -j ACCEPT
                iptables -A redisdb -p icmp --icmp-type any -j ACCEPT
                iptables -A INPUT -j redisdb
                iptables -P INPUT DROP
                exit
EOF


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
                sed -i /reject-with/d /etc/sysconfig/iptables
                iptables-restore < /etc/sysconfig/iptables
                echo "iptables-restore < /etc/sysconfig/iptables" >>/etc/rc.d/rc.local
                chmod u+x /etc/rc.d/rc.local
                exit
EOF
fi
echo "complete..."
done

exit 0
