<xsl:stylesheet version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:param name="POD_HOSTNAME" />
	<xsl:param name="KEYSTORE" />
	<xsl:param name="KEYSTORE_PASSWORD" />

	<xsl:output method="xml" indent="yes" />

	<xsl:template name="string-replace">
		<xsl:param name="string" />
		<xsl:param name="replace" />
		<xsl:param name="with" />

		<xsl:choose>
			<xsl:when test="contains($string, $replace)">
				<xsl:value-of select="substring-before($string, $replace)" />
				<xsl:value-of select="$with" />
				<xsl:call-template name="string-replace">
					<xsl:with-param name="string" select="substring-after($string,$replace)" />
					<xsl:with-param name="replace" select="$replace" />
					<xsl:with-param name="with" select="$with" />
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$string" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="replace-params">
		<xsl:param name="input" />
		<xsl:variable name="step1">
			<xsl:call-template name="string-replace">
				<xsl:with-param name="string" select="$input" />
				<xsl:with-param name="replace" select="'${POD_HOSTNAME}'" />
				<xsl:with-param name="with" select="$POD_HOSTNAME" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:variable name="step2">
			<xsl:call-template name="string-replace">
				<xsl:with-param name="string" select="$step1" />
				<xsl:with-param name="replace" select="'${KEYSTORE}'" />
				<xsl:with-param name="with" select="$KEYSTORE" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:variable name="step3">
			<xsl:call-template name="string-replace">
				<xsl:with-param name="string" select="$step2" />
				<xsl:with-param name="replace" select="'${KEYSTORE_PASSWORD}'" />
				<xsl:with-param name="with" select="$KEYSTORE_PASSWORD" />
			</xsl:call-template>
		</xsl:variable>
		<xsl:value-of select="$step3" />
	</xsl:template>

	<xsl:template match="text()">
		<xsl:variable name="newText">
			<xsl:call-template name="replace-params">
				<xsl:with-param name="input" select="." />
			</xsl:call-template>
		</xsl:variable>
		<xsl:value-of select="$newText"/>
	</xsl:template>

	<xsl:template match="node()|@*">
		<xsl:copy>
			<xsl:apply-templates select="node()|@*"/>
		</xsl:copy>
	</xsl:template>
</xsl:stylesheet>
