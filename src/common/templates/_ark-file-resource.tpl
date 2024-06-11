{{- define "arkcase.file-resource.name" -}}
  {{- printf "%s-files" (include "arkcase.basename" $) -}}
{{- end -}}

{{- define "__arkcase.file-resource.details" -}}
  {{- $result := dict -}}
  {{- $fullPath := ($ | toString) -}}
  {{- if $fullPath -}}
    {{- $result = set $result "fullPath" $fullPath -}}

    {{- /* Parse out the path the file is at, if any */ -}}
    {{- $path := ($fullPath | dir) -}}
    {{- if $path -}}{{- $result = set $result "path" $path -}}{{- end }}

    {{- /* Parse out the file's name, which must always be there */ -}}
    {{- $name := ($fullPath | base) -}}

    {{- /* Parse out the file's intended deployment mode, if any */ -}}
    {{- $mode := regexReplaceAll "^(.*?)([.]([0-7]{4}))?$" $name "${3}" -}}

    {{- /* Recompute the name in case there was a file mode */ -}}
    {{- $name = regexReplaceAll "^(.*?)([.]([0-7]{4}))?$" $name "${1}" -}}

    {{- /* Store the computed values */ -}}
    {{- $result = set $result "name" $name -}}
    {{- if $mode -}}{{- $result = set $result "mode" $mode -}}{{- end }}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.file-resources.list-files" -}}
  {{- $result := dict }}
  {{- /* if and (include "arkcase.subsystem.enabled" $) (not (include "arkcase.subsystem.external" $)) */ -}}
  {{- if true -}}
    {{- $ctx := $ -}}
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
      {{- $basePath := (printf "files/%s" $cfg.path) -}}
      {{- $allFiles := ($ctx.Files.Glob (printf "%s/**" $basePath)) -}}
      {{- if not $allFiles -}}
        {{- continue -}}
      {{- end -}}

      {{- $files := dict }}

      {{- range $type := (list "bin" "tpl" "txt") -}}
        {{- $files := ($ctx.Files.Glob (printf "%s/%s/*" $basePath $type)) }}
        {{- if not $files }}
          {{- continue -}}
        {{- end -}}

        {{- range $path, $_ := $files }}
          {{- $details := (include "__arkcase.file-resource.details" $path | fromYaml) -}}
          {{- $key := $details.name -}}
          {{- if hasKey $result $key -}}
            {{- continue -}}
          {{- end -}}
          {{- $result = set $result $key $details -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
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
    {{- $rendered := dict }}
    {{- range $kind, $cfg := $resources }}
      {{- $basePath := (printf "files/%s" $cfg.path) }}
      {{- $allFiles := ($ctx.Files.Glob (printf "%s/**" $basePath)) }}
      {{- if not $allFiles }}
        {{- continue }}
      {{- end }}
      {{- $files := dict }}
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

{{ $cfg.bin }}:
      {{- $files = ($ctx.Files.Glob (printf "%s/bin/*" $basePath)) }}
      {{- if $files }}
  #
  # Include {{ $files | len }} binary files
  #
        {{- $files.AsSecrets | nindent 2 }}
        {{- range $path, $_ := $files }}
          {{- $details := (include "__arkcase.file-resource.details" $path | fromYaml) -}}
          {{- $key := $details.name -}}
          {{- if hasKey $rendered $key }}
            {{- continue }}
          {{- end }}
          {{- $rendered = set $rendered $key $path }}
        {{- end }}
      {{- else }}
  #
  # No binary files to include
  #
      {{- end }}

{{ $cfg.txt }}:
      {{- $files = $ctx.Files.Glob (printf "%s/tpl/*" $basePath) }}
      {{- if $files }}
  #
  # Render {{ $files | len }} templated files
  #
        {{- range $path, $_ := $files }}
          {{- $details := (include "__arkcase.file-resource.details" $path | fromYaml) -}}
          {{- $key := $details.name -}}
          {{- if hasKey $rendered $key }}
            {{- continue }}
          {{- end }}
          {{- $rendered = set $rendered $key $path }}
  {{ $key }}: | {{- tpl ($ctx.Files.Get $path) $ | nindent 4 }}
        {{- end }}
      {{- else }}
  #
  # No templated files to render
  #
      {{- end }}

      {{- $files = $ctx.Files.Glob (printf "%s/txt/*" $basePath) }}
      {{- if $files }}
  #
  # Include {{ $files | len }} static files
  #
        {{- range $path, $_ := $files }}
          {{- $details := (include "__arkcase.file-resource.details" $path | fromYaml) -}}
          {{- $key := $details.name -}}
          {{- if hasKey $rendered $key }}
            {{- continue }}
          {{- end }}
          {{- $rendered = set $rendered $key $path }}
  {{ $key }}: | {{- $ctx.Files.Get $path | nindent 4 }}
        {{- end }}
      {{- else }}
  #
  # No static files to include
  #
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "__arkcase.file-resource.volumeName" -}}
  {{- printf "arkcase-%s-file-resource" $ -}}
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

{{- define "__arkcase.file-resource.volume" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- /* cheat a little since we know this should only be called from specific points */ -}}
    {{- fail "Must provide the root context (. or $) as the only parameter" -}}
  {{- end -}}
  {{- $resourceName := (include "arkcase.file-resource.name" $ctx) -}}
  {{- $type := ($.secret | ternary "secret" "config") -}}
  {{- $typeAnchor := ($.secret | ternary "secret" "configMap") -}}
  {{- $nameAnchor := ($.secret | ternary "secretName" "name") -}}
  {{- $fileList := (include "__arkcase.file-resources.list-files" $ctx | fromYaml) -}}
- name: {{ include "__arkcase.file-resource.volumeName" $type | quote }}
  {{ $typeAnchor }}:
    optional: false
    {{ $nameAnchor }}: {{ $resourceName | quote }}
    defaultMode: 0444
    items:
    {{- range $key, $details := $fileList }}
      - key: {{ $key | quote }}
        path: {{ $key | quote }}
      {{- if $details.mode }}
        mode: {{ $details.mode }}
      {{- end }}
    {{- end }}
{{- end -}}

{{- define "arkcase.file-resource.config.volume" -}}
  {{- include "__arkcase.file-resource.volume" (dict "ctx" $ "secret" false) -}}
{{- end -}}

{{- define "arkcase.file-resource.secret.volume" -}}
  {{- include "__arkcase.file-resource.volume" (dict "ctx" $ "secret" true) -}}
{{- end -}}
