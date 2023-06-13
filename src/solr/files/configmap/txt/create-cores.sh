#!/bin/bash

set -euo pipefail

timestamp() {
	date -Isec -u
}

say() {
	echo -e "$(timestamp): ${@}"
}

err() {
	say "ERROR: ${@}" 1>&2
}

fail() {
	say "${@}"
	exit ${EXIT_CODE:-1}
}

create() {
	local NAME="${1}"
	local CONF="${2}"
	local SHARDS="${3}"
	local REPLICAS="${4}"

	[[ "${SHARDS}" =~ ^[1-9][0-9]*$ ]] || SHARDS=1
	[[ "${REPLICAS}" =~ ^[1-9][0-9]*$ ]] || REPLICAS=1

	solr create -c "${NAME}" -d "${CONF_HOME}/${CONF}" -n "${CONF}" -shards ${SHARDS} -replicationFactor ${REPLICAS} -V
}

config_exists() {
	local CONF="${1}"
	local DIR="${CONF_HOME}/${CONF}"
	[ -e "${DIR}" ] || return 1
	[ -d "${DIR}" ] || return 1
	[ -r "${DIR}" ] || return 1
	[ -x "${DIR}" ] || return 1
	return 0
}

exists() {
	local NAME="${1}"
	local RC=0

	# Run the query
	local JSON="$(curl -kL "http://localhost:8983/solr/admin/collections?action=colstatus&collection=${NAME}")" || RC=${?}
	[ ${RC} -eq 0 ] || return ${RC}

	# Examine the result
	local RESULT="$(jq -r ".${NAME}.stateFormat // \"missing\"" <<< "${JSON}")" || return ${?}

	RC=0
	[ "${RESULT}" == "missing" ] && RC=1
	return ${RC}
}

[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v DATA_DIR ] || DATA_DIR="${BASE_DIR}/data"
[ -v LOGS_DIR ] || LOGS_DIR="${DATA_DIR}/logs"

if [ -d "${LOGS_DIR}" ] ; then
	LOG_FILE="${LOGS_DIR}/create-cores.log"
	exec > >(/usr/bin/tee -a "${LOG_FILE}")
	exec 2>&1
	say "Logs redirected to [${LOG_FILE}]"
fi

[ -v SOLR_HOME ] || fail "Can't find the SOLR_HOME variable - can't continue"
CONF_HOME="${SOLR_HOME}/configsets"
[ -d "${CONF_HOME}" ] || fail "Can't find the configsets directory at [${CONF_HOME}]"

# If there are no cores to add, skip this job
[ -v SOLR_CORES ] || exit 0

MODE="cloud"

readarray -d , -t CORES < <(echo -n "${SOLR_CORES}")
say "Validating the core specifications"
PLURAL=""
[ ${#CORES[@]} -lt 2 ] || PLURAL="s"
for C in "${CORES[@]}" ; do
	# Each core must have the format NAME=CONFIG
	[[ "${C}" =~ ^([^=]+)=([^=]+)$ ]] || fail "\tThe core specification [${C}] is invalid - it must be in the form \${NAME}=\${CONFIG}"
	NAME="${BASH_REMATCH[1]}"
	CONF="${BASH_REMATCH[2]}"

	config_exists "${CONF}" || fail say "The [${CONF}] configuration for collection [${NAME}] doesn't exist."

	if exists "${NAME}" ; then
		say "The [${NAME}] core already exists, skipping its creation"
		continue
	fi

	# TODO: Allow these to be specified/computed somehow
	SHARDS=""
	REPLICAS=""

	create "${NAME}" "${CONF}" "${SHARDS}" "${REPLICAS}" || fail "\tFailed to create the core as specified by [${C}]"
done
say "Created ${#CORES[@]} core${PLURAL}"
