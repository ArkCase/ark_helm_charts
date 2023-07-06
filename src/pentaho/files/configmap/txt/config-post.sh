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

RUN_MARKER="${PENTAHO_HOME}/.initRan"
trap cleanup EXIT
set -euo pipefail

[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v DATA_DIR ] || DATA_DIR="${BASE_DIR}/data"
[ -v LOGS_DIR ] || LOGS_DIR="${BASE_DIR}/logs"
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

START="$(date +%s)"
say "Starting the polling cycle"
while true ; do
	/usr/bin/curl -Lk -m 5 "${ADMIN_URL}" &>/dev/null && break
	say "\tURL is not up yet at [${ADMIN_URL}]"
	NOW="$(date +%s)"
	[ $(( NOW - START )) -ge ${INIT_MAX_WAIT} ] && fail "Timed out waiting for the URL [${ADMIN_URL}] to come up"
	# If sleep didn't succeed, it means it got signaled, which
	# Means we need to stop what we're doing and puke out
	sleep ${INIT_POLL_SLEEP} || fail "Sleep interrupted, can't continue polling"
done
say "The URL [${ADMIN_URL}] responded, continuing"

[ -f "${RUN_MARKER}" ] || exit 0

/install-reports

exit 0
