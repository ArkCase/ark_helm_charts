#!/bin/bash

say() {
	echo -e "$(date -Isec -u): ${@}"
}

fail() {
	say "${@}" 1>&2
	exit ${EXIT_CODE:-1}
}

initRequired()
{
	# TODO: How to properly identify if initialization is actually required?
	case "${1,,}" in
		mysql5 )
			export LAUNCH_COMMAND=""
			;;
		oracle10g )
			;;
		postgresql )
			;;
		sqlserver )
			;;
	esac
	return 1
}

renderPasswordScript() {
	local SCRIPT="${1}"
	# TODO: Render the password update script based on the database information
	return 0
}

runScript() {
	local SCRIPT="${1}"
	say "Running the script [${SCRIPT}] (from the ${SCRIPT_DIALECT} dialect)"
	# TODO: Run the given SQL script ...
	return 0
}

set -euo pipefail

[ -v INIT_DIR ] || INIT_DIR="${BASE_DIR}/init"

[ -v DBCONFIG ] || DBCONFIG="/dbconfig.json"
[ -e "${DBCONFIG}" ] || fail "No database configuration is available to initialize with"
[ -f "${DBCONFIG}" ] || fail "The path ${DBCONFIG} is not a regular file, cannot continue."
[ -r "${DBCONFIG}" ] || fail "The Database configuration file ${DBCONFIG} is not readable, cannot continue."

OUT="$(jq -r . < "${DBCONFIG}" 2>&1)" || fail "The Database configuration ${DBCONFIG} is malformed JSON, cannot continue:\n${OUT}"

DB_DIALECT="$(jq -r '.db.dialect // ""' < "${DBCONFIG}")"
[ -n "${DB_DIALECT}" ] || fail "No dialect is set in the DB configuration file ${DBCONFIG}, cannot continue"
say "The database dialect is [${DB_DIALECT}]..."

SCRIPT_DIALECT="$(jq -r '.db.scripts // ""' < "${DBCONFIG}")"
# Just for safety
if [ -z "${SCRIPT_DIALECT}" ] ; then
	say "\tNo scripts dialect provided, so using the same database dialect"
	SCRIPT_DIALECT="${DB_DIALECT}"
else
	say "The script dialect is [${DB_DIALECT}]..."
fi

say "Initializing the Pentaho database configurations at [${PENTAHO_SERVER}]..."

# Set the correct audit_sql ... no harm in doing this every time (right?)
SRC_AUDIT_XML="${PENTAHO_SERVER}/pentaho-solutions/system/dialects/${DB_DIALECT}/audit_sql.xml"
[ -f "${SRC_AUDIT_XML}" ] || fail "There's no audit_sql.xml file for DB dialect [${DB_DIALECT}], cannot continue"
TGT_AUDIT_XML="${PENTAHO_SERVER}/pentaho-solutions/system/audit_sql.xml"
say "Setting the audit_xml file for dialect ${DB_DIALECT}..."
cp -vf "${SRC_AUDIT_XML}" "${TGT_AUDIT_XML}"

if initRequired "${DB_DIALECT}" ; then
	# Run the correct scripts (but how?!?! We don't have the DBInit clients)
	SQL_DIR="${PENTAHO_SERVER}/data/${SCRIPT_DIALECT}"
	[ -d "${SQL_DIR}" ] || fail "There are no SQL initialization scripts for dialect [${SCRIPT_DIALECT}], cannot continue"
	pushd "${SQL_DIR}"
	runScript "${n}" || fail "Failed to initialize the database"
	renderPasswordScript "fix-passwords.sql" || fail "Failed to render the password update script"
	runScript "fix-passwords.sql" || fail "Failed to update the passwords as required"
	popd
else
	say "No database initialization is required"
fi
exit 0
