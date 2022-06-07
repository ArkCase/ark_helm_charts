{{- define "arkcase.activemq.adminUser" -}}
  {{- default "admin" (.Values.configuration).adminUsername -}}
{{- end -}}

{{- define "arkcase.activemq.adminPassword" -}}
  {{- default "admin" (.Values.configuration).adminPassword -}}
{{- end -}}

{{- define "arkcase.activemq.adminGroup" -}}
  {{- default "admins" (.Values.configuration).adminGroup -}}
{{- end -}}

{{- define "arkcase.activemq.adminRole" -}}
  {{- default "admin" (.Values.configuration).adminRole -}}
{{- end -}}

{{- define "arkcase.activemq.guestPassword" -}}
  {{- default "password" (.Values.configuration).guestPassword -}}
{{- end -}}

{{- define "arkcase.activemq.encryptionPassword" -}}
  {{- default "activemq" (.Values.configuration).encryptionPassword -}}
{{- end -}}

{{- define "arkcase.activemq.users" -}}
  {{ include "arkcase.activemq.adminUser" $ }}:{{ include "arkcase.activemq.adminPassword" $ }}
  {{- range (.Values.configuration).users -}}
    {{- $user := (required "Username may not be empty" .name) -}}
    {{- $password := (default $user .password) }}
{{ $user }}:{{ $password }}
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
  {{- range (.Values.configuration).users -}}
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
{{- end -}}

{{- define "arkcase.activemq.roles" -}}
  {{- $users := dict -}}
  {{- $crap := set $users (include "arkcase.activemq.adminUser" $) (join "," (list (include "arkcase.activemq.adminPassword" $) (include "arkcase.activemq.adminRole" $))) -}}
  {{- range (.Values.configuration).users -}}
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
{{- end -}}
