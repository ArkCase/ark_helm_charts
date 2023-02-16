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

create_collection() {
	local NAME="${1}"
	local CONF="${2}"

	solr create -c "${NAME}" -d "${CONF_HOME}/${CONF}"
}

create_core() {
	local NAME="${1}"
	local CONF="${2}"

	solr create -c "${NAME}" -n "${CONF}"
}

set -euo pipefail

[ -v SOLR_HOME ] || fail "Can't find the SOLR_HOME variable - can't continue"
CONF_HOME="${SOLR_HOME}/configsets"
[ -d "${CONF_HOME}" ] || fail "Can't find the configsets directory at [${CONF_HOME}]"

# If there are no cores to add, skip this job
[ -v SOLR_CORES ] || exit 0

CLOUD="false"
MODE="core"

# TODO: How to identify if solr is in "cloud" or "standalone" mode?
${CLOUD} || MODE="collection"

readarray -d , -t CORES < <(echo -n "${SOLR_CORES}")
say "Validating the core specifications"
PLURAL=""
[ ${#CORES[@]} -lt 2 ] || PLURAL="s"
for C in "${CORES[@]}" ; do
	# Each core must have the format NAME=CONFIG
	[[ "${C}" =~ ^([^=]+)=([^=]+)$ ]] || fail "\tThe core specification [${C}] is invalid - it must be in the form \${NAME}=\${CONFIG}"
	NAME="${BASH_REMATCH[1]}"
	CONF="${BASH_REMATCH[2]}"

	"create_${MODE}" "${NAME}" "${CONF}" || fail "\tFailed to create the core specified by [${C}]"
done
say "Created ${#CORES[@]} core${PLURAL}"
