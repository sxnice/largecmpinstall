#!/bin/bash
source ~/.bashrc
mongo $1:31001 <<-EOSQL
	mongo $1:31001 <<-EOSQL
	rs.initiate({_id:"dbReplSet",members:[{_id:0,host:"$1:31001",priority:2},{_id:1,host:"$2:31001",priority:1},{_id:2,host:"$3:31001",arbiterOnly: true},{_id:3,host:"$1:31002",arbiterOnly: true},{_id:4,host:"$2:31002",arbiterOnly: true}]});
	rs.status();
EOSQL
echo "正在选举主控节点，请等待60秒"
sleep 60
mongo $1:31001 <<-EOSQL
	use collectDataDB;
	db.createUser(
        {
          user: "$4",
          pwd: "$5",
          roles: [ { role: "root", db: "admin" } ]
        }
     );
	 db.auth('$4','$5');
EOSQL
