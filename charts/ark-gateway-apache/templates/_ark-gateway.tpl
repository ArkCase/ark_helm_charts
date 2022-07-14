{{- define "arkcase.gateway.cleanPath" -}}
  {{- $path := . -}}
  {{- if not $path -}}
    {{- $path = list -}}
  {{- else -}}
    {{- if not (kindIs "list" $path) -}}
      {{- $path = (toString $path | trim) -}}
      {{- $path = (splitList "/" (toString $path)) -}}
    {{- else -}}
      {{- $path = (toStrings $path) -}}
    {{- end -}}
  {{- end -}}
  {{- printf "/%s" (join "/" (compact $path) | osClean) -}}
{{- end -}}

{{- define "arkcase.gateway.cleanUrl" -}}
  {{- $url := . -}}
  {{- if not $url -}}
    {{- $url = "" -}}
  {{- else -}}
    {{- $url = (toString $url) -}}
  {{- end -}}
  {{- if not (hasSuffix "/" $url) -}}
    {{- $url = (printf "%s/" $url) -}}
  {{- end -}}
  {{- $url -}}
{{- end -}}

{{- define "arkcase.gateway.proxy" -}}
  # Begin Custom Global configurations
  {{- with .settings }}{{- . | nindent 0 }}{{- end }}
  # End Custom Global configurations

  {{- if or .preserveHost (not (hasKey . "preserveHost")) }}
ProxyPreserveHost On
  {{- end }}

  {{- $vhost := false -}}
  {{- with .vhost }}
    {{- $vhost = true }}
    {{- if .ssl }}
<VirtualHost _default_:443>
      {{- with .ssl }}
    SSLEngine        on

    # SSLCipherSuite		ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP
        {{- if .cipherSuite }}
    SSLCipherSuite			{{ .cipherSuite }}
        {{- end }}

    SSLCertificateFile		{{ required "Must provide the SSL certificate name" .cert }}
    SSLCertificateKeyFile	{{ required "Must provide the SSL certificate name" .key }}

        {{- if .caFile }}
    SSLCACertificateFile	{{ .caFile }}
        {{- else if .caPath }}
    SSLCACertificatePath	{{ .caPath }}
        {{- end }}

        # Begin Custom SSL VHost configurations
        {{- with .settings }}{{- . | nindent 4 }}{{- end }}
        # End Custom SSL VHost configurations
      {{- end }}
    {{- else }}
<VirtualHost _default_:80>
    {{- end }}

    ServerName				{{ include "arkcase.tools.mustSingleHostname" .name }}
    {{- with .aliases }}
    ServerAlias				{{ range . }} {{ include "arkcase.tools.mustSingleHostname" . }}{{- end }}
    {{- end }}

    # Begin Custom VHost configurations
    {{- with .settings }}{{- . | nindent 4 }}{{- end }}
    # End Custom VHost configurations
  {{- end }}

  {{- range .locations }}
    {{- $cleanPath := "/" -}}
    {{- $mainPath := "/" -}}
    {{- if .path }}
      {{- $cleanPath = (include "arkcase.gateway.cleanPath" .path) }}
      {{- $mainPath = (printf "%s/" $cleanPath) }}
    Redirect {{ $cleanPath | quote }} {{ $mainPath | quote }}
    {{- end }}


    <Location {{ $mainPath | quote }}>
        {{- $url := (include "arkcase.gateway.cleanUrl" .url) }}
        ProxyPass           {{ $url | quote }}
        ProxyPassReverse    {{ $url | quote }}
        {{- if (.html).enabled }}
        ProxyHTMLEnable     On
          {{- if .html.extended }}
        ProxyHTMLExtended   On
          {{- end }}
          {{- range .html.urlMap }}
        ProxyHTMLURLMap     {{ .from | quote }} {{ .to | quote }}
          {{- end }}
        {{- end }}

        # Begin Custom Location configurations
        {{- with .settings }}{{- . | nindent 8 }}{{- end }}
        # End Custom Location configurations
    </Location>
  {{- end }}

  {{- if $vhost }}

</VirtualHost>
  {{- end }}
{{- end -}}
