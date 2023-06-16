{{- define "arkcase.zookeeper.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "zookeeper.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.zookeeper.nodes" -}}
  {{- $nodes := max 1 ($ | toString | atoi) -}}
  {{- $pad := 0 -}}
  {{- if not (mod $nodes 2) -}}
    {{- /* It's an even number ... add one to support at least the given number of nodes */ -}}
    {{- $pad = 1 -}}
  {{- end -}}

  {{- /* We have a hard limit of 255 nodes */ -}}
  {{- min 255 (add $nodes $pad) -}}
{{- end -}}

{{- define "arkcase.zookeeper.maxFailed" -}}
  {{- $nodes := max 1 ($ | toString | atoi) -}}
  {{- /* We can lose at most half of our nodes */ -}}
  {{- div $nodes 2 -}}
{{- end -}}

{{- /*
  Return "true" if:
    * clustering is enabled
    * and there's no external ZooKeeper URL
    * and we're deploying either Artemis or Solr in embedded mode, and in clustered mode
*/ -}}
{{- define "arkcase.zookeeper.required" -}}
  {{- $external := (include "arkcase.zookeeper.external" $) -}}
  {{- if not $external -}}
    {{- $config := (include "arkcase.cluster" $ | fromYaml) -}}
    {{- if $config.enabled -}}
      {{- /* Check to see if we've been given an external Artemis URL */ -}}
      {{- $messaging := (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.url" "detailed" true) | fromYaml) -}}
      {{- $messaging = not (and $messaging $messaging.global) -}}

      {{- /* Check to see if we've been given an external Solr URL */ -}}
      {{- $search := (include "arkcase.tools.conf" (dict "ctx" $ "value" "search.url" "detailed" true) | fromYaml) -}}
      {{- $search = not (and $search $search.global) -}}

      {{- if or $messaging $search -}}
        {{- true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
