#!/bin/bash
		source /etc/profile
		mysqlc=( mysql -h127.0.0.1 -uroot  --connect-expired-password )
		"${mysqlc[@]}" <<-EOSQL 
		ALTER USER 'root'@'localhost' IDENTIFIED WITH sha256_password BY "$1"  PASSWORD EXPIRE INTERVAL 180 DAY;
		ALTER USER 'root'@'localhost' REQUIRE SSL;
		create database if not exists evuser COLLATE 'utf8_general_ci';
		create database if not exists im COLLATE 'utf8_general_ci';
		CREATE USER 'evuser'@'%' IDENTIFIED WITH sha256_password  BY "$2";
		CREATE USER 'im'@'%' IDENTIFIED WITH sha256_password  BY "$3";
		GRANT ALL PRIVILEGES ON evuser.* TO evuser@'%';
		GRANT ALL PRIVILEGES ON im.* TO im@'%';
		ALTER  USER evuser@'%' REQUIRE SSL;
		ALTER USER im@'%' REQUIRE SSL;
		FLUSH PRIVILEGES;
EOSQL
