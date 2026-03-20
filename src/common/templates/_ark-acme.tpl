{{- define "arkcase.acme.env" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given must be the root context (. or $)" -}}
  {{- end -}}
  {{- $fips := (not (empty (include "arkcase.fips" $))) -}}
  {{ include "arkcase.subsystem-access.env" (dict "ctx" $ "subsys" "acme" "key" "url" "name" "ACME_URL") | nindent 0 }}
- name: ACME_SERVICE_NAME
  value: {{ include "arkcase.service.name" $ | quote }}
- name: ACME_KEYSTORE_WITH_TRUSTS
  value: "true"

- name: GOLANG_FIPS140
  value: {{ $fips | ternary "on" "off" | quote }}
- name: SSL_DIR
  value: "/.ssl"

- name: JAVA_KEY_ALIAS
  value: "acme"
- name: JAVA_KEY_PASSWORD_FILE
  value: "$(SSL_DIR)/keystore.pass"

- name: JAVA_KEYSTORE
  value: "$(SSL_DIR)/keystore.pkcs12"
- name: JAVA_KEYSTORE_PASSWORD_FILE
  value: "$(JAVA_KEY_PASSWORD_FILE)"
- name: JAVA_KEYSTORE_TYPE
  value: {{ printf "%SPKCS12" ($fips | ternary "BC" "") | quote }}

- name: JAVA_TRUSTSTORE
  value: "$(JAVA_KEYSTORE)"
- name: JAVA_TRUSTSTORE_PASSWORD_FILE
  value: "$(JAVA_KEYSTORE_PASSWORD_FILE)"
- name: JAVA_TRUSTSTORE_TYPE
  value: "$(JAVA_KEYSTORE_TYPE)"

#
# These settings should be added to any JVM command
# to ensure that its SSL configuration matches what
# the system has available, even in FIPS mode
#
- name: JAVAX_NET_SSL_OPTIONS
  value: >-
    -Djavax.net.ssl.keyAlias=$(JAVA_KEY_ALIAS)
    -Djavax.net.ssl.keyPasswordFile=$(JAVA_KEY_PASSWORD_FILE)
    -Djavax.net.ssl.keyStore=$(JAVA_KEYSTORE)
    -Djavax.net.ssl.keyStorePasswordFile=$(JAVA_KEYSTORE_PASSWORD_FILE)
    -Djavax.net.ssl.keyStoreType=$(JAVA_KEYSTORE_TYPE)
    -Djavax.net.ssl.trustStore=$(JAVA_TRUSTSTORE)
    -Djavax.net.ssl.trustStorePasswordFile=$(JAVA_TRUSTSTORE_PASSWORD_FILE)
    -Djavax.net.ssl.trustStoreType=$(JAVA_TRUSTSTORE_TYPE)
  {{- if $fips }}
    -Djava.security.properties=/usr/lib/jvm/java/conf/security/java.security.fips
    -Dssl.KeyManagerFactory.algorithm=PKIX
    -Dssl.TrustManagerFactory.algorithm=PKIX
    -Dorg.bouncycastle.fips.approved_only=true
    --add-opens=java.base/sun.security.internal.spec=org.bouncycastle.fips.core
  {{- end }}

# We keep this one separate in case containers wish to integrate it
# with their existing --module-path customizations, so we don't
# clobber whatever's there blindly, and allow for flexibility
- name: FIPS_MODULE_PATH
  value: "/app/crypto/bc"
{{- end -}}

{{- define "arkcase.acme.volumeMount" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given should be the root context (. or $)" -}}
  {{- end -}}
  {{- include "arkcase.subsystem-access.volumeMount" (dict "ctx" $ "subsys" "acme" "conn" "main" "key" "password" "mountPath" "/.acme.password") -}}
{{- end -}}

{{- define "arkcase.acme.volumeMount-shared" -}}
  {{- include "arkcase.acme.volumeMount" $ | nindent 0 }}
- name: "acme-ssl-vol"
  mountPath: "/.ssl"
{{- end -}}

{{- define "arkcase.acme.volume" -}}
  {{- if not (include "arkcase.isRootContext" $) -}}
    {{- fail "The parameter given should be the root context (. or $)" -}}
  {{- end -}}
  {{- include "arkcase.subsystem-access.volume" (dict "ctx" $ "subsys" "acme" "conn" "main") -}}
{{- end -}}

{{- define "arkcase.acme.volume-shared" -}}
  {{- include "arkcase.acme.volume" $ | nindent 0 }}
# The shared certificates volume is laughably tiny
- name: "acme-ssl-vol"
  emptyDir:
    medium: "Memory"
    sizeLimit: 4Mi
{{- end -}}
