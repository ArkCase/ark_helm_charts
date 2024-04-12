#!/bin/bash

say() {
	echo -e "${@}"
}

err() {
	say "ERROR: ${@}" 1>&2
}

fail() {
	say "${@}"
	exit ${EXIT_CODE:-1}
}

deploy_config() {
	local CONF="${1}"
	local CONF_SOURCE="${2##*/}"
	local CONF_TARGET="${3##*/}"

	case "${CONF_SOURCE}" in
		. | .. ) err "The source configuration [${CONF_SOURCE}] is not valid" ; return 1 ;;
	esac
	case "${CONF_TARGET}" in
		. | .. ) err "The target configuration [${CONF_TARGET}] is not valid" ; return 1 ;;
	esac
	if [ ! -f "${CONF}" ] ; then
		err "Can't find the configuration archive [${CONF}]"
		return 1
	fi

	# To avoid issues with directory changes
	CONF="$(readlink -f "${CONF}")"

	pushd "${CONF_HOME}"
	if [ -d "${CONF_TARGET}" ] ; then
		say "The ${CONF_TARGET} configuration seems to already be deployed, skipping initialization"
		return 0
	fi
	if [ ! -d "${CONF_SOURCE}" ] ; then
		say "The ${CONF_SOURCE} configuration can't be found"
		return 1
	fi

	say "Copying the ${CONF_SOURCE} configuration into ${CONF_TARGET}..."
	cp -Rprfv "${CONF_SOURCE}" "${CONF_TARGET}" || return 1
	say "Extracting the bundled configuration"
	tar -C "${CONF_TARGET}/conf" -xzvf "${CONF}" || return 1
	say "Removing extraneous files"
	rm -fv "${CONF_TARGET}/conf/managed-schema" || return 1
	say "Initialization complete"
	popd
	return 0
}

set -euo pipefail

[ -v SOLR_HOME ] || fail "Can't find the SOLR_HOME variable - can't continue"
CONF_HOME="${SOLR_HOME}/configsets"
[ -d "${CONF_HOME}" ] || fail "Can't find the configsets directory at [${CONF_HOME}]"

# Deploy the configuration
deploy_config "arkcase-conf.tar.gz" "_default" "arkcase"
