#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
# set -x
base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
export JOB_WAIT_TARGET_PATH="${JOB_WAIT_TARGET_PATH:-"300"}"
export TARGET_PATH="${TARGET_PATH:-"/private/tsc/config/capabilities"}"
export UI_PATH="${UI_PATH:-"/contributions/gems/web/apps"}"
export tmpPath="$TARGET_PATH/tmp.msgdp.$RANDOM"

whoami
id

function show_target_contributions {
    cat "$tmpPath/top.list" | while read x ; do
        echo "=== Top: $x ==="
        find "$TARGET_PATH/$x" -type f -ls
        find $TARGET_PATH/$x -name 'recipe.yaml' | xargs egrep -H ' version: '
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

function process_recipe_overrides {
    echo "Processing recipe overrides"
    cd $TARGET_PATH
    cat /boot/recipeOverrides | yq '. | keys' | cut -c3- | while read key  other ; do 
        echo "Found override for recipe: $key"
        cp $key $key.bk
        tmp=$(dirname $key)/tmp
        mkdir $tmp
        cat /boot/recipeOverrides | yq ".[\"$key\"]"  > $tmp/override.yaml
        cat $key | yq '.recipe.helmCharts.[0].values.[0].content' > $tmp/orig.yaml
        # Merge a new values
        yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)'  $tmp/orig.yaml $tmp/override.yaml | yq -P '.' > $tmp/update.yaml
        # Create an updated recipe
        cat $key | yq 'del(.recipe.helmCharts.[0].values)' > $tmp/new.yaml
        cat - <<! >> $tmp/new.yaml
      values:
        - content: |
!
        cat $tmp/update.yaml | sed -e 's/^/            /' >> $tmp/new.yaml
        auditsize=$( cat $tmp/new.yaml 2>/dev/null | wc -c )
        [ $auditsize -le 0 ]  && echo "Error computing updated recipe for $key, skipping" && return 1
        mv $tmp/new.yaml $key  
        rm -rf $tmp
        echo "#+: ==== Change Summary for $key ===="
        diff $key.bk $key || true
    done
    cd - >/dev/null 2>&1
}

trap debug_on_error ERR

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

echo "Starting Updates to $TARGET_PATH recipes"
mkdir -p "$tmpPath"
cd "$tmpPath" || exit 1
> top.list
for spec in /boot/spec.*.yaml ; do
    export top=$(cat $spec | yq -r '.top')
    echo "Processing recipes for $top"
    echo "$top" >> top.list
    [ -d "$TARGET_PATH/$top.old" ] && rm -rf "$TARGET_PATH/$top.old"
    # Unpack recipe packages
    for f in $(cat $spec | yq '.files | keys' | cut -c2- ) ; do 
        echo "#+: $f" 
        dir=$(dirname $f) 
        mkdir -p "$dir" 
        cat $spec |  yq '.files["'$f'"]' > $f 
    done
    # Get latest.json
    cat $top/versions.json | yq -P -o json  '.[0]' > $top/latest.json
    # be careful with root
    [ $(id -u) -eq 0 ] && chown -R 1000:1000 "$top"

    # Update via directory move
    echo "Updating $top"
    [ -e "$TARGET_PATH/$top" ] && mv $TARGET_PATH/$top $TARGET_PATH/$top.old 
    mv $top $TARGET_PATH/$top
done

size=$(cat /boot/recipeOverrides 2>/dev/null | wc -c )
if [ "$size" -gt 0 ] ; then
    process_recipe_overrides
fi

show_target_contributions
rm -rf "$tmpPath"
