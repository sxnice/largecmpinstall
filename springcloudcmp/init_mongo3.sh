#!/bin/bash
source ~/.bashrc
mongo $1:31001 <<-EOSQL
        use collectDataDB;
        db.createUser(
        {
          user: "$2",
          pwd: "$3",
          roles: [ { role: "root", db: "admin" } ]
        }
     );
         db.auth('$2','$3');
EOSQL
