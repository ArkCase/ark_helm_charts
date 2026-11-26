{{- define "arkcase.app.image.artifacts" -}}
  {{- $imageName := "artifacts" -}}
  {{- $portal := (include "arkcase.portal" $.ctx | fromYaml) -}}
  {{- if $portal -}}
    {{- $imageName = (printf "%s-%s" $imageName $portal.containerSuffix) -}}
  {{- end -}}
  {{- $param := (merge (dict "name" $imageName) $) -}}
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

{{- define "arkcase.app.ingress.sanitize-modules" -}}
  {{- $ingress := ($ | default dict) -}}
  {{- $entries := dict -}}
  {{- $hasPrivate := false -}}
  {{- if and $ingress $ingress.modules -}}
    {{- range $module, $mode := ((kindIs "map" $ingress.modules) | ternary $ingress.modules dict) -}}
      {{ if (not (include "arkcase.tools.hostnamePart" $module)) -}}
        {{- continue -}}
      {{- end -}}
      {{- $mode = ($mode | toString | default "off" | lower) -}}
      {{- if (eq "true" $mode) -}}
        {{- $mode = "public" -}}
      {{- end -}}
      {{- if or (eq "public" $mode) (eq "private" $mode) -}}
        {{- $entries = set $entries $module $mode -}}
        {{- $hasPrivate = (or $hasPrivate (eq "private" $mode)) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- dict "private" $hasPrivate "entries" $entries | toYaml -}}
{{- end -}}

{{- define "arkcase.app.ingress.sanitize-cloud" -}}
  {{- $ctx := $.ctx -}}
  {{- if not (include "arkcase.isRootContext" $ctx) -}}
    {{- fail "The 'ctx' parameter given must be the root context (. or $)" -}}
  {{- end -}}

  {{- $baseUrl := $.baseUrl -}}
  {{- if or (not $baseUrl) (not (kindIs "map" $baseUrl)) -}}
    {{- fail "Must provide the parsed-out base URL object as the baseUrl parameter" -}}
  {{- end -}}

  {{- $ingress := ($.ingress | default dict) -}}
  {{- $result := dict -}}

  {{- /* First, set the basic stuff that overrides everything else */ -}}
  {{- if $ingress.className -}}
    {{- $result = set $result "className" $ingress.className -}}
  {{- end -}}
  {{- $result = set $result "labels" ((kindIs "map" $ingress.labels) | ternary $ingress.labels dict) -}}
  {{- $result = set $result "annotations" ((kindIs "map" $ingress.annotations) | ternary $ingress.annotations dict) -}}

  {{- /* Now check to see if we have any special cloud stuff */ -}}
  {{- /* (we ALWAYS have cloud stuff - even if it's just "default" */ -}}
  {{- $defaultCloud := (dict "type" "default") -}}

  {{- $cloud := dict -}}
  {{- if (hasKey $ingress "cloud") -}}
    {{- /* No backwards compatibility applicable */ -}}
    {{- $cloud = $ingress.cloud -}}
  {{- else if (include "arkcase.toBoolean" (get $ingress "ai5-rancher")) -}}
    {{- /* Provide a little backwards compatibility */ -}}
    {{- $hostname := $baseUrl.hostname -}}
    {{- if (hasKey $ingress "ai5-hostname") -}}
      {{- $hostname = (get $ingress "ai5-hostname" | toString) -}}
    {{- end -}}
    {{- $cloud = dict "type" "ai5" "ai5" (dict "public" (ne $hostname $baseUrl.hostname)) -}}
  {{- end -}}

  {{- /* Make sure the $cloud map has the expected form */ -}}
  {{- if not (kindIs "map" $cloud) -}}
    {{- if not (kindIs "string" $cloud) -}}
      {{- fail (printf "The ingress's cloud specification may be a string or a map, but not a %s: [%s]" (kindOf $cloud) $cloud) -}}
    {{- end -}}
    {{- $cloud = dict "type" $cloud -}}
  {{- end -}}
  {{- $cloud = merge $cloud $defaultCloud -}}

  {{- /* Get the specific cloud configurations from the values file */ -}}
  {{- $cloudType := $cloud.type -}}
  {{- $cloud = ((hasKey $cloud $cloudType) | ternary (get $cloud $cloudType) dict) -}}
  {{- if not (kindIs "map" $cloud) -}}
    {{- $cloud = dict -}}
  {{- end -}}

  {{- /* Get the general cloud configurations from the chart support */ -}}
  {{- $cloudSettings := ($ctx.Files.Get "clouds.yaml" | fromYaml | default dict) -}}
  {{- if $cloudSettings -}}
    {{- if not (hasKey $cloudSettings $cloudType) -}}
      {{- /* If we were given an unknown cloud configuration, use our default settings */ -}}
      {{- $cloudType = $defaultCloud.type -}}
    {{- end -}}
    {{- $cloudSettings = get $cloudSettings $cloudType -}}
    {{- if and $cloudSettings (kindIs "map" $cloudSettings) -}}

      {{- /* This will be used for rendering the labels/annotations */ -}}
      {{- $valueCtx := dict "url" (deepCopy $baseUrl) "cfg" (omit $cloud "labels" "annotations" "providesCertificate") -}}

      {{- /* Compute any dynamic label and annotation values */ -}}
      {{- range $element := (list "labels" "annotations") -}}
        {{- if not (hasKey $cloudSettings $element) -}}
          {{- continue -}}
        {{- end -}}

        {{- $map := (get $cloudSettings $element) -}}
        {{- range $key, $value := $map -}}
          {{- $map = set $map $key (tpl ($value | toString) $valueCtx | trim) -}}
        {{- end -}}
        {{- $cloud = set $cloudSettings $element $map -}}
      {{- end -}}

      {{- /* Apply the computed values where necessary */ -}}
      {{- $cloud = merge $cloud $cloudSettings -}}
    {{- end -}}
  {{- end -}}

  {{- /* Ensure this value is a boolean! */ -}}
  {{- $cloud = set $cloud "providesCertificate" (not (empty (include "arkcase.toBoolean" $cloud.providesCertificate))) -}}

  {{- merge $result (pick $cloud "className" "labels" "annotations" "providesCertificate") | toYaml -}}
{{- end -}}

