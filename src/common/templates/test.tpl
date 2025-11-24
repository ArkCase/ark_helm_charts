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

{{- range $index, $fullPath := (list
    "/some/stupid/path/somewhere/filename.ext"
    "some/relative/path/another-file.txt"
    "no-path.txt"
    "/another/stupid/path/somewhere/filename.ext.0123"
    "some/relative/path/another-file-with-mode.txt.0456"
    "no-path-with-mode.txt.0777"
  )
}}
file-{{ $index }}: {{- include "__arkcase.file-resource.details" $fullPath | nindent 2 }}
{{- end }}
