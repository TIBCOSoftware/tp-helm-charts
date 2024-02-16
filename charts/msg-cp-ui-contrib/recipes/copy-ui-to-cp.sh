#!/bin/bash
# Copyright (c) 2023-2024 Cloud Software Group, Inc. All Rights Reserved. Confidential and Proprietary.
set -x
base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
export CONTRIB_LIST="${CONTRIB_LIST:-"ems pulsar"}"
export SOURCE_PATH="${SOURCE_PATH:-"/contributions"}"
export RECIPE_PATH="${RECIPE_PATH:-"/private/tsc/config/capabilities/platform"}"
export UI_PATH="${UI_PATH:-"/private/tsc/contributors"}"
# export TARGET_PATH="${TARGET_PATH:-"/private/tsc/config/capabilities/platform"}"
export tmptag="tmp.$RANDOM"
export tmproot="$(dirname $UI_PATH)/tmp.$RANDOM"
export tmpui="$tmproot/msgui"
export tmppkg="$tmproot/msgpkg"
export JOB_POST_SLEEP="${JOB_POST_SLEEP:-"180"}"
mkdir -p $tmppkg $tmpui
# Cleanup any old backups
for TARGET_PATH in $UI_PATH $RECIPE_PATH ; do
    for cap in $CONTRIB_LIST ; do
        old="$TARGET_PATH/$cap.old"
        [ -d "$old" ] && rm -rf "$old"
    done
done
# COPY UI Contributions
for cap in $CONTRIB_LIST ; do
    if [ -d "$SOURCE_PATH/$cap" ] ; then
        echo "Staging $cap"
        mkdir -p "$tmpui"
        cp -r "$SOURCE_PATH/$cap" "$tmpui/$cap"
    else
        echo "Skipping $cap - no source"
    fi
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
# POST new UI contributions
for x in $( /bin/ls -1 $tmpui ) ; do 
    old="$UI_PATH/$cap.old"
    [ -e "$UI_PATH/$x" ]  && mv "$UI_PATH/$x" "$UI_PATH/$x.old"
    echo "Updating $x"
    mv "$tmpui/$x" "$UI_PATH/$x"
done
# POST new PKG contributions
for x in $( /bin/ls -1 $tmppkg ) ; do 
    old="$RECIPE_PATH/$cap.old"
    [ -e "$RECIPE_PATH/$x" ]  && mv "$RECIPE_PATH/$x" "$RECIPE_PATH/$x.old"
    echo "Updating $x"
    mv "$tmppkg/$x" "$RECIPE_PATH/$x"
done
rm -rf $tmppkg
for TARGET_PATH in $UI_PATH $RECIPE_PATH ; do
    for cap in $CONTRIB_LIST ; do
        find "$TARGET_PATH/$cap" -type f -ls
    done
done
set +x
for cap in $CONTRIB_LIST ; do
    echo "=== UI Version: $cap ==="
    cat "$UI_PATH/$cap/version.txt"
done
echo "sleeping $JOB_POST_SLEEP , before exit"
sleep $JOB_POST_SLEEP
