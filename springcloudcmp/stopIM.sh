PRG="$0"
while [ -h "$PRG" ]; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=`dirname "$PRG"`/"$link"
  fi
done
PRGDIR=`dirname "$PRG"`
  
CURRENT_DIR=`cd "$PRGDIR" >/dev/null; pwd`
"$CURRENT_DIR"/background/springbootstoptaskengine.sh
"$CURRENT_DIR"/background/springbootstopvspheremanage.sh
"$CURRENT_DIR"/background/springbootstopalarmcenter.sh
"$CURRENT_DIR"/background/springbootstopcmdb.sh
"$CURRENT_DIR"/background/springbootstopTaskjob.sh
"$CURRENT_DIR"/background/springbootstopmessage.sh
"$CURRENT_DIR"/background/springbootstopi18nserver.sh
"$CURRENT_DIR"/background/springbootstopservicemonitor.sh
"$CURRENT_DIR"/background/springbootstopactivemqserver.sh
"$CURRENT_DIR"/background/springbootstopeurekaserver.sh
"$CURRENT_DIR"/background/springbootstopconfigserver.sh
"$CURRENT_DIR"/background/springbootstopzuulmanager.sh
"$CURRENT_DIR"/background/springbootstopvsphereagent.sh
"$CURRENT_DIR"/background/springbootstopgatherframe.sh
"$CURRENT_DIR"/background/springbootstopeseemanager.sh
"$CURRENT_DIR"/background/springbootstopgmccmanager.sh
"$CURRENT_DIR"/background/springbootstopuniviewmanager.sh

CURRENT_DIR=`cd "$PRGDIR" >/dev/null; pwd`
"$CURRENT_DIR"/im/im-task-stop.sh
"$CURRENT_DIR"/im/im-apigateway-stop.sh
"$CURRENT_DIR"/im/im-provider-stop.sh
"$CURRENT_DIR"/im/im-3rdinf-stop.sh
"$CURRENT_DIR"/im/im-web-stop.sh
