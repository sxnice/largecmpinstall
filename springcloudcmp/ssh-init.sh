#!/bin/bash
source ./colorecho
pass="Pbu4@123"
wd=.__tmp__sfsfas
mkdir -p $wd

generate_key(){
    if [[ ! -e "$HOME/.ssh/id_rsa.pub"  ]]; then
        ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa > /dev/null && echo_green "$HOSTNAME succeed in generating ssh key." || echo_red "$HOSTNAME fail to generate ssh key."
    fi
}

generate_key

for i in "$@"
do
echo =======$i=======
#ssh-copy-id -i ~/.ssh/id_rsa.pub $i
expect <<-EOF
set timeout -1
spawn  ssh-copy-id -i /root/.ssh/id_rsa.pub $i
expect {
"*yes/no" { send "yes\n"; exp_continue }
"*exist" { send "login ok\n" }
"*password" { send "${passwd}\n" }
}
expect eof
EOF
done



rm -rf $wd
exit 0
