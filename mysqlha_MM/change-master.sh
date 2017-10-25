#!/bin/bash
source /etc/profile
mysqlc=( mysql -h127.0.0.1 -uroot -p"$1" )
"${mysqlc[@]}" <<-EOSQL
	STOP SLAVE;
	CHANGE MASTER TO MASTER_HOST="$5", MASTER_USER="REPL", MASTER_PASSWORD="$4", MASTER_AUTO_POSITION=1;
    START SLAVE;
EOSQL
exit 0
