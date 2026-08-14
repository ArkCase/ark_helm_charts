{{- define "arkcase.vsdb.enabled" -}}
  {{- $ai := (include "arkcase.ai" $ | fromYaml) -}}
  {{- if and $ai (include "arkcase.subsystem.enabled" $) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.vsdb.replicas" -}}
  {{- /* Must always be at least one */ -}}
  {{- $r := max ($ | int) 1 -}}

  {{- /* Set a max of 6 replicas b/c we're not completely, utterly stupid (yet) */ -}}
  {{- min (max ($ | int) 1) 6 -}}
{{- end -}}

{{- define "arkcase.vsdb.replicas-etcd" -}}
  {{- /* Must always be at least one */ -}}
  {{- $r := max ($ | int) 1 -}}

  {{- /* Must always be an odd number */ -}}
  {{- if (eq (mod $r 2) 0) -}}
    {{- $r = add 1 $r -}}
  {{- end -}}

  {{- /* Set a max of 5 replicas b/c we're not completely, utterly stupid (yet) */ -}}
  {{- min $r 5 -}}
{{- end -}}

{{- define "arkcase.vsdb.replicas-coord" -}}
  {{- /* Must be either 1 or 2, b/c it appears we don't need more */ -}}
  {{- min (max ($ | int) 1) 2 -}}
{{- end -}}