{{- /*
Compute the inputs that decide the Ingress' existence and its rules, exactly as the chart that renders
the Ingress (app) sees them, so any chart may tell which of its services the Ingress routes to (see
arkcase.app.ingress.backends): only global settings count, other than the app chart's own baseUrl
(which only the app chart itself can see).

Parameter: the root context (either "." or "$")
*/ -}}
{{- define "arkcase.app.ingress.inputs" -}}
  {{- $ctx := $ -}}
  {{- $result := dict -}}
  {{- $global := ($ctx.Values.global | default dict) -}}

  {{- /* The app chart may also set it in its own configuration */ -}}
  {{- $baseUrl := (dig "subsys" "app" "settings" "baseUrl" "" $global | default (dig "settings" "baseUrl" "" $global) | toString) -}}
  {{- if (eq "app" (include "arkcase.subsystem.name" $ctx)) -}}
    {{- $baseUrl = (include "arkcase.tools.conf" (dict "ctx" $ctx "value" "baseUrl") | toString) -}}
  {{- end -}}
  {{- if $baseUrl -}}
    {{- $baseUrl = ((include "arkcase.tools.parseUrl" $baseUrl) | fromYaml) -}}

    {{- $ingress := ($ctx.Values.global.ingress | default dict) -}}
    {{- $ingress = (kindIs "map" $ingress) | ternary $ingress dict -}}

    {{- $dev := (include "arkcase.dev" $ctx | fromYaml) -}}

    {{- $hostnames := list $baseUrl.hostname -}}
    {{- /* For development mode, we enable other hostnames */ -}}
    {{- if $dev -}}
      {{- $hostnames = append $hostnames "localhost.localdomain" -}}
    {{- end -}}

    {{-
      $result = dict
        "baseUrl" $baseUrl
        "ingress" $ingress
        "enabled" (or (not (hasKey $ingress "enabled")) (not (empty (include "arkcase.toBoolean" $ingress.enabled))))
        "hostnames" $hostnames
        "portal" (include "arkcase.portal" $ctx | fromYaml)
        "dev" $dev
        "modules" (include "arkcase.app.ingress.sanitize-modules" $ingress | fromYaml)
        "contentDialect" (dig "subsys" "content" "settings" "dialect" "" $global | default "s3" | toString | lower)
    -}}
  {{- end -}}
  {{- $result | toYaml -}}
{{- end -}}

