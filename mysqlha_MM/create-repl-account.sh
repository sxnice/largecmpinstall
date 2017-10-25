#!/bin/bash
source /etc/profile
mysqlc=( mysql -h127.0.0.1 -uroot -p"$1" )
"${mysqlc[@]}" <<-EOSQL
	GRANT REPLICATION SLAVE ON *.* TO "REPL"@"%" IDENTIFIED WITH mysql_native_password BY "$4";
	FLUSH PRIVILEGES;
EOSQL
exit 0
