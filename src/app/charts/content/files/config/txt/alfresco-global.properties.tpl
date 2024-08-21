#################################################################
# Mount this file as:
# ${ALFRESCO_HOME}/shared/classes/alfresco-global.properties
#################################################################

#################################################################
# Set the administrator info (Must be NTLM/MD4 hashed)
#################################################################
alfresco_user_store.adminusername=${CONTENT_ADMIN_USERNAME}
alfresco_user_store.adminpassword=${CONTENT_ADMIN_PASSWORD_MD4}

#################################################################
# Some DB tune-ups & general settings
#################################################################
alfresco.restApi.basicAuthScheme=true
db.username=${ALFRESCO_JDBC_USERNAME}
db.password=${ALFRESCO_JDBC_PASSWORD}
db.pool.max=50
db.pool.validate.query=SELECT 1
db.schema.update=true
system.preferred.password.encoding=bcrypt10

#################################################################
# Transformation service control
#################################################################
local.transform.service.enabled=false

#################################################################
# Audit support
#################################################################
audit.enabled=true

#################################################################
# For header authentication support
#################################################################
external.authentication.defaultAdministratorUserNames=
external.authentication.enabled=true
external.authentication.proxyHeader=X-Alfresco-Remote-User
external.authentication.proxyUserName=

#################################################################
# For user synchronization
#################################################################
synchronization.autoCreatePeopleOnLogin=false
synchronization.import.cron=0 0/5 * * * ? *
synchronization.synchronizeChangesOnly=false
synchronization.syncOnStartup=true
synchronization.syncWhenMissingPeopleLogIn=true

#################################################################
# LDAP configuration
#################################################################
ldap.authentication.active=true
ldap.authentication.allowGuestLogin=false
ldap.authentication.authenticateFTP=false
ldap.authentication.defaultAdministratorUserNames=${CONTENT_ADMIN_USERNAME}
ldap.authentication.escapeCommasInBind=false
ldap.authentication.escapeCommasInUid=false
# ldap.authentication.userNameFormat=${CONTENT_LDAP_REALM}\\%s
ldap.authentication.userNameFormat=%s@${CONTENT_LDAP_DOMAIN}
ldap.authentication.java.naming.factory.initial=com.sun.jndi.ldap.LdapCtxFactory
ldap.authentication.java.naming.read.timeout=0
ldap.authentication.java.naming.security.authentication=simple
ldap.authentication.java.naming.provider.url=${CONTENT_LDAP_URL}

ldap.synchronization.active=true
ldap.synchronization.attributeBatchSize=0
ldap.synchronization.defaultHomeFolderProvider=largeHomeFolderProvider
ldap.synchronization.enableProgressEstimation=true
ldap.synchronization.groupDisplayNameAttributeName=displayName
ldap.synchronization.groupIdAttributeName=cn
ldap.synchronization.groupMemberAttributeName=member
ldap.synchronization.modifyTimestampAttributeName=whenChanged
ldap.synchronization.queryBatchSize=0
ldap.synchronization.userEmailAttributeName=mail
ldap.synchronization.userFirstNameAttributeName=givenName
ldap.synchronization.userLastNameAttributeName=sn
ldap.synchronization.userOrganizationalIdAttributeName=o
ldap.synchronization.java.naming.security.authentication=simple
ldap.synchronization.java.naming.security.principal=${CONTENT_LDAP_REALM}\\${CONTENT_LDAP_USERNAME}
ldap.synchronization.java.naming.security.credentials=${CONTENT_LDAP_PASSWORD}

#################################################################
# For Active Directory / Samba
#################################################################
authentication.chain=external1:external,ldap1:ldap-ad,alfrescoNtlm1:alfrescoNtlm

ldap.synchronization.groupDifferentialQuery=(&(objectclass\=group)(!(whenChanged<\={0})))
ldap.synchronization.groupQuery=objectClass\=group
ldap.synchronization.groupType=group
ldap.synchronization.personDifferentialQuery=(&(objectClass\=user)(!(whenChanged<\={0})))
ldap.synchronization.personQuery=objectClass\=user
ldap.synchronization.personType=user
ldap.synchronization.timestampFormat=yyyyMMddHHmmss'.0Z'
ldap.synchronization.userIdAttributeName=samAccountName
ldap.synchronization.userSearchBase=${CONTENT_LDAP_USER_BASE_DN},${CONTENT_LDAP_BASE_DN},${CONTENT_LDAP_ROOT_DN}
ldap.synchronization.groupSearchBase=${CONTENT_LDAP_GROUP_BASE_DN},${CONTENT_LDAP_BASE_DN},${CONTENT_LDAP_ROOT_DN}


#################################################################
# Remove unneeded Alfresco activity
#################################################################
activities.feed.notifier.enabled=false
alfresco.cluster.enabled=false
cifs.enabled=false
sync.mode=OFF
sync.pullJob.enabled=false
sync.pushJob.enabled=false
syncService.mode=OFF
system.usages.enabled=false

#################################################################
# Chemistry fixes
#################################################################
opencmis.context.override=true
opencmis.context.value=
# opencmis.server.override=true
# opencmis.server.value=https://external_host/alfresco/api
opencmis.servletpath.override=true
opencmis.servletpath.value=
