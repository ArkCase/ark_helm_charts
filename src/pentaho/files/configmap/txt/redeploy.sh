#!/bin/bash
set -euo pipefail

[ -v BASE_DIR        ] || BASE_DIR="/app"
[ -v PENTAHO_HOME    ] || PENTAHO_HOME="${BASE_DIR}/pentaho"
[ -v RUN_MARKER      ] || RUN_MARKER="${PENTAHO_HOME}/.initRan"

[ -e "${RUN_MARKER}" ] || touch "${RUN_MARKER}"
exec /config-post.sh "${@}"
