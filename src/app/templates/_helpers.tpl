{{- define "arkcase.app.image.artifacts" -}}
  {{- $imageName := "artifacts" -}}
  {{- $foia := (include "arkcase.foia" $.ctx | fromYaml) -}}
  {{- if $foia -}}
    {{- $imageName = (printf "%s-foia" $imageName) -}}
  {{- end -}}
  {{- $param := (merge (dict "name" $imageName) (omit $ "name")) -}}
  {{- include "arkcase.image" $param }}
{{- end -}}

{{- define "arkcase.artifacts.external" -}}
  {{- $url := (include "arkcase.tools.conf" (dict "ctx" $ "value" "app-artifacts.url" "detailed" true) | fromYaml) -}}
  {{- if or (and $url $url.global) -}}
    {{- true -}}
  {{- end -}}
{{- end -}}

{{- define "arkcase.app.issuerByDomain" -}}
  {{- $domain := (. | toString) -}}
  {{- $elements := (splitList "." $domain | compact) -}}
  {{- if (lt (len $elements) 2) -}}
    {{- fail (printf "Insufficient domain components in domain [%s] - must have at least 2" $domain) -}}
  {{- end -}}
  {{- /* Here we use reverse so we can grab the first two elements, and then flip them again */ -}}
  {{- slice (reverse $elements) 0 2 | reverse | join "-" -}}
{{- end -}}

{{- define "arkcase.app.rancher" -}}
  {{- $ctx := .ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $ingress := .ingress -}}
  {{- $baseUrl := .baseUrl -}}

  {{- $result := dict -}}
  {{- if and (hasKey $ingress "ai5-rancher") (not (empty (include "arkcase.toBoolean" (get $ingress "ai5-rancher")))) -}}
    {{- $dnsName := $baseUrl.hostname -}}
    {{- if (hasKey $ingress "ai5-hostname") -}}
      {{- $dnsName = (include "arkcase.tools.mustSingleHostname" (get $ingress "ai5-hostname" | toString)) -}}
      {{- /* Make sure the hostname has at least 3 components ... can't be a domain, or a tld */ -}}
      {{- if (lt (splitList "." $dnsName | len) 3) -}}
        {{- fail (printf "The ai5-hostname value [%s] is not valid - must have at least 3 components" $dnsName) -}}
      {{- end -}}
    {{- end -}}

    {{- /* TODO: Gate these based on specific flags? */ -}}
    {{- /* We use "toString" everywhere to ensure that the values are strings ... paranoia ;) */ -}}
    {{- $result = set $result "external-dns.alpha.kubernetes.io/hostname" ($dnsName | toString) -}}
    {{- $result = set $result "cert-manager.io/common-name" ($baseUrl.hostname | toString) -}}
    {{- $result = set $result "cert-manager.io/cluster-issuer" (include "arkcase.app.issuerByDomain" $baseUrl.hostname | toString) -}}
  {{- end -}}

  {{- $result | toYaml -}}
{{- end -}}
