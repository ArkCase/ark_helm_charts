{{- define "arkcase.activemq.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.activemq.adminUser" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminUsername") | default "admin" -}}
{{- end -}}

{{- define "arkcase.activemq.adminPassword" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminPassword") | default "admin" -}}
{{- end -}}

{{- define "arkcase.activemq.adminGroup" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminGroup") | default "admins" -}}
{{- end -}}

{{- define "arkcase.activemq.adminRole" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminRole") | default "admin" -}}
{{- end -}}

{{- define "arkcase.activemq.guestPassword" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "guestPassword") | default "password" -}}
{{- end -}}

{{- define "arkcase.activemq.encryptionPassword" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "encryptionPassword") | default "activemq" -}}
{{- end -}}

{{- define "arkcase.activemq.users" -}}
  {{ include "arkcase.activemq.adminUser" $ }}:{{ include "arkcase.activemq.adminPassword" $ }}
  {{- $users := (include "arkcase.tools.conf" (dict "ctx" $ "value" "users" "detailed" true) | fromYaml) -}}
  {{- if $users.value -}}
    {{- range $users.value -}}
      {{- $user := (required "Username may not be empty" .name) -}}
      {{- $password := (.password | default $user) }}
{{ $user }}:{{ $password }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.activemq.groups" -}}
  {{- $groups := dict -}}
  {{- $members := list -}}
  {{- /* First, deal with the administrators */ -}}
  {{- $adminUser := (include "arkcase.activemq.adminUser" $) -}}
  {{- $adminGroup := (include "arkcase.activemq.adminGroup" $) -}}
  {{- $admins := (default list (get $groups $adminGroup)) -}}
  {{- $admins = (append $admins $adminUser) -}}
  {{- $crap := set $groups $adminGroup (sortAlpha $admins | uniq | compact) -}}
  {{- /* Now, deal with the rest of the users */ -}}
  {{- $users := (include "arkcase.tools.conf" (dict "ctx" $ "value" "users" "detailed" true) | fromYaml) -}}
  {{- if $users.value -}}
    {{- range $users.value -}}
      {{- $userName := (required "Username may not be empty" .name) -}}
      {{- if not (eq $adminUser $userName) -}}
        {{- range (sortAlpha (default list .groups) | uniq | compact) -}}
          {{- $members = (default list (get $groups .)) -}}
          {{- $members = (append $members $userName) -}}
          {{- $crap = set $groups . (sortAlpha $members | uniq | compact) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
    {{- range $group, $members := $groups }}
{{ $group }}: {{ join "," $members }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.activemq.roles" -}}
  {{- $users := dict -}}
  {{- $crap := set $users (include "arkcase.activemq.adminUser" $) (join "," (list (include "arkcase.activemq.adminPassword" $) (include "arkcase.activemq.adminRole" $))) -}}
  {{- $users := (include "arkcase.tools.conf" (dict "ctx" $ "value" "users" "detailed" true) | fromYaml) -}}
  {{- if $users.value -}}
    {{- range $users.value -}}
      {{- $user := (required "Username may not be empty" .name) -}}
      {{- if not (hasKey $users $user) -}}
        {{- $password := (default $user .password) -}}
        {{- $roles := (list $password) -}}
        {{- range (sortAlpha .roles | uniq | compact) -}}
          {{- $roles = (append $roles .) -}}
        {{- end -}}
        {{- $crap = set $users $user $roles -}}
      {{- end -}}
    {{- end -}}
    {{- range $user, $roles := $users }}
{{ $user }}: {{ join "," $roles }}
    {{- end }}
  {{- end }}
{{- end -}}
