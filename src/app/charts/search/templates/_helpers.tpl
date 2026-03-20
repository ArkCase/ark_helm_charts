{{- define "arkcase.solr.maxUnavailable" -}}
  {{- /* Compute the number of replicas based on our formula */ -}}
  {{- $totalPods := max 1 ($ | toString | atoi) -}}
  {{- $maxUnavailable := "50%" -}}
  {{- if ge $totalPods 2 -}}
    {{- $replicas := (le $totalPods 2) | ternary $totalPods (div (add $totalPods 1) 2) -}}
    {{- /* We can lose up to ($replicas - 1) replicas */ -}}
    {{- $maxUnavailable = printf "%d%%" (div (mul (sub $replicas 1) 100) $totalPods) }}
  {{- end -}}
  {{- $maxUnavailable -}}
{{- end -}}

{{- define "arkcase.solr.sharding" -}}
  {{- $ctx := $ -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "Must send the root context as the only parameter" -}}
  {{- end -}}
  {{- $settings := (include "arkcase.subsystem.settings" $ctx | fromYaml) -}}
  {{- include "arkcase.toBoolean" $settings.enableSharding -}}
{{- end -}}
