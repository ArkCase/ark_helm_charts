#!/bin/bash

say() {
	echo -e "${@}"
}

fail() {
	say "${@}"
	exit ${EXIT_CODE:-1}
}

set -euo pipefail

CONF="arkcase-conf.tar.gz"
[ -f "${CONF}" ] || exit 0
[ -v SOLR_HOME ] || fail "Can't find the SOLR_HOME variable - can't continue"

CONF="$(readlink -f "${CONF}")"

CONF_HOME="${SOLR_HOME}/configsets"
[ -d "${CONF_HOME}" ] || fail "Can't find the configuration home at [${CONF_HOME}]"
cd "${CONF_HOME}"

CONF_SOURCE="_default"
CONF_TARGET="arkcase"

if [ -d "${CONF_TARGET}" ] ; then
	say "The ${CONF_TARGET} configuration seems to already be deployed, skipping initialization"
	exit 0
fi

say "Copying the ${CONF_SOURCE} configuration into ${CONF_TARGET}..."
cp -Rprfv "${CONF_SOURCE}" "${CONF_TARGET}"
say "Extracting the bundled configuration"
tar -C "${CONF_TARGET}/conf" -xzvf "${CONF}"
say "Removing extraneous files"
rm -fv "${CONF_TARGET}/conf/managed-schema"
say "Initialization complete"
exit 0
