#!/bin/bash

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

RUN_MARKER="${HOME_DIR}/.initRan"
trap cleanup EXIT
set -euo pipefail

[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v DATA_DIR ] || DATA_DIR="${BASE_DIR}/data"

[ -v LOGS_DIR ] || LOGS_DIR="${DATA_DIR}/logs"
if [ -d "${LOGS_DIR}" ] ; then
	LOG_FILE="${LOGS_DIR}/config-post.log"
	exec >> >(/usr/bin/tee -a "${LOG_FILE}")
	exec 2>&1
	say "Logs redirected to [${LOG_FILE}]"
fi

# By default, wait up to 90 seconds if not told otherwise
[ -v INIT_POLL_SLEEP ] || INIT_POLL_SLEEP=2
[[ "${INIT_POLL_SLEEP}" =~ ^[1-9][0-9]*$ ]] || INIT_POLL_SLEEP=2
[ -v INIT_MAX_WAIT ] || INIT_MAX_WAIT=90
[[ "${INIT_MAX_WAIT}" =~ ^[1-9][0-9]*$ ]] || INIT_MAX_WAIT=90

[ -v SOLR_URL ] || SOLR_URL="https://localhost:8983/solr"
SOLR_URL+="/admin/info/health"

START="$(date +%s)"
say "Starting the polling cycle"
while true ; do
	/usr/bin/curl -fsSL -m 5 "${SOLR_URL}" &>/dev/null && break
	NOW="$(date +%s)"
	[ $(( NOW - START )) -ge ${INIT_MAX_WAIT} ] && fail "Timed out waiting for the URL [${SOLR_URL}] to come up"
	# If sleep didn't succeed, it means it got signaled, which
	# Means we need to stop what we're doing and puke out
	sleep ${INIT_POLL_SLEEP} || fail "Sleep interrupted, can't continue polling"
done
say "The URL [${SOLR_URL}] responded, continuing"

# Don't run if init didn't run
[ -f "${RUN_MARKER}" ] || exit 0

# Run the scripts due to be run before Solr is booted up
[ -v INIT_DIR ] || INIT_DIR="${BASE_DIR}/init"
INIT_DIR="${INIT_DIR}/post"
if [ -d "${INIT_DIR}" ] ; then
	cd "${INIT_DIR}" || fail "Failed to CD into [${INIT_DIR}]"
	(
		set -euo pipefail
		while read script ; do
			[ -x "${script}" ] || continue
			# Run the script
			say "\tInitializing from script [${script}]..."
			"${script}" || exit 1
		done < <(/usr/bin/find . -mindepth 1 -maxdepth 1 -type f -name '*.sh' | sort)
	) || fail "Initialization failed"
fi
say "Initialization complete"
exit 0
