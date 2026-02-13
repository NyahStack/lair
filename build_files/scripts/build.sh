#!/usr/bin/env bash

# src: https://github.com/ublue-os/bazzite-dx/blob/1b91935ba127474e835229a91b7b483ffd41b98b/build_files/build.sh

set -eo pipefail

CONTEXT_PATH="$(realpath "$(dirname "$0")/..")" # should return /run/context/scripts
BUILD_SCRIPTS_PATH="$(realpath "$(dirname $0)")"
MAJOR_VERSION_NUMBER="$(sh -c '. /usr/lib/os-release ; echo $VERSION_ID')"
SCRIPTS_PATH="$(realpath "$(dirname "$0")/helpers")"
export CONTEXT_PATH
export SCRIPTS_PATH
export MAJOR_VERSION_NUMBER

run_buildscripts_for() {
	WHAT=$1
	shift
	# Complex "find" expression here since there might not be any overrides
	# Allows us to numerically sort scripts by stuff like "01-packages.sh" or whatever
	# CUSTOM_NAME is required if we dont need or want the automatic name
	find "${BUILD_SCRIPTS_PATH}/$WHAT" -maxdepth 1 -iname "*-*.sh" -type f -print0 | sort --zero-terminated --sort=human-numeric | while IFS= read -r -d $'\0' script ; do
		if [ "${CUSTOM_NAME}" != "" ] ; then
			WHAT=$CUSTOM_NAME
		fi
		printf "::group:: ===$WHAT-%s===\n" "$(basename "$script")"
		"$(realpath $script)"
		printf "::endgroup::\n"
	done
}

CUSTOM_NAME="base"
run_buildscripts_for .
CUSTOM_NAME=
