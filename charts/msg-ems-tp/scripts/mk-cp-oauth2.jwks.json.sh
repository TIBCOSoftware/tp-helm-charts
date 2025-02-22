#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
echo "cmd=$cmd, base=$base"
usage="
$cmd -- Generate/Update EMS JWKS JSON file
"
outfile=${1:-cp-oauth2.jwks.json}

# FIXME: EMS-10.4.0.1 Workaround
#  echo "$EMS_CP_JWKS" | jq '.keys[] |= . + {"use": "sig"}'

if echo "$EMS_CP_JWKS" | grep -q "keys" ; then
    # Have full JWKS
    echo "$EMS_CP_JWKS" | jq '.' > $outfile
else
    # Single key, wrap for JWKS
    cat - <<! | jq '.' > $outfile
{"keys":[ $EMS_CP_JWKS ]}
!
fi

exit 0
