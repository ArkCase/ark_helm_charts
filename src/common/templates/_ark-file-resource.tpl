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

{{- define "__arkcase.file-resources.list-files.compute" -}}
  {{- $result := dict }}
  {{- if and (include "arkcase.subsystem.enabled" $) (not (include "arkcase.subsystem.external" $)) -}}
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
    {{- $index := dict }}
    {{- /* We do this manually b/c we want files from a Secret to override files from ConfigMaps */ -}}
    {{- range $kind := (list "Secret" "ConfigMap") -}}
      {{- $cfg := get $resources $kind -}}
      {{- $basePath := (printf "files/%s" $cfg.path) -}}
      {{- $allFiles := ($ctx.Files.Glob (printf "%s/**" $basePath)) -}}
      {{- if not $allFiles -}}
        {{- continue -}}
      {{- end -}}

      {{- $files := dict -}}
      {{- $entries := dict -}}
      {{- range $type := (list "bin" "tpl" "txt") -}}
        {{- $files := ($ctx.Files.Glob (printf "%s/%s/*" $basePath $type)) -}}
        {{- if not $files -}}
          {{- continue -}}
        {{- end -}}

        {{- range $path, $_ := $files -}}
          {{- $details := (include "__arkcase.file-resource.details" $path | fromYaml) -}}
          {{- $key := $details.name -}}
          {{- if hasKey $index $key -}}
            {{- /* It's a duplicate of some kind, and since we're processing in order of priority, we skip it */ -}}
            {{- /* $index is different from $entries b/c it includes stuff from both Secret and ConfigMap */ -}}
            {{- continue -}}
          {{- end -}}
          {{- $entries = set $entries $key $details -}}
          {{- $index = set $index $key true -}}
        {{- end -}}
      {{- end -}}
      {{- if $entries -}}
        {{- $result = set $result $kind $entries -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- define "__arkcase.file-resources.list-files" -}}
  {{- $args :=
    dict
      "ctx" $
      "template" "__arkcase.file-resources.list-files.compute"
  -}}
  {{- include "__arkcase.tools.getCachedValue" $args -}}
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
    {{- $rendered := dict -}}
    {{- $fileList := (include "__arkcase.file-resources.list-files" $ctx | fromYaml) -}}
    {{- range $kind := (list "Secret" "ConfigMap") }}
      {{- if not (hasKey $fileList $kind) }}
        {{- continue }}
      {{- end }}

      {{- $cfg := get $resources $kind }}
      {{- $basePath := (printf "files/%s" $cfg.path) }}
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

{{- define "arkcase.file-resource.volumeMount" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- /* cheat a little since we know this should only be called from specific points */ -}}
    {{- fail "Must provide the root context (. or $) as the only parameter" -}}
  {{- end -}}
  {{- $mountPath := ($.mountPath | required "Must provide the mountPath value for the resource file you wish to mount") -}}
  {{- $subPath := (hasKey $ "subPath" | ternary $.subPath ($mountPath | base) | required "The subPath to be mounted must not be an empty string") -}}

  {{- /* Find the resource in the file list, and render the correct volumeMount entry */ -}}
  {{- $fileList := (include "__arkcase.file-resources.list-files" $ctx | fromYaml) -}}
  {{- if $fileList }}

    {{- /* Regardless of whether it's a configmap or a secret, this is the name to use */ -}}
    {{- $resourceName := (include "arkcase.file-resource.name" $ctx) -}}
    {{-
      $ref :=
        dict
          "Secret"    "secret"
          "ConfigMap" "config"
    -}}

    {{- range $resource, $entries := $fileList }}
      {{- if not (hasKey $entries $subPath) }}
        {{- continue }}
      {{- end }}

      {{- $type := get $ref $resource }}
      {{- $details := get $entries $subPath }}
- name: {{ include "__arkcase.file-resource.volumeName" $type | quote }}
  mountPath: {{ $mountPath | quote }}
  subPath: {{ $subPath | quote }}
  readOnly: true
      {{- break }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "arkcase.file-resource.volumes" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- /* cheat a little since we know this should only be called from specific points */ -}}
    {{- fail "Must provide the root context (. or $) as the only parameter" -}}
  {{- end -}}

  {{- $fileList := (include "__arkcase.file-resources.list-files" $ctx | fromYaml) -}}
  {{- if $fileList }}
    {{- /* Regardless of whether it's a configmap or a secret, this is the name to use */ -}}
    {{- $resourceName := (include "arkcase.file-resource.name" $ctx) -}}

    {{-
      $allRef :=
        dict
          "Secret"    (dict "type" "secret" "typeAnchor" "secret"    "nameAnchor" "secretName")
          "ConfigMap" (dict "type" "config" "typeAnchor" "configMap" "nameAnchor" "name")
    -}}
    {{- range $resource := (list "Secret" "ConfigMap") }}
      {{- if not (hasKey $fileList $resource) }}
        {{- continue }}
      {{- end }}
      {{- $entries := get $fileList $resource }}
      {{- $ref := get $allRef $resource }}
- name: {{ include "__arkcase.file-resource.volumeName" $ref.type | quote }}
  {{ $ref.typeAnchor }}:
    optional: false
    {{ $ref.nameAnchor }}: {{ $resourceName | quote }}
    defaultMode: 0444
    items:
      {{- range $key := (keys $entries | sortAlpha) }}
        {{- $details := get $entries $key }}
      - key: {{ $key | quote }}
        path: {{ $key | quote }}
        {{- if $details.mode }}
        mode: {{ $details.mode }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}
