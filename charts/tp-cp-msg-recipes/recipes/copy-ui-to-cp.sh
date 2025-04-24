#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
set -x
base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
export CONTRIB_LIST="${CONTRIB_LIST:-"ems pulsar"}"
export TARGET_PATH="${TARGET_PATH:-"/private/tsc/config/capabilities/platform"}"
export UI_PATH="${UI_PATH:-"/contributions/gems/web/apps"}"
export STAGING_PATH="${STAGING_PATH:-/data}"
# export TARGET_PATH="${TARGET_PATH:-"/private/tsc/config/capabilities/platform"}"
export tmproot="$STAGING_PATH/tmp.$RANDOM"
export tmppkg="$tmproot/msgpkg"
export JOB_WAIT_TARGET_PATH="${JOB_WAIT_TARGET_PATH:-"300"}"
export JOB_POST_SLEEP="${JOB_POST_SLEEP:-"60"}"

whoami
id

function show_target_contributions {
    for cap in $CONTRIB_LIST ; do
        find "$TARGET_PATH/$cap" -type f -ls
    done
    set +x
    for cap in $CONTRIB_LIST ; do
        echo "=== UI Version: $cap ==="
        cat "$UI_PATH/$cap/version.txt"
        find $TARGET_PATH/$cap -name 'recipe.yaml' | xargs egrep -H ' version: '
    done
}

function debug_on_error {
    echo "Error: Collecting debug information."
    echo "df -h"
    df -h
    ls -la "$TARGET_PATH"
    ls -la $(dirname "$TARGET_PATH")
    show_target_contributions
}

trap debug_on_error ERR

mkdir -p "$tmppkg"
# Cleanup any old backups
for cap in $CONTRIB_LIST ; do
    old="$TARGET_PATH/$cap.old"
    [ -d "$old" ] && rm -rf "$old"
done
# COPY recipe packaging files
for x in /boot/* ; do
    inf="$x"
    outf="$(basename $x | tr 'X' '/' )"
    outd="$(dirname $outf)"
    [ "$outd" = '.' ] && continue
    echo "Staging pkgfile: $outf"
    mkdir -p $tmppkg/$outd
    cp $inf $tmppkg/$outf
done

# Wait until $TARGET_PATH exists
elapsed=0
while [ ! -d "$TARGET_PATH" ]; do
    if [ "$elapsed" -ge "$JOB_WAIT_TARGET_PATH" ]; then
        echo "Timeout waiting for $TARGET_PATH to exist"
        debug_on_error
        exit 1
    fi
    sleep 3
    elapsed=$((elapsed + 3))
done

# POST new PKG contributions
for x in $( /bin/ls -1 $tmppkg ) ; do 
    old="$TARGET_PATH/$cap.old"
    [ -e "$TARGET_PATH/$x" ]  && mv "$TARGET_PATH/$x" "$TARGET_PATH/$x.old"
    echo "Updating $x"
    mv "$tmppkg/$x" "$TARGET_PATH/$x"
done
rm -rf $tmproot

show_target_contributions

echo "sleeping $JOB_POST_SLEEP , before exit"
sleep $JOB_POST_SLEEP
