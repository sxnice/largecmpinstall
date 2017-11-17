#!/bin/bash
source ./colorecho
wd=.__tmp__sfsfas
mkdir -p $wd

generate_key(){
    if [[ ! -e "$HOME/.ssh/id_rsa.pub"  ]]; then
        ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa > /dev/null && echo_green "$HOSTNAME succeed in generating ssh key." || echo_red "$HOSTNAME fail to generate ssh key."
    fi
}

#ssh-keygen -t rsa <<eof
#
#
#
#
#eof

generate_key

for i in "$@"
do
 echo =======$i=======
# ssh -o StrictHostKeyChecking=no $i 
 ssh-copy-id -i ~/.ssh/id_rsa.pub $i

done

rm -rf $wd
exit 0
