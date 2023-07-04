#!/bin/bash

set -euo pipefail

[ -v MARKER_LABEL ] || MARKER_LABEL="com.arkcase/readyTagger"
[ -v NAMESPACE ] || NAMESPACE="default"

COMMAND=""
[ ${#} -gt 0 ] && COMMAND="${1}"

if [ "${COMMAND}" == "--config" ] ; then
exec cat <<EOF
configVersion: v1
kubernetes:
  - apiVersion: v1
    name: "Monitor pods for manual readyness tagging"
    kind: Pod
    executeHookOnEvent: [ "Added", "Modified" ]
    executeHookOnSynchronization: true
    keepFullObjectsInMemory: true
    labelSelector:
      matchLabels:
        ${MARKER_LABEL}: "true"
    namespace:
      nameSelector:
        matchNames: [ "${NAMESPACE}" ]
    allowFailure: true
    queue: "ready-marker-pods"
EOF
fi

say() {
	echo -e "$(date -Ins): ${@}"
}

fail() {
	say "${@}" 1>&2
	exit ${EXIT_CODE:-1}
}

[ -v READY_LABEL ] || READY_LABEL="com.arkcase/ready"

DATA="$(<"${BINDING_CONTEXT_PATH}")"

#
# Get the pod's TRUE ready status
#
RC=0
STATUS="$(jq -r ".[].object.status.conditions[] | select(.type == \"Ready\") .status" <<< "${DATA}" 2>&1)" || RC=${?}
[ ${RC} -eq 0 ] || fail "Failed to parse the given data (rc=${RC}): ${STATUS}"

#
# Get and verify the pod's namespace
#
POD_NAMESPACE="$(jq -r ".[].object.metadata.namespace" <<< "${DATA}")" || RC=${?}
[ ${RC} -eq 0 ] || fail "Failed to parse the given data (rc=${RC}): ${STATUS}"

# If the namespace was the empty string, use "default"
[ -n "${POD_NAMESPACE}" ] || POD_NAMESPACE="default"
[ "${NAMESPACE}" == "${POD_NAMESPACE}" ] || fail "This script is only designed to work on a single namespace (${NAMESPACE}) - the pod is on the namespace ${POD_NAMESPACE}"

#
# Get the pod's name
#
POD_NAME="$(jq -r ".[].object.metadata.name" <<< "${DATA}")" || RC=${?}
[ ${RC} -eq 0 ] || fail "Failed to parse the given data (rc=${RC}): ${STATUS}"

#
# Everything checks out, do the actual work
#
case "${STATUS,,}" in
	# Pod is ready, apply the marker label so it will be added by the service
	true )
		say "Applying the ready label (${READY_LABEL}) as 'true' to ${POD_NAMESPACE}:${POD_NAME}"
		READY_VALUE="=true"
		;;

	# Pod is not ready, remove the marker label if present
	* )
		say "Removing the ready label (${READY_LABEL}) from ${POD_NAMESPACE}:${POD_NAME}"
		READY_VALUE="-"
		;;
esac

# Apply the label change
exec kubectl label pod --namespace "${POD_NAMESPACE}" "${POD_NAME}" "${READY_LABEL}${READY_VALUE}"
