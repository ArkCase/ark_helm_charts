#!/bin/bash
SCRIPT="$(readlink -f "${BASH_SOURCE:-${0}}")"
BASEDIR="$(dirname "${SCRIPT}")"

. "${BASEDIR}/set-pentaho-env.sh"

setPentahoEnv "${BASEDIR}/jre"

### =========================================================== ###
## Set a variable for DI_HOME (to be used as a system property)  ##
## The plugin loading system for kettle needs this set to know   ##
## where to load the plugins from                                ##
### =========================================================== ###
DI_HOME="${BASEDIR}/pentaho-solutions/system/kettle"

[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v PENTAHO_HOME ] || PENTAHO_HOME="${BASE_DIR}/pentaho"
[ -v CATALINA_OPTS ] || CATALINA_OPTS=""

###################################################################
# CONFIGURE PERSISTENCE                                           #
###################################################################
[ -v DATA_DIR ] || DATA_DIR="${BASE_DIR}/data"
[ -d "${DATA_DIR}" ] || mkdir -p "${DATA_DIR}"
CATALINA_OPTS+=" -Droot.data.path='${DATA_DIR}'"

#
# ActiveMQ Persistence
#
ACTIVEMQ_DATA="${DATA_DIR}/activemq"
[ -d "${ACTIVEMQ_DATA}" ] || mkdir -p "${ACTIVEMQ_DATA}"
CATALINA_OPTS+=" -Dactivemq.data='${ACTIVEMQ_DATA}'"

#
# Configure Kettle
#
export KETTLE_HOME="${DATA_DIR}/pdi"

#
# Configure license location
#
export PENTAHO_INSTALLED_LICENSE_PATH="${DATA_DIR}/.installedLicenses.xml"

###################################################################
# CONFIGURE LOGGING                                               #
###################################################################
[ -v LOGS_DIR ] || LOGS_DIR="${BASE_DIR}/logs"
[ -d "${LOGS_DIR}" ] || mkdir -p "${LOGS_DIR}"
CATALINA_OPTS+=" -Droot.log.path='${LOGS_DIR}'"

#
# Tomcat Logging
#
[ -v TOMCAT_LOGS_DIR ] || TOMCAT_LOGS_DIR="${LOGS_DIR}/tomcat"
[ -d "${TOMCAT_LOGS_DIR}" ] || mkdir -p "${TOMCAT_LOGS_DIR}"
CATALINA_OPTS+=" -Dcatalina.log.path='${TOMCAT_LOGS_DIR}'"

[ -v CATALINA_OUT ] || CATALINA_OUT="${TOMCAT_LOGS_DIR}/catalina.out"
export CATALINA_OUT

###################################################################
# FINAL TOMCAT CONFIGURATIONS                                     #
###################################################################
CATALINA_OPTS+=" -Xms2048m -Xmx6144m -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Dfile.encoding=utf8 -Djava.locale.providers=COMPAT,SPI -DDI_HOME='${DI_HOME}'"
[ -z "${PENTAHO_INSTALLED_LICENSE_PATH}" ] || CATALINA_OPTS+=" -Dpentaho.installed.licenses.file='${PENTAHO_INSTALLED_LICENSE_PATH}'"
# We're done configuring Tomcat
export CATALINA_OPTS

###################################################################
# FINAL JDK CONFIGURATIONS                                        #
###################################################################
# Add options to Java 9+ to remove illegal reflective access warnings
[ -v JDK_JAVA_OPTIONS ] || JDK_JAVA_OPTIONS=""
JDK_JAVA_OPTIONS+=" --add-opens=java.base/sun.net.www.protocol.jar=ALL-UNNAMED"
JDK_JAVA_OPTIONS+=" --add-opens=java.base/java.lang=ALL-UNNAMED"
JDK_JAVA_OPTIONS+=" --add-opens=java.base/java.net=ALL-UNNAMED"
JDK_JAVA_OPTIONS+=" --add-opens=java.base/java.security=ALL-UNNAMED"
JDK_JAVA_OPTIONS+=" --add-opens=java.base/sun.net.www.protocol.file=ALL-UNNAMED"
JDK_JAVA_OPTIONS+=" --add-opens=java.base/sun.net.www.protocol.ftp=ALL-UNNAMED"
JDK_JAVA_OPTIONS+=" --add-opens=java.base/sun.net.www.protocol.http=ALL-UNNAMED"
JDK_JAVA_OPTIONS+=" --add-opens=java.base/sun.net.www.protocol.https=ALL-UNNAMED"
export JDK_JAVA_OPTIONS

###################################################################
# LAUNCH PENTAHO                                                  #
###################################################################
export JAVA_HOME="${_PENTAHO_JAVA_HOME}"
[ ${#} -gt 1 ] || set -- "run"
[ -v PENTAHO_SERVER ] || PENTAHO_SERVER="${PENTAHO_HOME}/pentaho-server"
[ -v PENTAHO_TOMCAT ] || PENTAHO_TOMCAT="${PENTAHO_SERVER}/tomcat"
exec "${PENTAHO_TOMCAT}/bin/catalina.sh" "${@}"
