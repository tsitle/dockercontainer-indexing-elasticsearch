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

# Outputs CPU architecture string
#
# @param string $1 debian_rootfs|debian_dist
#
# @return int EXITCODE
function _getCpuArch() {
	case "$(uname -m)" in
		x86_64*)
			echo -n "amd64"
			;;
		aarch64*)
			if [ "$1" = "debian_rootfs" ]; then
				echo -n "arm64v8"
			elif [ "$1" = "debian_dist" ]; then
				echo -n "arm64"
			else
				echo "$VAR_MYNAME: Error: invalid arg '$1'" >/dev/stderr
				return 1
			fi
			;;
		armv7*)
			if [ "$1" = "debian_rootfs" ]; then
				echo -n "arm32v7"
			elif [ "$1" = "debian_dist" ]; then
				echo -n "armhf"
			else
				echo "$VAR_MYNAME: Error: invalid arg '$1'" >/dev/stderr
				return 1
			fi
			;;
		*)
			echo "$VAR_MYNAME: Error: Unknown CPU architecture '$(uname -m)'" >/dev/stderr
			return 1
			;;
	esac
	return 0
}

_getCpuArch debian_dist >/dev/null || exit 1

# ----------------------------------------------------------

function printUsageAndExit() {
	echo "Usage: $VAR_MYNAME VERSION" >/dev/stderr
	echo "Examples: $VAR_MYNAME 5.6" >/dev/stderr
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

function _checkVmMaxMapCount() {
	TMP_IS_MMC_OK=false
	TMP_MAXMAPCNT=""
	[ -f /etc/sysctl.conf ] && TMP_MAXMAPCNT="$(grep vm.max_map_count /etc/sysctl.conf)"
	TMP_MMC_MIN_M1=$(( 262144 - 1 ))
	if [ -z "$TMP_MAXMAPCNT" ]; then
		TMP_MAXMAPCNT="$(sysctl -n vm.max_map_count 2>/dev/null)"
	fi
	if [ -n "$TMP_MAXMAPCNT" ]; then
		TMP_MAXMAPCNT="$(echo -n "$TMP_MAXMAPCNT" | tr -d [:space:] | cut -f2 -d=)"
	fi
	if [ -n "$TMP_MAXMAPCNT" ]; then
		[ $TMP_MAXMAPCNT -gt $TMP_MMC_MIN_M1 ] && TMP_IS_MMC_OK=true
	fi
	if [ "$TMP_IS_MMC_OK" != "true" ]; then
		echo "Elasticsearch (5.6) requires vm.max_map_count >= 262144" >/dev/stderr
		echo "Use 'sudo sysctl -w vm.max_map_count=262144'" >/dev/stderr
		echo "or 'echo vm.max_map_count=262144 | sudo tee -a /etc/sysctl.conf'" >/dev/stderr
		exit 1
	fi
}

case "$OSTYPE" in
	linux*) _checkVmMaxMapCount ;;
	*) echo -n ;;
esac

# ----------------------------------------------------------

LCFG_ES_USER_ID=
LCFG_ES_GROUP_ID=

TMP_UID="$(id -u)"
TMP_GID="$(id -g)"
[ $TMP_UID -gt 499 ] && LCFG_ES_USER_ID=$TMP_UID
[ $TMP_GID -gt 100 ] && LCFG_ES_GROUP_ID=$TMP_GID

# ----------------------------------------------------------

TMP_IMG_VER_SHORT="$(echo -n "$OPT_IMG_VER" | cut -f1-2 -d.)"
TMP_IMGVER_STR="$(echo -n "$TMP_IMG_VER_SHORT" | tr -d .)"

echo -n "$TMP_IMG_VER_SHORT" | grep -q -E "[0-9]{1,2}[\.][0-9]{1,2}" || {
	echo "Invalid version. Must have format 'xx.xx'." >/dev/stderr
	exit 1
}

TMP_CONTNAME="indexing-elasticsearch${TMP_IMGVER_STR}-cont"

echo "Starting container '$TMP_CONTNAME' (TCP port 92${TMP_IMGVER_STR})..."

docker run \
		--rm \
		-d \
		-it \
		-v "$VAR_MYDIR/mpdata/$OPT_IMG_VER":"/usr/share/elasticsearch/data" \
		-p "92${TMP_IMGVER_STR}:9200" \
		-e "xpack.security.enabled=false" \
		-e "discovery.type=single-node" \
		-e "http.cors.enabled=true" \
		-e "http.cors.allow-origin=/.*/" \
		-e "http.cors.allow-headers=X-Requested-With,X-Auth-Token,Content-Type,Content-Length,Authorization" \
		-e "http.cors.allow-credentials=true" \
		-e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
		-e "CF_SYSUSR_ES_USER_ID=$LCFG_ES_USER_ID" \
		-e "CF_SYSUSR_ES_GROUP_ID=$LCFG_ES_GROUP_ID" \
		--name "$TMP_CONTNAME" \
		indexing-elasticsearch-$(_getCpuArch debian_dist):$OPT_IMG_VER
