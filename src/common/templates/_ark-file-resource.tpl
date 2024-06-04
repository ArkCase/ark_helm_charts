{{- define "arkcase.file-resource.name" -}}
  {{- printf "%s-files" (include "arkcase.basename" $) -}}
{{- end -}}

{{- define "arkcase.file-resources" -}}
  {{- if and (include "arkcase.subsystem.enabled" $) (not (include "arkcase.subsystem.external" $)) -}}
    {{- $ctx := $ -}}
    {{- $filesResourceName := (include "arkcase.file-resource.name" $) -}}
    {{- $resources :=
      dict
        "ConfigMap" ( dict
            "path" "config"
            "txt" "data"
            "bin" "binaryData"
        )
        "Secret" ( dict
            "path" "secret"
            "txt" "stringData"
            "bin" "data"
        )
    -}}
    {{- range $kind, $cfg := $resources }}
      {{- $basePath := (printf "files/%s" $cfg.path) }}
---
apiVersion: v1
kind: {{ $kind }}
metadata:
  name: {{ $filesResourceName | quote }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels: {{- include "arkcase.labels" $ | nindent 4 }}
      {{- with ($ctx.Values.labels).common }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
  annotations:
      {{- with ($ctx.Values.annotations).common }}
        {{- toYaml . | nindent 4 }}
      {{- end }}
{{ $cfg.txt }}:
      {{- $files := $ctx.Files.Glob (printf "%s/txt/*" $basePath) }}
      {{- if $files }}
  #
  # Include {{ $files | len }} static files
  #
        {{- range $path, $_ := $files }}
  {{ $path | base }}: | {{- $ctx.Files.Get $path | nindent 4 }}
        {{- end }}
      {{- else }}
  #
  # No static files to include
  #
      {{- end }}

      {{- $files = $ctx.Files.Glob (printf "%s/tpl/*" $basePath) }}
      {{- if $files }}
  #
  # Render {{ $files | len }} templated files
  #
        {{- range $path, $_ := $files }}
  {{ $path | base }}: | {{- tpl ($ctx.Files.Get $path) $ | nindent 4 }}
        {{- end }}
      {{- else }}
  #
  # No templated files to render
  #
      {{- end }}

{{ $cfg.bin }}:
    {{- $files = ($ctx.Files.Glob (printf "%s/bin/*" $basePath)) }}
      {{- if $files }}
  #
  # Include {{ $files | len }} binary files
  #
        {{- $files.AsSecrets | nindent 2 }}
      {{- else }}
  #
  # No binary files to include
  #
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "__arkcase.file-resource.volumeName" -}}
  {{- printf "arkcase-%s-file-resource" $ -}}
{{- end -}}

{{- define "__arkcase.file-resource.volume" -}}
  {{- if not (include "arkcase.isRootContext" $.ctx) -}}
    {{- /* cheat a little since we know this should only be called from specific points */ -}}
    {{- fail "Must provide the root context (. or $) as the only parameter" -}}
  {{- end -}}
  {{- $resourceName := (include "arkcase.file-resource.name" $.ctx) -}}
  {{- $type := ($.secret | ternary "secret" "config") -}}
  {{- $typeAnchor := ($.secret | ternary "secret" "configMap") -}}
  {{- $nameAnchor := ($.secret | ternary "secretName" "name") -}}
- name: {{ include "__arkcase.file-resource.volumeName" $type | quote }}
  {{ $typeAnchor }}:
    optional: false
    {{ $nameAnchor }}: {{ $resourceName | quote }}
    defaultMode: 0444
{{- end -}}

{{- define "arkcase.file-resource.config.volume" -}}
  {{- include "__arkcase.file-resource.volume" (dict "ctx" $ "secret" false) -}}
{{- end -}}

{{- define "arkcase.file-resource.secret.volume" -}}
  {{- include "__arkcase.file-resource.volume" (dict "ctx" $ "secret" true) -}}
{{- end -}}

{{- define "__arkcase.file-resource.volumeMount" -}}
  {{- if not (include "arkcase.isRootContext" $.ctx) -}}
    {{- fail "Must provide the root context (. or $) as the 'ctx' parameter" -}}
  {{- end -}}
  {{- $type := ($.secret | ternary "secret" "config") -}}
  {{- $mountPath := ($.mountPath | required "Must provide the mountPath value for the resource file you wish to mount") -}}
  {{- $subPath := (hasKey $ "subPath" | ternary $.subPath ($mountPath | base) | required "The subPath to be mounted must not be an empty string") -}}
- name: {{ include "__arkcase.file-resource.volumeName" $type | quote }}
  mountPath: {{ $mountPath | quote }}
  subPath: {{ $subPath | quote }}
  readOnly: true
{{- end -}}

{{- define "arkcase.file-resource.config.volumeMount" -}}
  {{- $params := (dict "ctx" $.ctx "secret" false) -}}
  {{- include "__arkcase.file-resource.volumeMount" (merge $params (pick $ "mountPath" "subPath")) -}}
{{- end -}}

{{- define "arkcase.file-resource.secret.volumeMount" -}}
  {{- $params := (dict "ctx" $.ctx "secret" true) -}}
  {{- include "__arkcase.file-resource.volumeMount" (merge $params (pick $ "mountPath" "subPath")) -}}
{{- end -}}
