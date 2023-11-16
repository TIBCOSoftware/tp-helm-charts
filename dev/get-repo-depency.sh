#!/bin/bash

#
# © 2023 Cloud Software Group, Inc.
# All Rights Reserved. Confidential & Proprietary.
#

CHART_NAME=${1}

[ -n "${CHART_NAME}" ] || { >&2 echo "ERROR: Please set CHART_NAME."; exit 1; }

pushd ../charts/${CHART_NAME} || exit

#yq -i eval 'del(.dependencies.[].repository)' Chart.yaml
#yq -i eval 'del(.dependencies.[].repository)' Chart.lock

helmDepUp () {
  path=$1
  (
    cd $path
    echo "Updating dependencies inside $path ..."
    if [ -f Chart.yaml ] ; then
        helm dep update
        if [ -d charts ]; then
          pushd charts
          ls *.tgz | xargs -n 1 tar -zxvf
          rm -rf *.tgz
          popd
        fi
    fi
    echo "... done."
    if [ -d charts ]; then
      for nextPath in $(find charts -mindepth 1 -maxdepth 1 -type d)
      do
        helmDepUp $(pwd)"/"$nextPath
      done
    fi
  )
}

#popd .. || exit

helmDepUp ${CHART_NAME}
