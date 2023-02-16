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

set -euo pipefail

# By default, wait up to 90 seconds if not told otherwise
[ -v INIT_POLL_SLEEP ] || [[ "${INIT_POLL_SLEEP}" =~ ^[1-9][0-9]*$ ]] || INIT_POLL_SLEEP=2
[ -v INIT_MAX_WAIT ] || [[ "${INIT_MAX_WAIT}" =~ ^[1-9][0-9]*$ ]] || INIT_MAX_WAIT=90

[ -v SOLR_URL ] || SOLR_URL="http://localhost:8983/solr"
SOLR_URL+="/admin/info/health"

wait_for_solr "${SOLR_URL}" || fail "Failed to wait for Solr to start up - can't complete post-initialization"
START="$(date +%s)"
say "Starting the polling cycle"
while true ; do
	/usr/bin/curl -k -m 5 "${1}" &>/dev/null && break
	say "\tURL is not up yet at [${SOLR_URL}]"
	 NOW="$(date +%s)"
	[ $(( NOW - START )) -ge ${INIT_MAX_WAIT} ] && fail "Timed out waiting for the URL [${SOLR_URL}] to come up"
	# If sleep didn't succeed, it means it got signaled, which
	# Means we need to stop what we're doing and puke out
	sleep ${INIT_POLL_SLEEP} || fail "Sleep interrupted, can't continue polling"
done
say "The URL [${SOLR_URL}] responded, continuing"

# Run the scripts due to be run before Solr is booted up
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
