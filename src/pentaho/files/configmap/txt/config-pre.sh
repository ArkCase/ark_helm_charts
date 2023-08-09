#!/bin/bash

say() {
	echo -e "$(date -Isec -u): ${@}"
}

fail() {
	say "${@}" 1>&2
	exit ${EXIT_CODE:-1}
}

set -euo pipefail

[ -v BASE_DIR ] || BASE_DIR="/app"
[ -v INIT_DIR ] || INIT_DIR="${BASE_DIR}/init"

[ -v DB_DIALECT ] || fail "The DB dialect (\${DB_DIALECT}) has not been chosen"

say "Initializing the Pentaho database configurations at [${PENTAHO_SERVER}]..."

# Set the correct audit_sql ... no harm in doing this every time (right?)
SRC_AUDIT_XML="${PENTAHO_SERVER}/pentaho-solutions/system/dialects/${DB_DIALECT}/audit_sql.xml"
[ -f "${SRC_AUDIT_XML}" ] || fail "There's no audit_sql.xml file for DB dialect [${DB_DIALECT}], cannot continue"
TGT_AUDIT_XML="${PENTAHO_SERVER}/pentaho-solutions/system/audit_sql.xml"
say "Setting the audit_xml file for dialect ${DB_DIALECT}..."
cp -vf "${SRC_AUDIT_XML}" "${TGT_AUDIT_XML}"

[ -v LB_DIR ] || LB_DIR="${BASE_DIR}/lb"
say "Running the Liquibase DB updates"
"${LB_DIR}/run-liquibase-updates"

exit 0
