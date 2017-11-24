#!/bin/bash
source ./colorecho
hosts="$@"
for i in $hosts
do
echo "配置节点"$i 
ostype=`ssh $i head -n 1 /etc/issue | awk '{print $1}'`

#开放端口外部访问
ssh -Tq $i <<EOF

                iptables -P INPUT ACCEPT
                iptables-save >/etc/iptables
                sed -i /"-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT"/d /etc/iptables
		sed -i /"-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"/d /etc/iptables
                sed -i /mongodb/d /etc/iptables
                iptables-restore </etc/iptables
                iptables --new mongodb
                iptables -A INPUT -p tcp --dport 22 -j ACCEPT
                iptables -A mongodb -p tcp --dport 31001 -j ACCEPT
		iptables -A mongodb -p tcp --dport 31002 -j ACCEPT
                iptables -A mongodb -m state --state ESTABLISHED,RELATED -j ACCEPT
                iptables -A mongodb -p icmp --icmp-type any -j ACCEPT
                iptables -A INPUT -j mongodb
                exit
EOF


if [ "$ostype" == "Ubuntu" ]; then
        ssh -Tq $i <<EOF
		iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
		iptables -P INPUT DROP
                iptables-save > /etc/iptables
                sed -i /iptables/d /etc/rc.local
                sed -i /exit/d /etc/rc.local
                echo "iptables-restore < /etc/iptables" >>/etc/rc.local
                chmod u+x /etc/rc.local
                exit
EOF
else
        ssh -Tq $i <<EOF
		iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
		iptables -P INPUT DROP
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
