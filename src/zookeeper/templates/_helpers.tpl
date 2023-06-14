{{- define "arkcase.zookeeper.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "zookeeper.url" "detailed" true) | fromYaml) -}}
  {{- if and $url $url.global -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.zookeeper.nodes" -}}
  {{- $nodes := (include "arkcase.tools.conf" (dict "ctx" $ "value" "nodes")) -}}

  {{- /* If it's not set at all, use the default of 1 node */ -}}
  {{- if not $nodes -}}
    {{- $nodes = "0" -}}
  {{- else if not (regexMatch "^[0-9]+$" $nodes) -}}
    {{- fail (printf "The nodes value [%s] is not valid - it must be a numeric value" $nodes) -}}
  {{- end -}}

  {{- /* Remove leading zeros */ -}}
  {{- $nodes = (regexReplaceAll "^0+" $nodes "") -}}

  {{- /* In case it nuked the whole string :D */ -}}
  {{- $nodes = (empty $nodes) | ternary 0 (atoi $nodes) -}}
  {{- $pad := 0 -}}
  {{- if not (mod $nodes 2) -}}
    {{- /* It's an even number ... add one to support at least the given number of nodes */ -}}
    {{- $pad = 1 -}}
  {{- end -}}
  {{- $nodes = add $nodes $pad -}}

  {{- /* We have a hard limit of 255 nodes */ -}}
  {{- (gt $nodes 255) | ternary 255 $nodes -}}
{{- end -}}

{{- define "arkcase.zookeeper.onePerHost" -}}
  {{- $onePerHost := (include "arkcase.tools.conf" (dict "ctx" $ "value" "onePerHost")) -}}
  {{- if (include "arkcase.toBoolean" $onePerHost) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.zookeeper.maxFailed" -}}
  {{- $nodes := (include "arkcase.zookeeper.nodes" $ | atoi) -}}
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
      {{- $messaging := (include "arkcase.tools.conf" (dict "ctx" $ "value" "messaging.url" "detailed" true)) -}}
      {{- if and $messaging $messaging.global -}}
        {{- /* Messaging does not require Zookeeper b/c it's external */ -}}
        {{- $messaging = false -}}
      {{- else -}}
        {{- /* Search only requires zookeeper if its clustering is enabled */ -}}
        {{- $messaging = or (not (hasKey $config "messaging")) ($config.messaging.enabled) -}}
      {{- end -}}
      {{- /* At this point, $messaging is "true" if it's being deployed embedded and in clustered mode */ -}}

      {{- /* Check to see if we've been given an external Solr URL */ -}}
      {{- $search := (include "arkcase.tools.conf" (dict "ctx" $ "value" "search.url" "detailed" true)) -}}
      {{- if and $search $search.global -}}
        {{- /* Search does not require Zookeeper b/c it's external */ -}}
        {{- $search = false -}}
      {{- else -}}
        {{- /* Search only requires zookeeper if its clustering is enabled */ -}}
        {{- $search = or (not (hasKey $config "search")) ($config.search.enabled) -}}
      {{- end -}}
      {{- /* At this point, $search is "true" if it's being deployed embedded and in clustered mode */ -}}

      {{- if or $messaging $search -}}
        {{- true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
