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
	if [ ${#WORKDIRS[@]} -gt 0 ] ; then
		for n in "${WORKDIRS[@]}" ; do
			rm -rf "${n}" &>/dev/null
		done
	fi
}

debug_report_installer() {
	say "\t${@}" 1>&2
}

WORKDIRS=()
RUN_MARKER="${PENTAHO_HOME}/.initRan"
trap cleanup EXIT
set -euo pipefail

[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v DATA_DIR ] || DATA_DIR="${BASE_DIR}/data"

[ -v LOGS_DIR ] || LOGS_DIR="${BASE_DIR}/logs"
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

[ -v ADMIN_URL ] || ADMIN_URL="http://localhost:8080/pentaho/"

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

# We have to sanitize the Admin URL to remove any trailing slashes
shopt -s extglob
ADMIN_URL="${ADMIN_URL%%+(/)}"
shopt -u extglob

[ -v INIT_DIR ] || INIT_DIR="${BASE_DIR}/init"
[ -v DATA_DIR ] || DATA_DIR="${BASE_DIR}/data"
[ -v LOGS_DIR ] || LOGS_DIR="${DATA_DIR}/logs"

REPORT_INSTALLER="${PENTAHO_HOME}/pentaho-server/import-export.sh"

extract_archive() {
	local TYPE="${1}"
	local SRC="${2}"

	local WORK="$(mktemp -d)"
	WORK="$(readlink -f "${WORK}")"

	# Track it for cleanup
	WORKDIRS+=("${WORK}")

	local C=""
	local ZIP="false"
	case "${TYPE,,}" in
		zip )
			unzip -uod "${WORK}" "${SRC}" 1>&2 || return ${?}
			ZIP="true"
			;;
		tgz ) C="z" ;;
		tbz ) C="j" ;;
		txz ) C="J" ;;
	esac
	"${ZIP}" || tar -C "${WORK}" -x${C}f "${SRC}" 1>&2 || return ${?}
	local L="${#WORK}"
	find "${WORK}" -type f | sort | while read f ; do
		local D="${f:${L}}"
		D="${D%/*}"
		echo "${D}:///:${f}"
	done
	return 0
}

is_report_installed() {
	local DEST="${1}"
	local HASH="${2}"

	local REPORTS_DB="${DATA_DIR}/.installedReports"

	# Is it listed in the reports database file? (only consider the last entry)
	local EXISTING="$(egrep "^([0-9a-f]{64})=${DEST}$" "${REPORTS_DB}" | tail -1)" || return 1

	# Does the record in the database file match our expected pattern?
	[[ "${EXISTING,,}" =~ ^([0-9a-f]{64})=(.*)$ ]] || return 1

	# Does the hash match our expected hash?
	[ "${BASH_REMATCH[0],,}" != "${HASH,,}" ] || return 1

	# Does the filename match exactly? (just for paranoia's sake)
	[ "${BASH_REMATCH[1]}" != "${DEST}" ] || return 1

	# Everything matches, the report is already installed
	return 0
}

mark_report_installed() {
	local DEST="${1}"
	local HASH="${2}"
	local REPORTS_DB="${DATA_DIR}/.installedReports"
	echo "${HASH}=${DEST}" >> "${REPORTS_DB}"
}

