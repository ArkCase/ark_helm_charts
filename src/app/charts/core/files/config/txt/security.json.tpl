{{- define "render-security" -}}
authentication:
  blockUnknown: true
  class: "solr.BasicAuthPlugin"
  credentials:
    {{ $.ARKCASE_USERNAME | quote }}: {{ printf "%s %s" $.ARKCASE_PASSWORD $.ARKCASE_PASSWORD_SALT | quote }}
  realm: {{ printf "Solr Users for %s/%s" $.NAMESPACE $.RELEASE | quote }}
  forwardCredentials: false
authorization:
  class: "solr.RuleBasedAuthorizationPlugin"
  permissions:
    - name: "all"
      role:
        - "admin"
  user-role:
    {{ $.ARKCASE_USERNAME | quote }}:
      - "admin"
{{- end -}}

{{- include "render-security" $ fromYaml -}}
