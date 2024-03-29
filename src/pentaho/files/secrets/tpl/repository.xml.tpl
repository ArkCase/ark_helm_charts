<?xml version="1.0"?>
<!DOCTYPE Repository
    PUBLIC "-//The Apache Software Foundation//DTD Jackrabbit 2.0//EN"
    "http://org.apache.jackrabbit.core.data.db.DbDataStore">
<Repository>
  {{- include "arkcase.pentaho.jcr.fileSystem" (dict "ctx" . "prefix" "fs_repos_") | nindent 2 }}

  {{- include "arkcase.pentaho.jcr.dataStore" (dict "ctx" . "prefix" "ds_repos_") | nindent 2 }}

  <Security appName="Jackrabbit">
    <SecurityManager class="org.apache.jackrabbit.core.DefaultSecurityManager" workspaceName="security"/>

    <AccessManager class="org.apache.jackrabbit.core.security.DefaultAccessManager"/>

    <LoginModule class="org.pentaho.platform.repository2.unified.jcr.jackrabbit.security.SpringSecurityLoginModule">
      <param name="anonymousId" value="anonymous"/>
      <param name="adminId" value="pentahoRepoAdmin"/>

      <param name="principalProvider"
             value="org.pentaho.platform.repository2.unified.jcr.jackrabbit.security.SpringSecurityPrincipalProvider"/>
      <param name="preAuthenticationTokens" value="ZchBOvP8q9FQ"/>
      <param name="trust_credentials_attribute" value="pre_authentication_token"/>
    </LoginModule>
  </Security>

  <Workspaces rootPath="${rep.home}/workspaces" defaultWorkspace="default"/>
  <Workspace name="${wsp.name}">
    {{- include "arkcase.pentaho.jcr.fileSystem" (dict "ctx" . "prefix" "fs_ws_") | nindent 4 }}

    {{- include "arkcase.pentaho.jcr.persistenceManager" (dict "ctx" . "prefix" "${wsp.name}_pm_ws_") | nindent 4 }}

    <SearchIndex class="org.apache.jackrabbit.core.query.lucene.SearchIndex">
      <param name="path" value="${wsp.home}/index"/>
      <param name="supportHighlighting" value="true"/>
    </SearchIndex>

    <WorkspaceSecurity>
      <AccessControlProvider class="org.apache.jackrabbit.core.security.authorization.acl.PentahoACLProvider"/>
    </WorkspaceSecurity>
  </Workspace>

  <Versioning rootPath="${rep.home}/version">
    {{- include "arkcase.pentaho.jcr.fileSystem" (dict "ctx" . "prefix" "fs_ver_") | nindent 4 }}

    {{- include "arkcase.pentaho.jcr.persistenceManager" (dict "ctx" . "prefix" "pm_ver_") | nindent 4 }}
  </Versioning>

  <!--
    The cluster ID is computed in the following order priority:
      * the "id" attribute in the <Cluster> element
      * the value of the system property org.apache.jackrabbit.core.cluster.node_id
      * the contents of the file ${rep.home}/cluster_node.id
      * a UUID rendered at bootup time
  -->
  <Cluster>
    {{- include "arkcase.pentaho.jcr.journal" (dict "ctx" . "type" ((.Values.configuration).journalType | default "db")) | nindent 4 }}
  </Cluster>
</Repository>
