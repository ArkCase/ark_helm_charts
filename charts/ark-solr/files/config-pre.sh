#!/bin/bash

timestamp() {
	/usr/bin/date -Isec -u
}

say() {
	echo -e "$(timestamp): ${@}"
}

fail() {
	say "${@}" 1>&2
	exit ${EXIT_CODE:-1}
}

set -euo pipefail

# First things first - duplicate the Solr home contents into ${SOLR_HOME}
say "\tInitializing the SOLR_HOME at [${SOLR_HOME}]"
mkdir -p "${SOLR_HOME}"
( cd "${HOME_DIR}/server/solr" && tar -cf - . ) | tar -C "${SOLR_HOME}" -xf -
say "\t...SOLR_HOME is ready"

# Run the scripts due to be run before Solr is booted up
INIT_DIR="${INIT_DIR}/pre"
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
# This is important: ${HOME_DIR} must be *ephemeral* - this flag is only meant to
# inform when the init script ran, so we can run the post-init script in the helm chart
touch "${HOME_DIR}/.initRan"
exit 0
