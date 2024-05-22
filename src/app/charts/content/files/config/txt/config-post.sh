#!/bin/bash

[ -v DEBUG ] || DEBUG="false"
case "${DEBUG,,}" in
	true | t | 1 | on | y | yes | enabled | enable | active ) DEBUG="true" ;;
	* ) DEBUG="false" ;;
esac

timestamp()
{
	/usr/bin/date -Ins -u
}

say()
{
	echo -e "$(timestamp): ${@}"
}

err()
{
	say "❌ ${@}" 1>&2
}

fail()
{
	err "${@}"
	exit ${EXIT_CODE:-1}
}

cleanup()
{
	[ -v RUN_MARKER ] || RUN_MARKER=""
	[ -z "${RUN_MARKER}" ] || rm -rf "${RUN_MARKER}" &>/dev/null
}

RUN_MARKER="${HOME}/.initRan"
trap cleanup EXIT
set -euo pipefail

[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v DATA_DIR ] || DATA_DIR="${BASE_DIR}/data"
[ -v LOGS_DIR ] || LOGS_DIR="${DATA_DIR}"

if [ -d "${LOGS_DIR}" ] ; then
	LOG_FILE="${LOGS_DIR}/config-post.log"
	exec >> >(/usr/bin/tee -a "${LOG_FILE}")
	exec 2>&1
	say "Logs redirected to [${LOG_FILE}]"
fi

# By default, wait up to 300 seconds if not told otherwise
[ -v INIT_POLL_SLEEP ] || INIT_POLL_SLEEP=2
[[ "${INIT_POLL_SLEEP}" =~ ^[1-9][0-9]*$ ]] || INIT_POLL_SLEEP=2
[ -v INIT_MAX_WAIT ] || INIT_MAX_WAIT=300
[[ "${INIT_MAX_WAIT}" =~ ^[1-9][0-9]*$ ]] || INIT_MAX_WAIT=300

[ -v ADMIN_URL ] || ADMIN_URL=""
[ -n "${ADMIN_URL}" ] || ADMIN_URL="https://localhost:9000"
[[ "${ADMIN_URL}" =~ ^(.*)/*$ ]] && ADMIN_URL="${BASH_REMATCH[1]}"
PROBE_URL="${ADMIN_URL}/minio/health/ready"

START="$(date +%s)"
say "Starting the polling cycle"
while true ; do
	/usr/bin/curl -fsSL -m 5 "${PROBE_URL}" &>/dev/null && break
	NOW="$(date +%s)"
	[ $(( NOW - START )) -ge ${INIT_MAX_WAIT} ] && fail "Timed out waiting for the URL [${PROBE_URL}] to come up"
	# If sleep didn't succeed, it means it got signaled, which
	# Means we need to stop what we're doing and puke out
	sleep ${INIT_POLL_SLEEP} || fail "Sleep interrupted, can't continue polling"
done
OUT="$(/usr/bin/curl -fL -m 5 "${PROBE_URL}" 2>&1)" || fail "Unable to access the URL [${PROBE_URL}] (rc=${?}): ${OUT}"

say "The URL [${PROBE_URL}] responded, continuing"

INSTANCE="local"

# Add the configuration for MC control
mcli config host add "${INSTANCE}" "${ADMIN_URL}" "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"

POLICIES=("consoleAdmin" "readwrite")
for POLICY in "${POLICIES[@]}" ; do
	# If the policy is already set, keep going
	mcli idp ldap policy entities --policy "${POLICY}" "${INSTANCE}" |& grep -qi "${LDAP_ADMIN_GROUP}" && continue

	# Apply the policy
	mcli idp ldap policy attach "${INSTANCE}" "${POLICY}" --group="${LDAP_ADMIN_GROUP}" || fail "Unable to set the [${POLICY}] policy for [${LDAP_ADMIN_GROUP}]"
done

# Create the "arkcase" user if they don't exist
# Grant the necessary (admin, for now) access to the "arkcase" user

exit 0