install_report() {
	local SRC_FILE="${1}"

	# If the file is an archive of some kind, then we make note of its name sans exception,
	# extract it flattened into a temporary directory, and deploy the files within
	# (we support zip, tar, and tar.gz archives)

	case "${SRC_FILE,,}" in
		*.zip | *.jar ) ARCHIVE_TYPE="zip" ;;
		*.tar ) ARCHIVE_TYPE="tar" ;;
		*.tar.gz | *.tgz ) ARCHIVE_TYPE="tgz" ;;
		*.tar.bz2 | *.tbz2 ) ARCHIVE_TYPE="tbz" ;;
		*.tar.xz | *.txz ) ARCHIVE_TYPE="txz" ;;
		* ) ARCHIVE_TYPE="" ;;
	esac

	local REPORTS=()
	if [ -n "${ARCHIVE_TYPE}" ] ; then
		# Extract, then enumerate the contents into the SRC_FILE array
		SRC_FILE="${REPORTS_DIR}/${SRC_FILE}"
		say "Extracting the reports from [${SRC_FILE}]..."
		readarray -t REPORTS < <(extract_archive "${ARCHIVE_TYPE}" "${SRC_FILE}")
	else
		REPORTS=("$(dirname "${SRC_FILE}"):///:${REPORTS_DIR}/${SRC_FILE}")
	fi

	local RC=0
	local ARCHIVE_INFO=""
	[ -z "${ARCHIVE_TYPE}" ] || ARCHIVE_INFO=" extracted from the archive [${SRC_FILE}]"
	local CMD=()
	local HASH=""
	for F in "${REPORTS[@]}" ; do
		[[ "${F}" =~ ^(.*):///:(.*)$ ]]
		local P="${BASH_REMATCH[1]}"
		F="${BASH_REMATCH[2]}"

		read HASH rest < <(sha256sum "${F}")
		B="${F##*/}"

		if is_report_installed "${P}/${B}" "${HASH}" ; then
			say "The report for [${P}]${ARCHIVE_INFO} is already installed."
			continue
		fi

		say "Installing the report from [${F}]${ARCHIVE_INFO}..."
		local UPLOAD_LOG_FILE="${LOGS_DIR}/uploads-$(date -u +%Y%m%d-%H%M%S)Z.log"
		CMD=(
			"${REPORT_INSTALLER}"
			--import
			--url="${ADMIN_URL}"
			--username="${ADMIN_USERNAME}"
			--password="${ADMIN_PASSWORD}"
			--path="/public${P}"
			--file-path="${F}"
			--logfile="${UPLOAD_LOG_FILE}"
			--charset=UTF-8
			--permission=true
			--overwrite=true
			--retainOwnership=true
		)
		${DEBUG} && say "\t${CMD[@]@Q}"
		(
			say "# Installing the report from [${F}]${ARCHIVE_INFO}..."
			say "COMMAND: ${CMD[@]@Q}"
			say "--------------------------------------------------------------------------------"
			exec "${CMD[@]}"
		) &> "${UPLOAD_LOG_FILE}"
		if grep -iq "Import was successful" "${UPLOAD_LOG_FILE}" ; then
			mark_report_installed "${P}/${B}" "${HASH}"
			say "\tReport installed successfully"
			rm -f "${UPLOAD_LOG_FILE}" &>/dev/null
		else
			err "\tFailed to install the report from [${F}]${ARCHIVE_INFO}\n$(cat "${UPLOAD_LOG_FILE}")"
			return ${?}
		fi
	done
	[ -z "${ARCHIVE_TYPE}" ] || say "Finished processing the reports contained in [${SRC_FILE}]"
	return 0
}

list_reports() {
	local REPORTS_DIR="${1}"
	[ -d "${REPORTS_DIR}" ] | return 0
	find "${REPORTS_DIR}" -type f | \
		sed -e "s;^${REPORTS_DIR}/;;g" | \
		sort
}

[ -v ADMIN_USERNAME ] || ADMIN_USERNAME="admin"
[ -v ADMIN_PASSWORD ] || ADMIN_PASSWORD="password"

if ${DEBUG} || [ -x "${REPORT_INSTALLER}" ] ; then
	#
	# Install reports
	#
	REPORTS_DIR="${INIT_DIR}/reports"
	while read FILE ; do

		# TODO: Implement the "check if changed" thing, and only
		# deploy the report if it's new or changed

		# TODO: What if we want to undeploy? How do we do that?

		# Install the report
		install_report "${FILE}" || \
			fail "Failed to install the report from [${FILE}]"
	done < <(list_reports "${REPORTS_DIR}")
else
	say "The reports installer executable could not be found at [${REPORT_INSTALLER}]"
fi

exit 0
