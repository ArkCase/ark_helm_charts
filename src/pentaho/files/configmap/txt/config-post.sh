#!/bin/bash

[ -v DEBUG ] || DEBUG="false"
case "${DEBUG,,}" in
	true | t | 1 | on | y | yes | enabled | enable | active ) DEBUG="true" ;;
	* ) DEBUG="false" ;;
esac

timestamp() {
	/usr/bin/date -Isec -u
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

cleanup() {
	[ -v RUN_MARKER ] || RUN_MARKER=""
	[ -z "${RUN_MARKER}" ] || rm -rf "${RUN_MARKER}" &>/dev/null
}

poll_url() {
	local URL="${1}"
	local START="$(date +%s)"
	say "Starting the polling cycle for [${URL}]..."
	while true ; do
		/usr/bin/curl -Lk -m 5 "${URL}" &>/dev/null && break
		local NOW="$(date +%s)"
		if [ $(( NOW - START )) -ge ${INIT_MAX_WAIT} ] ; then
			err "Timed out waiting for the URL [${URL}] to come up"
			return 1
		fi
		# If sleep didn't succeed, it means it got signaled, which
		# Means we need to stop what we're doing and puke out
		if ! sleep ${INIT_POLL_SLEEP} ; then
			err "Sleep interrupted, can't continue polling"
			return 1
		fi
	done
	say "The URL [${URL}] has responded, continuing"
	return 0
}

RUN_MARKER="${PENTAHO_HOME}/.initRan"
trap cleanup EXIT
set -euo pipefail

[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v DATA_DIR ] || DATA_DIR="${BASE_DIR}/data"
[ -v DWHS_DIR ] || DWHS_DIR="${DATA_DIR}/dw"
[ -v FOIA_DIR ] || FOIA_DIR="${DWHS_DIR}/foia"
[ -v LOGS_DIR ] || LOGS_DIR="${BASE_DIR}/logs"
[ -v INIT_DIR ] || INIT_DIR="${BASE_DIR}/init"
[ -v ADMIN_PORT ] || ADMIN_PORT="8080"

if [ -d "${LOGS_DIR}" ] ; then
	LOG_FILE="${LOGS_DIR}/config-post.log"
	exec >> >(/usr/bin/tee -a "${LOG_FILE}")
	exec 2>&1
	say "Logs redirected to [${LOG_FILE}]"
fi

# By default, wait up to 300 seconds if not told otherwise
[ -v INIT_POLL_SLEEP ] || INIT_POLL_SLEEP=2
[[ "${INIT_POLL_SLEEP}" =~ ^[1-9][0-9]*$ ]] || INIT_POLL_SLEEP=2
[ -v INIT_MAX_WAIT ] || INIT_MAX_WAIT=900
[[ "${INIT_MAX_WAIT}" =~ ^[1-9][0-9]*$ ]] || INIT_MAX_WAIT=900

[ -v ADMIN_URL ] || ADMIN_URL="http://localhost:${ADMIN_PORT}/pentaho/"
poll_url "${ADMIN_URL}" || fail "Cannot continue configuration if Pentaho is not online"

[ -f "${RUN_MARKER}" ] || exit 0

# Now we move into the more time-sensitive stuff
ARKCASE_CONNECTION_JSON="${PENTAHO_HOME}/.kettle/arkcase_connection.json"
if [ -f "${ARKCASE_CONNECTION_JSON}" ] ; then
	say "Deploying the Kettle DB connection from [${ARKCASE_CONNECTION_JSON}]"
	/usr/local/bin/add-pdi-connection "${ARKCASE_CONNECTION_JSON}"
fi

if [ -v FOIA_DIR ] && [ -d "${FOIA_DIR}" ] ; then

	# Deploy the Mondrian schema
	say "Deploying the Mondrian schema"
	/usr/local/bin/install-mondrian-schema "${FOIA_DIR}/mondrian_schema/foiaSchema1.4.xml"

	# Before we can run the dataminer first time, we MUST wait for
	# ArkCase to come up ... if it doesn't, we're screwed
	[ -v CORE_URL ] || CORE_URL="http://core:8080/arkcase/"
	say "Launching the background poller for [${CORE_URL}]..."
	coproc { poll_url "${CORE_URL}" ; }

fi

# Install the reports ... this *has* to happen last b/c the FOIA/PDI stuff
# won't install cleanly if the rest of its dependencies aren't already covered
say "Deploying reports"
/usr/local/bin/install-reports

if [ -v COPROC_PID ] ; then

	# We only enter this if the polling coprocess was started, above
	say "Joining the background poller for [${CORE_URL}]..."
	wait ${COPROC_PID} || fail "Failed to wait for ArkCase to be online"

	# TODO: This also needs to be a separate job/pod so it can be run periodically
	say "Launching the first-time dataminer process"
	/usr/local/bin/run-dataminer
fi

exit 0
