{{- define "arkcase.artemis.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.artemis.adminUser" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminUsername") -}}
{{- end -}}

{{- define "arkcase.artemis.adminPassword" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminPassword") -}}
{{- end -}}

{{- define "arkcase.artemis.adminRole" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminRole") -}}
{{- end -}}

{{- define "arkcase.artemis.guestPassword" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "guestPassword") -}}
{{- end -}}

{{- define "arkcase.artemis.encryptionPassword" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "encryptionPassword") -}}
{{- end -}}

{{- define "arkcase.artemis.users" -}}
  {{- $adminUser := (include "arkcase.artemis.adminUser" $) -}}
  {{- $users := dict $adminUser (include "arkcase.artemis.adminPassword" $) -}}
  {{- $declaredUsers := (include "arkcase.tools.conf" (dict "ctx" $ "value" "users" "detailed" true) | fromYaml) -}}
  {{- if $declaredUsers.value -}}
    {{- range $user, $data := $declaredUsers.value -}}
      {{- $password := $user -}}
      {{- if $data -}}
        {{- if and (kindIs "map" $data) (hasKey $data "password") -}}
          {{- $password = ($data.password | toString | default $user) -}}
        {{- else if (kindIs "string" $data) -}}
          {{- $password = ($data | toString | default $user) -}}
        {{- else -}}
          {{- fail (printf "User [%s] has a bad specification - the value must be a map with specific values (password, roles), or a string as the password (is a %s)." $user (kindOf $data)) -}}
        {{- end -}}
        {{- if (ne $user $adminUser) -}}
          {{- $users = set $users $user $password -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
    {{- range $user := (keys $users | compact | sortAlpha) }}
{{ $user }}={{ get $users $user }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.artemis.roles" -}}
  {{- /* First, deal with the administrators */ -}}
  {{- $adminUser := (include "arkcase.artemis.adminUser" $) -}}
  {{- $adminRole := (include "arkcase.artemis.adminRole" $) -}}
  {{- $roles := dict $adminRole (list $adminUser) -}}

  {{- /* Now, deal with the rest of the users */ -}}
  {{- $availableRole := (include "arkcase.tools.conf" (dict "ctx" $ "value" "roles" "detailed" true) | fromYaml) -}}
  {{- if $availableRole.value -}}
    {{- range $role, $data := $availableRole.value -}}
      {{- if $data -}}
        {{- $members := ($data | default list) -}}
        {{- if (kindIs "slice" $data) -}}
          {{- /* Convert everything to a string */ -}}
          {{- $members = (toStrings $data) -}}
        {{- else if (kindIs "string" $data) -}}
          {{- /* Support CSV values, and everything else */ -}}
          {{- $members = ($members | toString | splitList ",") -}}
        {{- else -}}
          {{- fail (printf "Role [%s] is improperly declared - must be a list of strings, or a CSV string (is a %s)" $role (kindOf $data)) -}}
        {{- end -}}
        {{- $members = (without ($members | uniq | sortAlpha | compact) $adminUser) -}}

        {{- /* This should only trigger for the admin role */ -}}
        {{- if hasKey $roles $role -}}
          {{- $existing := get $roles $role -}}
          {{- $members = (concat $existing $members | sortAlpha | uniq | compact) -}}
        {{- end -}}

        {{- $roles = set $roles $role $members -}}
      {{- end -}}
    {{- end -}}

    {{- /* Now, render the roles */ -}}
    {{- range $role := (keys $roles | sortAlpha) }}
{{ $role }}={{ join "," (get $roles $role) }}
    {{- end }}
  {{- end -}}
{{- end -}}

{{- define "arkcase.artemis.nodes" -}}
  {{- $nodes := (include "arkcase.tools.conf" (dict "ctx" $ "value" "nodes")) -}}

  {{- /* If it's not set at all, use the default of 1 node */ -}}
  {{- if not $nodes -}}
    {{- $nodes = "0" -}}
  {{- else if not (regexMatch "^[0-9]+$" $nodes) -}}
    {{- fail (printf "The nodes value [%s] is not valid - it must be a numeric value" $nodes) -}}
  {{- end -}}

  {{- /* Remove leading zeros */ -}}
  {{- $nodes = (regexReplaceAll "^0+" $nodes "") -}}

  {{- /* In case it nuked the whole string :D */ -}}
  {{- $nodes = (empty $nodes) | ternary 0 (atoi $nodes) -}}
  {{- $pad := 0 -}}
  {{- if not (mod $nodes 2) -}}
    {{- /* It's an even number ... add one to support at least the given number of nodes */ -}}
    {{- $pad = 1 -}}
  {{- end -}}
  {{- $nodes = add $nodes $pad -}}

  {{- /* We have a hard limit of 5 nodes */ -}}
  {{- (gt $nodes 5) | ternary 5 $nodes -}}
{{- end -}}

{{- define "arkcase.artemis.onePerNode" -}}
  {{- $onePerNode := (include "arkcase.tools.conf" (dict "ctx" $ "value" "onePerNode")) -}}
  {{- if (include "arkcase.toBoolean" $onePerNode) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.artemis.maxFailed" -}}
  {{- $nodes := (include "arkcase.artemis.nodes" $ | atoi) -}}
  {{- /* We can lose all but one of the nodes */ -}}
  {{- sub $nodes 1 -}}
{{- end -}}

{{- define "arkcase.artemis.clusterPassword" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}

  {{- $fullname := (include "common.fullname" $) -}}
  {{- $secretKey := (printf "%s-clusterPassword" $fullname) -}}
  {{- if not (hasKey $ $secretKey) -}}
    {{- $newSecret := (randAlphaNum 63 | b64enc) -}}
    {{- $crap := set $ $secretKey $newSecret -}}
    {{- $secretKey = $newSecret -}}
  {{- else -}}
    {{- $secretKey = get $ $secretKey -}}
  {{- end -}}
  {{- $secretKey -}}
{{- end -}}

{{- define "arkcase.artemis.zookeeper" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter must be the root context" -}}
  {{- end -}}

  {{- $zk := (include "arkcase.tools.conf" (dict "ctx" $ "value" "zookeeper") | fromYaml) -}}
  {{- if not $zk -}}
    {{- $zk = dict "hostname" "zookeeper" "port" 2181 -}}
  {{- end -}}

  {{- if (kindIs "string" $zk) -}}
    {{- /* Allow the use of host:port notation */ -}}
    {{- if not (regexMatch "^[^:]+:[1-9][0-9]*$" $zk) -}}
      {{- if (include "arkcase.tools.isSingleHostname" $zk) -}}
        {{- $zk = list $zk "2181" -}}
      {{- else -}}
        {{- fail (printf "The zookeeper configuration string [%s] is not valid - must be in host:port form (i.e. 'zookeeper:2181')" $zk) -}}
      {{- end -}}
    {{- else -}}
      {{- $zk = splitList ":" $zk -}}
    {{- end -}}
    {{- $host := (include "arkcase.tools.mustSingleHostname" (first $zk)) -}}
    {{- $port := (last $zk | atoi) -}}
    {{- $zk = dict "hostname" $host "port" $port -}}
  {{- end -}}
  {{- if not (kindIs "map" $zk) -}}
    {{- fail "The zookeeper configuration must be a string (host:port) or a map (with hostname and port bits)" -}}
  {{- end -}}
  {{- if not (hasKey $zk "hostname") -}}
    {{- fail "The zookeeper configuration is missing a hostname" -}}
  {{- end -}}
  {{- if not (hasKey $zk "port") -}}
    {{- $zk = set $zk "port" 2181 -}}
  {{- end -}}
  {{- $zk | toYaml -}}
{{- end -}}
