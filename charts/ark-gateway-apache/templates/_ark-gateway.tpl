{{- define "arkcase.gateway.proxy.path" -}}
    {{- if (coalesce .preserveHost true) }}
    ProxyPreserveHost On
    {{- end }}
    {{- $mainPath := (include "ark.gateway.mainPath" (required "Must provide the path to proxy on" .path)) }}
    Redirect {{ .path | quote }} {{ $mainPath | quote }}
    <Location {{ $mainPath | quote }}>
        ProxyPass           {{ .targetUrl | quote }}
        ProxyPassReverse    {{ .targetUrl | quote }}
        {{- if .html }}
        {{- if .html.enabled }}
        ProxyHTMLEnable     On
        {{- end }}
        {{- if .html.extended }}
        ProxyHTMLExtended   On
        {{- end }}
        {{- range .html.urlMap }}
        ProxyHTMLURLMap     {{ .from }} {{ .to }}
        {{- end }}
        {{- end }}
    </Location>
{{- end -}}

{{- define "arkcase.gateway.proxy.vhost" -}}
    {{- if (coalesce .preserveHost true) }}
    ProxyPreserveHost On
    {{- end }}
    {{- if .ssl }}
    <VirtualHost _default_:443>
        {{- with .ssl }}
        SSLEngine        on

        {{- if .cipherSuite }}
        # SSLCipherSuite		ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP
        SSLCipherSuite			{{ .sslCipherSuite }}
        {{- end }}

        SSLCertificateFile		{{ required "Must provide the SSL certificate name" .cert }}
        SSLCertificateKeyFile	{{ required "Must provide the SSL certificate name" .key }}

        {{- if .caFile }}
        SSLCACertificateFile	{{ .caFile }}
        {{- else if .caPath }}
        SSLCACertificatePath	{{ .caPath }}
        {{- end }}
        {{- end }}
    {{- else }}
    <VirtualHost _default_:80>
    {{- end }}

        ServerName				{{ include "arkcase.tools.mustSingleHostname" .serverName }}
    {{- if .serverAlias }}
        ServerAlias				{{ range .serverAlias }} {{ include "arkcase.tools.mustSingleHostname" . }}{{- end }}
    {{- end }}

    {{- $mainPath := (include "ark.gateway.mainPath" (required "Must provide the path to proxy on" .path)) }}
        Redirect {{ .path | quote }} {{ $mainPath | quote }}
        <Location {{ $mainPath | quote }}>
            ProxyPass			{{ .targetUrl | quote }}
            ProxyPassReverse	{{ .targetUrl | quote }}
    {{- if .html }}
        {{- if .html.enabled }}
            ProxyHTMLEnable		On
        {{- end }}
        {{- if .html.extended }}
            ProxyHTMLExtended	On
        {{- end }}
        {{- range .html.urlMap }}
            ProxyHTMLURLMap		{{ .from }} {{ .to }}
        {{- end }}
    {{- end }}
        </Location>
    </VirtualHost>
{{- end -}}
