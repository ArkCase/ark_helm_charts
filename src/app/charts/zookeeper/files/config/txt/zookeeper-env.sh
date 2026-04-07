#!/bin/bash

. /.functions

#
# Wait until the SSL stuff is ready!
#
START="$(date -u +%s)"
MAX="120"
MAX_STR="$(secs_to_timestr "${MAX}")"
FIRST="true"
while true ; do
	is_file "${SSL_DIR}/.env" && break
	as_boolean "${FIRST}" && sleeping "The SSL configuration isn't ready yet, will wait up to ${MAX_STR}"
	FIRST="false"
	sleep 0.1 || fail "Sleep interrupted!"
	NOW="$(date -u +%s)"
	[ $(( NOW - START )) -lt ${MAX} ] || fail "The SSL configuration didn't come up in time!"
done

as_boolean "${FIRST}" || ok "SSL configuration completed!"

init_ssl