{{- /*
Compute the list of the Ingress' backends (each a map with the service's name, and its port as
the Ingress refers to it), or an empty list if there's no Ingress. The network policies use it to
let the Ingress controller (wherever it may be) reach the pods behind those services.

Parameter: the root context (either "." or "$")
*/ -}}
{{- define "arkcase.app.ingress.backends" -}}
  {{- $inputs := (include "arkcase.app.ingress.inputs" $ | fromYaml) -}}
  {{- $result := list -}}
  {{- if and $inputs $inputs.enabled $inputs.hostnames -}}
    {{- range $rule := (include "arkcase.app.ingress.rules" $inputs | fromYamlArray) -}}
      {{- range $path := (dig "http" "paths" list $rule) -}}
        {{- $service := (dig "backend" "service" dict $path) -}}
        {{- if $service.name -}}
          {{- $result = append $result (dict "name" $service.name "port" ($service.port | default dict)) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $result | uniq | toYaml -}}
{{- end -}}

{{- /*
Render the Ingress rules (a list), so they may be consumed both by the Ingress itself
and by the network policies that grant access to its backends

Parameter: the inputs computed by arkcase.app.ingress.inputs
*/ -}}
{{- define "arkcase.app.ingress.rules" -}}
  {{- $hostnames := $.hostnames -}}
  {{- $portal := $.portal -}}
  {{- $dev := $.dev -}}
  {{- $modules := $.modules -}}
  {{- $contentDialect := $.contentDialect -}}
  {{- range $host := $hostnames }}
- host: {{ $host | quote }}
  http:
    paths:
      - path: "/"
        pathType: Prefix
        backend:
          service:
            name: "core"
            port:
              number: 8443
    {{- if $portal }}
      # We'll re-enable this when we figure out how to cleanly
      # expose Neo4j for user consumption
      # - path: "/browser"
      #   pathType: Prefix
      #   backend:
      #     service:
      #       name: "analytics"
      #       port:
      #         number: 8443
    {{- end }}
    {{- if or $dev $modules.entries.artifacts }}
      - path: "/artifacts"
        pathType: Prefix
        backend:
          service:
            name: "app-artifacts"
            port:
              number: 443
    {{- end }}
    {{- if or $dev $modules.entries.content }}
      {{- if (eq $contentDialect "alfresco") }}
      - path: "/alfresco"
        pathType: Prefix
        backend:
          service:
            name: "content-main"
            port:
              number: 8443
      - path: "/api-explorer"
        pathType: Prefix
        backend:
          service:
            name: "content-share"
            port:
              number: 8443
      - path: "/share"
        pathType: Prefix
        backend:
          service:
            name: "content-share"
            port:
              number: 8443
      {{- end }}
      {{- if (eq $contentDialect "s3") }}
      - path: "/minio"
        pathType: Prefix
        backend:
          service:
            name: "content-main"
            port:
              number: 9000
      {{- end }}
    {{- end }}
    {{- if or $dev $modules.entries.messaging }}
      - path: "/console"
        pathType: Prefix
        backend:
          service:
            name: "messaging"
            port:
              number: 8443
    {{- end }}
    {{- if or $dev $modules.entries.reports }}
      - path: "/pentaho"
        pathType: Prefix
        backend:
          service:
            name: "reports"
            port:
              number: 8443
    {{- end }}
    {{- if or $dev $modules.entries.search }}
      - path: "/solr"
        pathType: Prefix
        backend:
          service:
            name: "search"
            port:
              number: 8983
    {{- end }}
  {{- end }}
{{- end -}}
