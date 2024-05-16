{{- define "arkcase.artemis.adminRole" -}}
  {{- include "arkcase.tools.conf" (dict "ctx" $ "value" "adminRole") -}}
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

{{- define "arkcase.artemis.mountUserAccounts" -}}
{{- end -}}
