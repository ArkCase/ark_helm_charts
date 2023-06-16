#!/bin/bash -x

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

[ -v NODES ] || NODES=1
[[ "${NODES}" =~ ^[1-9][0-9]*$ ]] || fail "The number of nodes [${NODES}] is not a valid number"

# Default values
SHARDS=1
REPLICAS=${NODES}

# Have we been given a number of nodes that merits more sophisticated logic?
if [ ${NODES} -gt 2 ] ; then
	SHARDS=${NODES}
	REPLICAS=$(( ( SHARDS + 1 ) / 2 ))
fi

readarray -d , -t CORES < <(echo -n "${SOLR_CORES}")
say "Validating the core specifications"
CREATED=0
EXISTING=0
for C in "${CORES[@]}" ; do
	# Each core must have the format NAME=CONFIG
	[[ "${C}" =~ ^([^=]+)=([^=]+)$ ]] || fail "\tThe core specification [${C}] is invalid - it must be in the form \${NAME}=\${CONFIG}"
	NAME="${BASH_REMATCH[1]}"
	CONF="${BASH_REMATCH[2]}"

	config_exists "${CONF}" || fail say "The [${CONF}] configuration for collection [${NAME}] doesn't exist."

	if exists "${NAME}" ; then
		say "The [${NAME}] core already exists, skipping its creation"
		(( EXISTING += 1 ))
		continue
	fi

	if create "${NAME}" "${CONF}" "${SHARDS}" "${REPLICAS}" ; then
		(( CREATED += 1 ))
	else
		RC=${?}

		# Was it created by another instance coming up? If not, this is an error!
		exists "${NAME}" || fail "\tFailed to create the core as specified by [${C}] (rc=${RC})"

		# It *was* created concurrently! Complain mildrly, and exit cleanly
		say "The [${NAME}] core already exists, must have been created concurrently. Continuing."
		(( EXISTING += 1 ))
	fi
done

say "Work summary:"

PLURAL=""
[ ${CREATED} -eq 1 ] || PLURAL="s"
say "\t${CREATED} core${PLURAL} created"

PLURAL=""
[ ${ESISTING} -eq 1 ] || PLURAL="s"
say "\t${EXISTING} core${PLURAL} already existed"
