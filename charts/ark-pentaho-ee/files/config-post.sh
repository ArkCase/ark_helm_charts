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

# By default, wait up to 90 seconds if not told otherwise
[ -v INIT_POLL_SLEEP ] || INIT_POLL_SLEEP=2
[[ "${INIT_POLL_SLEEP}" =~ ^[1-9][0-9]*$ ]] || INIT_POLL_SLEEP=2
[ -v INIT_MAX_WAIT ] || INIT_MAX_WAIT=90
[[ "${INIT_MAX_WAIT}" =~ ^[1-9][0-9]*$ ]] || INIT_MAX_WAIT=90

[ -v ADMIN_URL ] || ADMIN_URL="http://localhost:2002/pentaho"

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

# TODO: Remove this when ready to test
exit 0

[ -f "${RUN_MARKER}" ] || exit 0

# wait until port 2002 is open, then...

[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v INIT_DIR ] || INIT_DIR="${BASE_DIR}/init"

REPORT_INSTALLER="${PENTAHO_HOME}/pentaho-server/import-export.sh"

install_report() {
	local URL_PATH="${1}"
	local SRC_FILE="${2}"

	"${REPORT_INSTALLER}" \
		--import \
		--url="${ADMIN_URL}" \
		--username="${ADMIN_USERNAME}"
		--password="${ADMIN_PASSWORD}" \
		--path="/public${URL_PATH}" \
		--file-path="${SRC_FILE}" \
		--logfile="${UPLOAD_LOG_FILE}" \
		--charset=UTF-8 \
		--permission=true \
		--overwrite=true \
		--retainOwnership=true
	return ${?}
}

list_reports() {
	local REPORTS_DIR="${1}"
	find "${REPORTS_DIR}" -type f | \
		sed -e "s;^${REPORTS_DIR}/;/;g" | \
		sort
}

#
# TODO: How do we populate these? (especially the password)
#
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="admin"

#
# Install reports
#
REPORTS_DIR="${INIT_DIR}/reports"
while read REPORT_SRC_FILE ; do
	# Remove any leading dot, but preserve any leading slash
	REPORT_SRC_FILE="${REPORT_SRC_FILE#.}"
	[ -n "${REPORT_SRC_FILE}" ] || continue

	REPORT_URL_PATH="$(dirname "${REPORT_SRC_FILE}")"

	# Remove any leading dot, but preserve any leading slash
	REPORT_URL_PATH="${REPORT_URL_PATH#.}"
	[ -n "${REPORT_URL_PATH}" ] || continue

	# TODO: Implement the "check if changed" thing, and only
	# deploy the report if it's new or changed
	# TODO: What if we want to undeploy? How do we do that?

	# Reconstitute the full path
	REPORT_SRC_FILE="${REPORTS_DIR}${REPORT_SRC_FILE}"

	# Install the report
	install_report "${REPORT_URL_PATH}" "${REPORT_SRC_FILE}" || \
		fail "Failed to install the extension for path [${REPORT_URL_PATH} from [${REPORT_SRC_FILE}]"
done < <(list_reports "${REPORTS_DIR}")

exit 0
