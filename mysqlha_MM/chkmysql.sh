#!/bin/bash
#date:2017-10-18
#filename:chkmysql.sh
#author:jerry.hu

#Email:27154076@qq.com
#version:v0.1
source /root/.bashrc

MYSQL_CHKUSER="Mi36a"
MYSQL_CHKPASS="ZaQ1xSw@"
host=''
localhost=''
Slave_IO_Running=''
Slave_SQL_Running=''
#m1,m2,s1,s2
MYSQL_H='10.31.186.70 10.31.186.94 10.31.185.246 10.31.186.29'
declare -a MSYQL_HOST=($MYSQL_H)

#建立对等互信
~/ssh-init.sh $MYSQL_H

for i in "${MSYQL_HOST[@]}"
do
        value=`mysql -h$i -u${MYSQL_CHKUSER} -p${MYSQL_CHKPASS} -e "select version();" >/dev/null 2>&1`
        if [ $? -ne 0 ]; then
                echo $i" ERROR! MySQL is not running! waiting for start..." `date`>>/root/chkmysql
                #如果第一次检测mysql有问题，尝试重启
                ssh $i /etc/init.d/mysql restart
                sleep 10
        else
                echo $i" MySQL is running! check first" `date`>>/root/chkmysql
                sleep 2

        fi

        value=`mysql -h$i -u${MYSQL_CHKUSER} -p${MYSQL_CHKPASS} -e "select version();" >/dev/null 2>&1`
        if [ $? -ne 0 ]; then
                 echo $i"ERROR! MySQL is not running! please check it! " `date`>>/root/chkmysql
                 if [ "$i" == "10.31.196.94" ]; then
                        host='master1'
                 fi
                
        else
                echo $i" MySQL is running! check second" `date`>>/root/chkmysql

                mysql -h$i -u${MYSQL_CHKUSER} -p${MYSQL_CHKPASS} -e "show slave status\\G" >/root/mysql_status
                array=($(egrep 'Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master' /root/mysql_status))
                if [[ "${array[1]}" == 'Yes' && "${array[3]}" == 'Yes' ]]; then
                        if [ "${array[5]}" -eq 0 ];  then
                                echo "MySQL slave running OK!">>/root/chkmysql
                        else
                                echo "MySQL slave is behind master ${array[5]} seconds">>/root/chkmysql
                        fi
                elif [[ "${array[1]}" == 'Yes' && "${array[3]}" != 'Yes' ]]; then
                        echo "MySQL slave sql_thread sync make error! try to start slave...">>/root/chkmysql
                        #跳过数据不存在，主键冲突错误
                        mysql -h$i -u$MYSQL_CHKUSER -p$MYSQL_CHKPASS -e "set global slave_exec_mode='IDEMOTENT';"
                        mysql -h$i -u$MYSQL_CHKUSER -p$MYSQL_CHKPASS -e "stop slave;"
                        mysql -h$i -u$MYSQL_CHKUSER -p$MYSQL_CHKPASS -e "start slave;"
                        echo "MySQL-SQL-THREAD Slave Error on $i", please check it!>>slave_status
                        perl /root/event_send_job.pl 'slave_status' '发送检测邮件'
                else

                        echo "MySQL slave sync make error! try to start slave...">>/root/chkmysql
                        mysql -h$i -u$MYSQL_CHKUSER -p$MYSQL_CHKPASS -e "start slave;"
                        echo "MySQL-Slave Error on $i", please check it!>>slave_status
                        perl /root/event_send_job.pl 'slave_status' '发送检测邮件'

                fi


        fi
echo "-----------------------">>/root/chkmysql

done

localhost=`hostname`
if [ "$localhost" == "slave1" ]; then
        if [ "$host" == "master1" ]; then
                 mysqlc=( mysql -h127.0.0.1 -u$MYSQL_CHKUSER -p$MYSQL_CHKPASS )
                        "${mysqlc[@]}" <<-EOSQL 
                        stop slave;
                        CHANGE MASTER TO MASTER_HOST="master2", MASTER_USER="REPL", MASTER_PASSWORD="Pbu4@123", MASTER_AUTO_POSITION=0;
                        START SLAVE;
                
EOSQL
        fi
fi

cat /dev/null > /root/slave_status
