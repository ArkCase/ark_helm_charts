#!/bin/bash

[ -v DEBUG ] || DEBUG="false"
case "${DEBUG,,}" in
	true | t | 1 | on | y | yes | enabled | enable | active ) DEBUG="true" ;;
	* ) DEBUG="false" ;;
esac

timestamp() {
	/usr/bin/date -Ins -u
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

# First things first: go through every config directory in the DW reports areas,
# and render all the templates. THEN, add all the connections and schemas, one by one
JOBS=()
while read JOB ; do
	DPL="${JOB}/deploy"
	say "Deploying the DW reports at [${JOB}]..."

	INCOMPLETE="false"
	if [ -d "${DPL}" ] ; then
		while read T ; do
			# Remove the ".tpl" extension...
			F="${T%.*}"
			say "Rendering [${F}]..."
			render-template < "${T}" > "${F}"
		done < <(find "${DPL}" -type f -iname '*.tpl' | sort)

		# Find any connections (i.e. connection-*.json)
		while read CONNECTION ; do
			jq -r < "${CONNECTION}" &>/dev/null || fail "The connection at [${CONNECTION}] is not valid JSON"
			NAME="$(jq -r .name < "${CONNECTION}")"
			[ -z "${NAME}" ] && fail "The connection at [${CONNECTION}] lacks a name, can't continue"
	
			if ! /usr/local/bin/add-pdi-connection "${CONNECTION}" ; then
				say "\tconnection installation failed!"
				INCOMPLETE="true"
				continue
			fi

			# This is a small hack ... we've found intermittent ConcurrentModificationExceptions
			# puke all over report installation, so we're going to delay everything for a few
			# seconds to let this datasource creation operation settle down a little bit
			#
			# Yes... waits SUCK ... but until we find a more robust means of checking
			# if the DataSource is ready to be consumed, this should help for now
			sleep 5 || true

		done < <(find "${DPL}" -type f -iname 'connection-*.json' | sort)

		# Find any Mondrian schemata (i.e. schema-*.xml)
		while read SCHEMA ; do
			xmllint --noout "${SCHEMA}" &>/dev/null || fail "The schema file at [${SCHEMA}] is not valid XML"
			NAME="$(xmlstarlet sel -t -v "/Schema/@name" "${SCHEMA}")"
			[ -z "${NAME}" ] && fail "The Mondrian schema at [${SCHEMA}] lacks a name, can't continue"

			if ! /usr/local/bin/install-mondrian-schema "${SCHEMA}" ; then
				say "\tschema installation failed!"
				INCOMPLETE="true"
			fi
		done < <(find "${DPL}" -type f -iname 'schema-*.xml' | sort)
	fi

	if ${INCOMPLETE} ; then
		say "The artifacts for the job at [${JOB}] are incomplete, will not launch the job"
		continue
	fi

	# Find the first *.kjb (case-insensitive) file in that folder, and run that
	JOB="$(find "${JOB}" -mindepth 1 -maxdepth 1 -type f -iname '*.kjb' | sort | head -1)"
	if [ -n "${JOB}" ] ; then
		say "\tAdding a PDI bootup job: [${JOB}]"
		JOBS+=("${JOB}")
	fi

done < <(find "${DWHS_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)
JOBS_COUNT=${#JOBS[@]}

if [ ${JOBS_COUNT} -gt 0 ] ; then
	# Before we can run the dataminer first time, we MUST wait for
	# ArkCase to come up ... if it doesn't, we're screwed
	[ -v CORE_URL ] || CORE_URL="http://core:8080/arkcase/"
	say "Found ${JOBS_COUNT} dataminers:"
	for J in "${JOBS[@]}" ; do
		say "\t${J}"
	done
	say "Launching the background poller for [${CORE_URL}]..."
	coproc { poll_url "${CORE_URL}" ; }
else
	say "No jobs found, will not wait for ArkCase to boot up"
fi

# Install the reports ... this *has* to happen last b/c the FOIA/PDI stuff
# won't install cleanly if the rest of its dependencies aren't already covered
#
# We also run this in parallel with waiting for ArkCase to come up, b/c
# we try to be efficient with time :D
say "Deploying reports"
/usr/local/bin/install-reports
say "Reports deployed"

# If we have to rejoin with the ArkCase poller, do so...
if [ -v COPROC_PID ] ; then
	say "Joining the background poller for [${CORE_URL}]..."
	wait ${COPROC_PID} || fail "Failed to wait for ArkCase to be online"
fi

# Leave this here ... if there are no jobs, nothing will happen...
for JOB in "${JOBS[@]}" ; do
	JOB_LOG="${JOB%.*}.log"
	say "Launching the first-time PDI job [${JOB}]..."
	if run-kjb "${JOB}" < /dev/null &> "${JOB_LOG}" ; then
		say "Job completed successfully"
	else
		say "Errors detected, please review the above logs."
	fi
done

say "Post-configuration completed"
exit 0
