#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

# THIS FILES IS EXPECTED TO BE SOURCED USING BASH SHELL
ls -lh /cm/*

export ENV_TYPE="${ENV_TYPE:-""}"
echo "ENV_TYPE: $ENV_TYPE"

# Env values needed
requiredEnv=()
requiredEnv+=("ACME_HOST")
requiredEnv+=("PERMISSIONS_ENGINE_HOST")

# cp-env or cic-env env values are already loaded in the environment

#
# Handle dnsdomains CM ENV
#
echo "Loading dnsdomains CM values"
cmDnsList="/cm/cp-dns /cm/cic-dns"
expectedCmDns=""
if [ "$ENV_TYPE" = "onprem" ]; then
    expectedCmDns="/cm/cp-dns"
elif [ "$ENV_TYPE" = "saas" ]; then
    expectedCmDns="/cm/cic-dns"
else
    expectedCmDns="Unknown"
fi
echo "Expected DNS CM: $expectedCmDns"

# GET DNS CM DATA
requiredKeys+=()
requiredKeys+=("TSC_ADMIN_DNS_DOMAIN")
requiredKeys+=("TP_CP_PERMISSIONS_ENGINE_HOST")
envKeys=()
envKeys+=("${requiredKeys[@]}")
envKeys+=("TSC_DNS_DOMAIN")

for try in $(seq 10) ; do 
    for cm in $cmDnsList ; do 
        for key in "${envKeys[@]}" ; do 
            if [ -f $cm/$key ] ; then 
                value=$(cat $cm/$key )
                export $key=$value
                echo "Setting $key=$value from $cm"
            fi
        done
    done

    # CHECK REQUIRED KEYS
    missing=
    for key in "${requiredKeys[@]}" ; do 
        if [ -z "${!key}" ] ; then 
            echo "ERROR: Required key $key is not set"
            missing=yes
        fi
    done
    if [ -n "$missing" ] ; then 
        echo "Waiting for dnsdomains CM to appear ..."
        sleep 10
    fi
done

# Convert DNS ENV to expected values
if [ -n "$TSC_ADMIN_DNS_DOMAIN" ]; then
    export ACME_HOST="$TSC_ADMIN_DNS_DOMAIN"
fi
if [ -n "$TP_CP_PERMISSIONS_ENGINE_HOST" ]; then
    export PERMISSIONS_ENGINE_HOST="$TP_CP_PERMISSIONS_ENGINE_HOST"
fi


#
# Handle cp-extra CM ENV overrides
#
cmextra="/cm/cp-extra"
if [ -n "$(ls $cmextra)" ]; then
    echo "Loading cp-extra CM values"
    for file in $cmextra/* ; do 
        key=$(basename $file)
        value=$(cat $file)
        export $key=$value
        echo "Setting $key=$value"
    done
fi


# CHECK REQUIRED ENV
missing=
for key in "${requiredEnv[@]}" ; do 
    if [ -z "${!key}" ] ; then 
        echo "ERROR: Required key $key is not set"
        missing=yes
    fi
done

env | sort 

if [ -n "$missing" ] ; then 
    echo "ERROR: Required keys not set, continuing ..."
fi
