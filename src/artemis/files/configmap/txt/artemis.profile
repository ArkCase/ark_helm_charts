# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

#
# Define base variables, according to all other containers/charts
#
[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v HOME_DIR ] || HOME_DIR="${BASE_DIR}/artemis"
[ -v CONF_DIR ] || CONF_DIR="${BASE_DIR}/conf"
[ -v DATA_DIR ] || DATA_DIR="${BASE_DIR}/data"
[ -v LOGS_DIR ] || LOGS_DIR="${BASE_DIR}/logs"

#
# Define Artemis variables based on base variables
#
[ -v ARTEMIS_HOME ] || ARTEMIS_HOME="${HOME_DIR}"
[ -v ARTEMIS_INSTANCE ] || ARTEMIS_INSTANCE="${CONF_DIR}"
[ -v ARTEMIS_DATA_DIR ] || ARTEMIS_DATA_DIR="${DATA_DIR}"
[ -v ARTEMIS_LOGS ] || ARTEMIS_LOGS="${LOGS_DIR}"
[ -v ARTEMIS_OOME_DUMP ] || ARTEMIS_OOME_DUMP="${ARTEMIS_LOGS}/oom_dump.hprof"

# Cluster Properties: Used to pass arguments to ActiveMQ Artemis which can be referenced in broker.xml
#ARTEMIS_CLUSTER_PROPS="-Dactivemq.remoting.default.port=61617 -Dactivemq.remoting.amqp.port=5673 -Dactivemq.remoting.stomp.port=61614 -Dactivemq.remoting.hornetq.port=5446"

# Hawtio Properties
# HAWTIO_ROLE define the user role or roles required to be able to login to the console. Multiple roles to allow can
# be separated by a comma. Set to '*' or an empty value to disable role checking when Hawtio authenticates a user.
[ -v HAWTIO_ROLE ] || HAWTIO_ROLE="administrator"

# Java Memory Options
[ -v JAVA_MEM_ARGS ] || JAVA_MEM_ARGS=(-Xms512M -Xmx2G)

# Convert to an array, respecting quotes
[[ "$(declare -p JAVA_MEM_ARGS)" =~ "declare -a" ]] || IFS=$'\n' JAVA_MEM_ARGS=( $(/usr/bin/xargs -n1 <<< "${JAVA_MEM_ARGS}") )

# Java Options
if [ ! -v JAVA_ARGS ] ; then
	JAVA_ARGS=(
		-XX:AutoBoxCacheMax=20000
		-XX:+PrintClassHistogram
		-XX:+UseG1GC
		-XX:+UseStringDeduplication
		-Dhawtio.disableProxy="true"
		-Dhawtio.realm="activemq"
		-Dhawtio.offline="true"
		-Dhawtio.rolePrincipalClasses="org.apache.activemq.artemis.spi.core.security.jaas.RolePrincipal"
		-Dhawtio.http.strictTransportSecurity="max-age=31536000;includeSubDomains;preload"
		-Djolokia.policyLocation="file://${ARTEMIS_INSTANCE}/jolokia-access.xml"
	)
fi

# Convert to an array, respecting quotes
[[ "$(declare -p JAVA_ARGS)" =~ "declare -a" ]] || IFS=$'\n' JAVA_ARGS=( $(/usr/bin/xargs -n1 <<< "${JAVA_ARGS}") )

# Extra JVM args
[ -v JAVA_ARGS_APPEND ] || JAVA_ARGS_APPEND=()

# Convert to an array, respecting quotes
[[ "$(declare -p JAVA_ARGS_APPEND)" =~ "declare -a" ]] || IFS=$'\n' JAVA_ARGS_APPEND=( $(/usr/bin/xargs -n1 <<< "${JAVA_ARGS_APPEND}") )

# Uncomment to enable logging for Safepoint JVM pauses
#
# In addition to the traditional GC logs you could enable some JVM flags to know any meaningful and "hidden" pause
# that could affect the latencies of the services delivered by the broker, including those that are not reported by
# the classic GC logs and dependent by JVM background work (eg method deoptimizations, lock unbiasing, JNI, counted
# loops and obviously GC activity).
#
[ -v ARTEMIS_GC_LOG ] && [ "${ARTEMIS_GC_LOG,,}" == "true" ] && JAVA_ARGS+=( -verbose:gc -Xlog:gc+heap=trace -Xlog:gc* -Xlog:age*=debug -Xlog:safepoint -Xlog:gc:"${ARTEMIS_LOGS}/artemis-gc.log:uptimemillis:filecount=9,filesize=20M" )

# Uncomment to enable the dumping of the Java heap when a java.lang.OutOfMemoryError exception is thrown
[ -v ARTEMIS_GC_DUMP ] && [ "${ARTEMIS_GC_DUMP,,}" == "true" ] && JAVA_ARGS+=( "${JAVA_MEM_ARGS[@]}" "${JAVA_ARGS[@]}" -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath="${ARTEMIS_OOME_DUMP}" )

# Only enable debug options for the 'run' command
if [ ${#} -ge 1 ] && [ "${1}" == "run" ] ; then
    # Uncomment to enable remote debugging
    [ -v ARTEMIS_DEBUG ] && [ "${ARTEMIS_DEBUG,,}" == "true" ] && JAVA_ARGS+=(-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005)

    # Uncomment for async profiler
    [ -v ARTEMIS_PROFILER ] && [ "${ARTEMIS_PROFILER,,}" == "true" ] && JAVA_ARGS+=(-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints)
fi
