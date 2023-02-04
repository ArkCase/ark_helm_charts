#!/bin/bash
set -euo pipefail

DBCONFIG="/dbconfig.json"

say() {
    echo -e "${@}"
}

fail() {
    say "${@}" 1>&2
    exit ${EXIT_CODE:-1}
}

[ -v PENTAHO_HOME ] || PENTAHO_HOME="/home/pentaho/app/pentaho/pentaho-server"

[ -d "${PENTAHO_HOME}" ] || fail "The Pentaho home directory could not be found at [${PENTAHO_HOME}], cannot continue."
[ -e "${DBCONFIG}" ] || fail "The Database configuration file ${DBCONFIG} is not there, cannot continue."
[ -f "${DBCONFIG}" ] || fail "The path ${DBCONFIG} is not a regular file, cannot continue."
[ -r "${DBCONFIG}" ] || fail "The Database configuration file ${DBCONFIG} is not readable, cannot continue."

DB_DIALECT="$(jq -r .dialect < "${DBCONFIG}")"
[ -n "${DB_DIALECT}" ] || fail "No dialect is set in the DB configuration file ${DBCONFIG}, cannot continue"
say "The database dialect is [${DB_DIALECT}]..."
SCRIPT_DIALECT="$(jq -r .script < "${DBCONFIG}")"
# Just for safety
if [ -z "${SCRIPT_DIALECT}" ] ; then
    say "\tNo scripts dialect provided, so using the same database dialect"
    SCRIPT_DIALECT="${DB_DIALECT}"
else
    say "The script dialect is [${DB_DIALECT}]..."
fi

say "Initializing the Pentaho configurations at [${PENTAHO_HOME}]..."

isInitialized()
{
    # TODO: Check to see if the DB is already initialized
    return 1
}

runScript() {
    local SCRIPT="${1}"
    say "Running the script [${SCRIPT}] (for dialect ${SCRIPT_DIALECT}"
}

# Set the correct audit_sql ... no harm in doing this every time (right?)
SRC_AUDIT_XML="${PENTAHO_HOME}/pentaho-solutions/system/dialects/${DB_DIALECT}/audit_sql.xml"
[ -f "${SRC_AUDIT_XML}" ] || fail "There's no audit_sql.xml file for DB dialect [${DB_DIALECT}], cannot continue"
TGT_AUDIT_XML="${PENTAHO_HOME}/pentaho-solutions/system/audit_sql.xml"
say "Setting the audit_xml file for dialect ${DB_DIALECT}..."
cp -vf "${SRC_AUDIT_XML}" "${TGT_AUDIT_XML}"

if ! isInitialized ; then
    # Run the correct scripts (but how?!?! We don't have the DBInit clients)
    SQL_DIR="${PENTAHO_HOME}/data/${SCRIPT_DIALECT}"
    [ -d "${SQL_DIR}" ] || fail "There are no SQL initialization scripts for dialect [${SCRIPT_DIALECT}], cannot continue"
    for n in create_jcr_*.sql create_quartz_*.sql create_repository_*.sql pentaho_mart_*.sql ; do
        runScript "${n}"
    done
    # TODO: Add the script that changes the default passwords into whatever is in the configurations ... there must also be
    #       dialectic versions of this script
fi

# Continue with normal bootup
exec start-pentaho.sh "${@}"
