#!/bin/bash
set -euo pipefail

[ -v DEBUG ] || DEBUG="false"
case "${DEBUG,,}" in
	true | t | 1 | on | y | yes | enabled | enable | active ) DEBUG="true" ;;
	* ) DEBUG="false" ;;
esac

timestamp()
{
	date -Ins -u
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

[ -v BASE_DIR ] || BASE_DIR=""
[ -n "${BASE_DIR}" ] || BASE_DIR="/app"
[ -v DATA_DIR ] || DATA_DIR=""
[ -n "${DATA_DIR}" ] || DATA_DIR="${BASE_DIR}/data"
[ -v LOGS_DIR ] || LOGS_DIR=""
[ -n "${LOGS_DIR}" ] || LOGS_DIR="${DATA_DIR}"

if [ -d "${LOGS_DIR}" ] ; then
	LOG_FILE="${LOGS_DIR}/config-post.log"
	exec >> >(tee -a "${LOG_FILE}")
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
	curl -fsSL -m 5 "${PROBE_URL}" &>/dev/null && break
	NOW="$(date +%s)"
	[ $(( NOW - START )) -ge ${INIT_MAX_WAIT} ] && fail "Timed out waiting for the URL [${PROBE_URL}] to come up"
	# If sleep didn't succeed, it means it got signaled, which
	# Means we need to stop what we're doing and puke out
	sleep ${INIT_POLL_SLEEP} || fail "Sleep interrupted, can't continue polling"
done
OUT="$(curl -fL -m 5 "${PROBE_URL}" 2>&1)" || fail "Unable to access the URL [${PROBE_URL}] (rc=${?}): ${OUT}"

say "The URL [${PROBE_URL}] responded, continuing"

INSTANCE="local"

# Add the configuration for MC control
mcli config host add "${INSTANCE}" "${ADMIN_URL}" "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"

# We ALWAYS "create" the user accounts b/c we want to always rotate
# the passwords to whatever they are at the moment of bootup
PREFIX="MINIO_SERVICE"
for T in "RO" "RW" ; do
	POLICY="readonly"
	[ "${T}" == "RW" ] && POLICY="readwrite"
	U="${PREFIX}_${T}_USER"
	P="${PREFIX}_${T}_PASSWORD"
	[ -v "${U}" ] || continue
	[ -v "${P}" ] || continue
	[ -n "${!U}" ] && [ -n "${!P}" ] || continue

	say "Creating the ${T} service account with username [${!U}] (policy = ${POLICY})..."
	mcli admin user add "${INSTANCE}" "${!U}" "${!P}" || fail "Failed to create the user account for [${!U}]..."
	mcli admin policy attach "${INSTANCE}" "${POLICY}" --user "${!U}" || fail "Failed to attach the ${POLICY} policy to user [${!U}]..."
done

exit 0
