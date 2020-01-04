#!/bin/bash

#
# by TS, May 2019
#

# @param string $1 Path
# @param int $2 Recursion level
#
# @return string Absolute path
function realpath_osx() {
	local TMP_RP_OSX_RES=
	[[ $1 = /* ]] && TMP_RP_OSX_RES="$1" || TMP_RP_OSX_RES="$PWD/${1#./}"

	if [ -h "$TMP_RP_OSX_RES" ]; then
		TMP_RP_OSX_RES="$(readlink "$TMP_RP_OSX_RES")"
		# possible infinite loop...
		local TMP_RP_OSX_RECLEV=$2
		[ -z "$TMP_RP_OSX_RECLEV" ] && TMP_RP_OSX_RECLEV=0
		TMP_RP_OSX_RECLEV=$(( TMP_RP_OSX_RECLEV + 1 ))
		if [ $TMP_RP_OSX_RECLEV -gt 20 ]; then
			# too much recursion
			TMP_RP_OSX_RES="--error--"
		else
			TMP_RP_OSX_RES="$(realpath_osx "$TMP_RP_OSX_RES" $TMP_RP_OSX_RECLEV)"
		fi
	fi
	echo "$TMP_RP_OSX_RES"
}

# @param string $1 Path
#
# @return string Absolute path
function realpath_poly() {
	case "$OSTYPE" in
		linux*) realpath "$1" ;;
		darwin*) realpath_osx "$1" ;;
		*) echo "$VAR_MYNAME: Error: Unknown OSTYPE '$OSTYPE'" >/dev/stderr; echo -n "$1" ;;
	esac
}

VAR_MYNAME="$(basename "$0")"
VAR_MYDIR="$(realpath_poly "$0")"
VAR_MYDIR="$(dirname "$VAR_MYDIR")"

# ----------------------------------------------------------

function printUsageAndExit() {
	echo "Usage: $VAR_MYNAME <VERSION>" >/dev/stderr
	echo "Examples: $VAR_MYNAME 1.7" >/dev/stderr
	echo "          $VAR_MYNAME 5.6" >/dev/stderr
	echo "          $VAR_MYNAME 6.6" >/dev/stderr
	exit 1
}

if [ $# -eq 1 ] && [ "$1" = "-h" -o "$1" = "--help" ]; then
	printUsageAndExit
fi

if [ $# -lt 1 ]; then
	echo -e "Missing argument. Aborting.\n" >/dev/stderr
	printUsageAndExit
fi

OPT_IMG_VER="$1"
shift

cd "$VAR_MYDIR" || exit 1

# ----------------------------------------------------------

TMP_IMG_VER_SHORT="$(echo -n "$OPT_IMG_VER" | cut -f1-2 -d.)"
TMP_IMGVER_STR="$(echo -n "$TMP_IMG_VER_SHORT" | tr -d .)"

echo -n "$TMP_IMG_VER_SHORT" | grep -q -E "[0-9]{1,2}[\.][0-9]{1,2}" || {
	echo "Invalid version. Must have format 'xx.xx'." >/dev/stderr
	exit 1
}

# ----------------------------------------------------------

docker container stop indexing-elasticsearch${TMP_IMGVER_STR}-cont
