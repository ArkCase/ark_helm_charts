{{- define "__arkcase.ai.compute" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $global := ($ctx.Values.global | default dict) -}}
  {{- $ai := (get $global "ai" | default dict) -}}
  {{- if (not (kindIs "map" $ai)) -}}
    {{- $ai = dict -}}
  {{- end -}}

  {{- $result := dict -}}
  {{- $features := 0 -}}
  {{- range $k := (list "chatbot" "redaction") -}}
    {{- $v := (not (empty (include "arkcase.toBoolean" (get $ai $k | default "false" )))) -}}
    {{- $result = set $result $k $v -}}
    {{- if $v -}}
      {{- $features = add $features 1 -}}
    {{- end -}}
  {{- end -}}

  {{- $enabled := or (not (hasKey $ai "enabled")) (not (empty (include "arkcase.toBoolean" (get $ai "enabled" | default "false" )))) -}}

  {{- if and $enabled (lt 0 $features) -}}
    {{- $result = set $result "enabled" true -}}
    {{- $llm := get $ai "llm" | default (printf "%s-llm" $ctx.Release.Name) -}}
    {{- $ns := $ctx.Release.Namespace -}}
    {{- if not (lookup "v1" "Secret" $ns $llm) -}}
      {{- fail (printf "Your configuration requires a secret named '%s' in the '%s' namespace, but it doesn't exist" $llm $ns) -}}
    {{- end -}}
    {{- $result = set $result "llm" $llm -}}
  {{- else -}}
    {{- /* If AI is disabled, just return an empty dict */ -}}
    {{- $result = dict -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}

{{- define "arkcase.ai" -}}
  {{- $args :=
    dict
      "ctx" $
      "template" "__arkcase.ai.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
{{- end -}}

{{- define "arkcase.ai.env" -}}
  {{- $ai := (include "arkcase.ai" $ | fromYaml) -}}
  {{- $enabled := (get $ai "enabled" | default false) -}}
- name: ARKCASE_AI_ENABLED
  value: {{ $enabled | toString | quote }}
- name: ARKCASE_AI_CHATBOT_ENABLED
  value: {{ and $enabled $ai.chatbot | toString | quote }}
- name: ARKCASE_AI_REDACTION_ENABLED
  value: {{ and $enabled $ai.redaction | toString | quote }}
  {{- if $enabled }}
- name: ARKCASE_AI_LLM_URL
  valueFrom:
    secretKeyRef:
      name: {{ $ai.llm | quote }}
      key: "url"
      optional: false
- name: ARKCASE_AI_LLM_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $ai.llm | quote }}
      key: "api-key"
      optional: true
- name: ARKCASE_AI_LLM_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ $ai.llm | quote }}
      key: "username"
      optional: true
- name: ARKCASE_AI_LLM_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $ai.llm | quote }}
      key: "password"
      optional: true
  {{- else }}
- name: ARKCASE_AI_LLM_URL
  value: "http://localhost:1"
- name: ARKCASE_AI_LLM_API_KEY
  value: ""
- name: ARKCASE_AI_LLM_USERNAME
  value: ""
- name: ARKCASE_AI_LLM_PASSWORD
  value: ""
  {{- end }}
{{- end -}}
