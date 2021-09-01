#!/usr/bin/env bash
CATALINA_OPTS="-Xms2024m -Xmx5024m  -Djava.rmi.server.hostname=localhost -XX:MaxPermSize=256m -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
#export $CATALINA_OPTS
#export CATALINA_OUT=/home/pentaho/log/pentaho/catalina.out
#export CATALINA_TMPDIR=/home/pentaho/tmp/pentaho
export JAVA_OPTS="-Djava.net.preferIPv4Stack=true"
