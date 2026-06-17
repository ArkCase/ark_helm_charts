# The number of milliseconds of each tick (default: 2000)
tickTime=${ZOOKEEPER_TICK_TIME}

# The number of ticks that the initial
# synchronization phase can take (default: 10)
initLimit=${ZOOKEEPER_INIT_LIMIT}

# The number of ticks that can pass between
# sending a request and getting an acknowledgement (default: 5)
syncLimit=${ZOOKEEPER_SYNC_LIMIT}

# Enable the admin server (??)
admin.enableServer=false

# the directory where the snapshot is stored.
# do not use /tmp for storage, /tmp here is just
# example sakes.
dataDir=${DATA_DIR}

# Disable standalone mode
standaloneEnabled=false

# the port at which the clients will connect
client.portUnification=true
clientPort=2181
secureClientPort=2281
quorumListenOnAllIPs=true
sslQuorum=true

client.secure=true
clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty
serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory

fips-mode=${FIPS}

ssl.authProvider=x509

ssl.clientAuth=need
ssl.hostnameVerification=${ZOOKEEPER_HOSTNAME_VERIFICATION}
ssl.protocol=TLSv1.3
ssl.enabledProtocols=TLSv1.3
ssl.ciphersuites=TLS_AES_256_GCM_SHA384,TLS_AES_128_GCM_SHA256

ssl.keyStore.location=${JAVA_KEYSTORE}
ssl.keyStore.passwordPath=${JAVA_KEYSTORE_PASSWORD_FILE}
ssl.keyStore.type=${JAVA_KEYSTORE_TYPE}

ssl.trustStore.location=${JAVA_TRUSTSTORE}
ssl.trustStore.passwordPath=${JAVA_TRUSTSTORE_PASSWORD_FILE}
ssl.trustStore.type=${JAVA_TRUSTSTORE_TYPE}

ssl.quorum.clientAuth=need
ssl.quorum.hostnameVerification=${ZOOKEEPER_HOSTNAME_VERIFICATION}
ssl.quorum.protocol=TLSv1.3
ssl.quorum.enabledProtocols=TLSv1.3
ssl.quorum.ciphersuites=TLS_AES_256_GCM_SHA384,TLS_AES_128_GCM_SHA256

ssl.quorum.keyStore.location=${JAVA_KEYSTORE}
ssl.quorum.keyStore.passwordPath=${JAVA_KEYSTORE_PASSWORD_FILE}
ssl.quorum.keyStore.type=${JAVA_KEYSTORE_TYPE}

ssl.quorum.trustStore.location=${JAVA_TRUSTSTORE}
ssl.quorum.trustStore.passwordPath=${JAVA_TRUSTSTORE_PASSWORD_FILE}
ssl.quorum.trustStore.type=${JAVA_TRUSTSTORE_TYPE}

# the maximum number of client connections.
# increase this if you need to handle more clients (default: 60)
maxClientCnxns=${ZOOKEEPER_MAX_CLIENTS}

# Whitelist commands for use by SOLR
4lw.commands.whitelist=mntr,conf,ruok

#
# Be sure to read the maintenance section of the
# administrator guide before turning on autopurge.
#
# https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_maintenance
#
# The number of snapshots to retain in dataDir (default: 3)
autopurge.snapRetainCount=${ZOOKEEPER_AUTOPURGE_SNAP_RETAIN_COUNT}
# Purge task interval in hours
# Set to "0" to disable auto purge feature (default: 1)
autopurge.purgeInterval=${ZOOKEEPER_AUTOPURGE_INTERVAL}

## Metrics Providers
#
# https://prometheus.io Metrics Exporter
# metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider
# metricsProvider.httpHost=0.0.0.0
# metricsProvider.httpPort=7000
# metricsProvider.exportJvmInfo=true

cnxTimeout=60

#
# This file is updated whenever nodes join or leave the cluster
#
dynamicConfigFile=${CONF_DIR}/zookeeper-servers.cfg.dynamic
