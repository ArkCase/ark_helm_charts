{{- define "arkcase.activemq.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.activemq.adminUser" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminUsername") -}}
{{- end -}}

{{- define "arkcase.activemq.adminPassword" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminPassword") -}}
{{- end -}}

{{- define "arkcase.activemq.adminGroup" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminGroup") -}}
{{- end -}}

{{- define "arkcase.activemq.adminRole" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminRole") -}}
{{- end -}}

{{- define "arkcase.activemq.guestPassword" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "guestPassword") -}}
{{- end -}}

{{- define "arkcase.activemq.encryptionPassword" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "encryptionPassword") -}}
{{- end -}}

{{- define "arkcase.activemq.users" -}}
  {{- $adminUser := (include "arkcase.activemq.adminUser" $) -}}
  {{- $users := dict $adminUser (include "arkcase.activemq.adminPassword" $) -}}
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
{{ $user }}:{{ get $users $user }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.activemq.groups" -}}
  {{- /* First, deal with the administrators */ -}}
  {{- $adminUser := (include "arkcase.activemq.adminUser" $) -}}
  {{- $adminGroup := (include "arkcase.activemq.adminGroup" $) -}}
  {{- $groups := dict $adminGroup (list $adminUser) -}}

  {{- /* Now, deal with the rest of the users */ -}}
  {{- $availableGroups := (include "arkcase.tools.conf" (dict "ctx" $ "value" "groups" "detailed" true) | fromYaml) -}}
  {{- if $availableGroups.value -}}
    {{- range $group, $data := $availableGroups.value -}}
      {{- if $data -}}
        {{- $members := ($data | default list) -}}
        {{- if (kindIs "slice" $data) -}}
          {{- /* Convert everything to a string */ -}}
          {{- $members = (toStrings $data) -}}
        {{- else if (kindIs "string" $data) -}}
          {{- /* Support CSV values, and everything else */ -}}
          {{- $members = ($members | toString | splitList ",") -}}
        {{- else -}}
          {{- fail (printf "Group [%s] is improperly declared - must be a list of strings, or a CSV string (is a %s)" $group (kindOf $data)) -}}
        {{- end -}}
        {{- $members = (without ($members | uniq | sortAlpha | compact) $adminUser) -}}

        {{- /* This should only trigger for the admin group */ -}}
        {{- if hasKey $groups $group -}}
          {{- $existing := get $groups $group -}}
          {{- $members = (concat $existing $members | sortAlpha | uniq | compact) -}}
        {{- end -}}

        {{- $groups = set $groups $group $members -}}
      {{- end -}}
    {{- end -}}

    {{- /* Now, render the groups */ -}}
    {{- range $group := (keys $groups | sortAlpha) }}
{{ $group }}: {{ join "," (get $groups $group) }}
    {{- end }}
  {{- end -}}
{{- end -}}

{{- define "arkcase.activemq.roles" -}}
  {{- $adminUser := (include "arkcase.activemq.adminUser" $) -}}
  {{- $adminPassword := (include "arkcase.activemq.adminPassword" $) -}}
  {{- $adminRole := (include "arkcase.activemq.adminRole" $) -}}
  {{- $definedRoles := dict $adminUser (list $adminPassword $adminRole) -}}
  {{- $users := (include "arkcase.tools.conf" (dict "ctx" $ "value" "users" "detailed" true) | fromYaml) -}}
  {{- if $users.value -}}
    {{- range $user, $data := $users.value -}}
      {{- $password := $user -}}
      {{- $roles := list -}}
      {{- /* We specifically avoid messing with the administative user's roles */ -}}
      {{- if and $data (ne $user $adminUser) -}}
        {{- if and (kindIs "map" $data) -}}
          {{- if hasKey $data "password" -}}
            {{- $password = ($data.password | toString | default $user) -}}
          {{- end -}}
          {{- if hasKey $data "roles" -}}
            {{- $roles = ($data.roles | default list) -}}
          {{- end -}}
        {{- else if (kindIs "string" $data) -}}
          {{- $password = ($data | toString | default $user) -}}
        {{- else -}}
          {{- fail (printf "User [%s] has a bad specification - the value must be a map with specific values (password, roles), or a string as the password (is a %s)." $user (kindOf $data)) -}}
        {{- end -}}

        {{- /* sanitize the roles */ -}}
        {{- if (kindIs "string" $roles) -}}
          {{- $roles = ($roles | splitList ",") -}}
        {{- end -}}
        {{- $roles = (compact $roles | sortAlpha | uniq) -}}

        {{- /* Generate the final data */ -}}
        {{- $roles = concat (list $password) $roles -}}

        {{- $definedRoles = set $definedRoles $user $roles -}}
      {{- end -}}
    {{- end -}}
    {{- range $user, $roles := $definedRoles }}
{{ $user }}: {{ join "," $roles }}
    {{- end }}
  {{- end }}
{{- end -}}
