# Copyright (c) 2023-2025 Cloud Software Group, Inc. All Rights Reserved. Confidential and Proprietary.
#
#=== 12: Platform Helpers
#
# DO NOT OVERRIDE THESE IF SET
# export myCPHOST="${myCPHOST:-https://$ACME_HOST}"
export myDataplane="${myDataplane:-$MY_DATAPLANE}"
export myDPCPHOST="http://cp-proxy.$MY_NAMESPACE.svc.cluster.local:80"
# export dpNperf01='ct7abgn5q0aqplclk9qg'
# export dpNperf15='csdbgskastra07an6t0g'
# export myCicToken='CIC~xxxx'

# FIXME: DELETE-ME - DO NOT CHECK-IN, add test tokens here
######
thisFile="${BASH_SOURCE[0]}"
pltFunctionsUsage="
Example methods for common MSGDP integration APIs

first export $myCicToken and $myDataplane when using in Control Plane

=== Topics:

+ CP-auth info (set $myCicToken first)
getJWT
getJWKS
getClaims
getSubscriptionId
getUser
getDPRawConfig

+ BMDP Resource Instance DB
getResources
getCPresources
getCPmsgServers
getDpDetails
getDpRegion
postCPresource
getCpRsrcByName
getCpRsrcByRiid
delCPresource
putPayload
putCPresource

+ Hawk Console
getHawkToken
hawkMHealth
hawkAbout
hawkRegister
hawkUnregister
hawkEHealth

+ EMS restd 
restdSendCmd
restdConnectByName
restdConnectByTag
restdDisconnect
restdServer
restdCommand
restdProxyList
restdHealth

+ Favorites
getCPmsgServers (CP only)
getCpRsrcByName
hawkEHealth
restdProxyList
restdHealth
"


alias ks='kubectl '
alias ksg='kubectl get -o wide '
alias ksgy='kubectl get -o yaml '
alias ksd='kubectl describe '
function ksx { kubectl exec  -ti ${1:?"podname required"} -- bash ; }

# Setup standard Curl options
export cOpts=()
cOpts+=(-Ss)
cOpts+=(--location)
cOpts+=(--header)
cOpts+=('Content-Type: application/json')
cOpts+=(--max-time)
cOpts+=(5)
cOpts+=(--connect-timeout)
cOpts+=(3)
cOpts+=(-k)

function require {
    # Do not overwrite callers usage message
    # usage="require <var ...> -- Check for required variables"
    for x in "$@"; do
        [ -z "${!x}" ] && echo "$usage" && echo "Missing required setting: \$$x" && return 1
    done
    return 0
}

## Ubuntu preferred: 
export REGISTER_DEBUG_LOG="${REGISTER_DEBUG_LOG:-/logs/tmp.plt-functions.log}"
fmtTime="--rfc-3339=ns"
function log
{ echo "$(date "$fmtTime"): $*" >> $REGISTER_DEBUG_LOG ; }

function myBearer {
    export myBearer="Authorization: Bearer $myCicToken"
    echo "$myBearer"
}

function ctBasicAuth {
    [ -n "$ctBasicAuth" ] && echo "$ctBasicAuth" && return 0
    if [ -n "$EMS_ADMIN_USER" ] ; then
        export ctBasicAuth="$EMS_ADMIN_USER:$EMS_ADMIN_PASSWORD"
    elif [ -n "$DP_ADMIN_USER" ] ; then
        export ctBasicAuth="$DP_ADMIN_USER:$DP_ADMIN_PASSWORD"
    else
        # Try to fetch from CT
        # export ctBasicAuth="$EMS_ADMIN_USER:$EMS_ADMIN_PASSWORD"
        echo "Fetch from CT not implemented yet"
        echo "Work-around: export ctBasicAuth=\"<user>:<password>\""
    fi
    echo -n "$ctBasicAuth"
}

function cpWebHost {
    [ -z "$TP_CP_WEB_SERVER_HOST" ] && \
        echo >&2 "No TP_CP_WEB_SERVER_HOST found, asking kubectl ..." && \
        export TP_CP_WEB_SERVER_HOST="$(kubectl get cm/tp-cp-core-dnsdomains -o=jsonpath='{.data.TP_CP_WEB_SERVER_HOST}' )"
    [ -z "$TP_CP_WEB_SERVER_SERVICE_PORT" ] && export TP_CP_WEB_SERVER_SERVICE_PORT=3000
    export cpWebHost="http://$TP_CP_WEB_SERVER_HOST:$TP_CP_WEB_SERVER_SERVICE_PORT/tp-cp-ws"
    echo "$cpWebHost"
}

function getJWT {
    # From OUTSIDE CP 
    usage=" getJWT <cpHostUrl> <cicToken>"
    [ -n "$1" ] && myCPHOST="$1"
    [ -n "$2" ] && myCicToken="$2"
    # FIXME: Need more reliable subscription host subdomain
    SUB_HOST=${ACME_HOST/admin./dev.}
    myCPHOST=${myCPHOST:-https://$SUB_HOST}
    myCicToken=${myCicToken:?"$usage -- myCicToken required."}
    myBearer="Authorization: Bearer $myCicToken"
    body=$(printf '{"tenant_id":"TSC","token":"%s"}' "$myCicToken")
    echo >&2 "#+: " curl ' "${cOpts[@]}" ' "$myCPHOST/idm/v1/oauth2/jwt" '-H "$myBearer" -d "$body" '
    response=$( curl "${cOpts[@]}" "$myCPHOST/idm/v1/oauth2/jwt" -H "$myBearer" -d "$body" )
    echo "$response" | jq -r '.jwt'
}

function getJWKS {
    # FROM CT Pod
    if [ -n "$MY_DATAPLANE" ] ; then
        myCPHOST="http://cp-proxy.$MY_NAMESPACE.svc.cluster.local:80"
        echo >&2 "#+: " curl -i "${cOpts[@]}" "$myCPHOST/idm/v1/oauth2/jwks-uri" 
        curl -i "${cOpts[@]}" "$myCPHOST/idm/v1/oauth2/jwks-uri"  | tee curl.out >&2
        echo >&2 ; echo >&2 ===
        tail -1 curl.out | jq '.'
    else
        # From OUTSIDE CP 
        usage=" getJWT <cpHostUrl> <cicToken>"
        [ -n "$1" ] && myCPHOST="$1"
        [ -n "$2" ] && myCicToken="$2"
        myCPHOST=${myCPHOST:?$usage}
        myCicToken=${myCicToken:?$usage}
        myBearer="Authorization: Bearer $myCicToken"
        # body=$(printf '{"tenant_id":"TSC","token":"%s"}' "$myCicToken")
        echo >&2 "#+: " curl -i "${cOpts[@]}" "$myCPHOST/idm/v1/oauth2/jwks-uri" '-H "$myBearer" '
        curl -i "${cOpts[@]}" "$myCPHOST/idm/v1/oauth2/jwks-uri" -H "$myBearer" | tee curl.out >&2
        echo >&2 ; echo >&2 ===
        tail -1 curl.out | jq '.'
    fi
}

function getClaims {
    usage=" getClaims [jwt]  -- Extract claims from JWT"
    [ -n "$1" ] && myJWT="$1"
    [ -z "$myJWT" ] && export myJWT=$(getJWT)
    [ -z "$myJWT" ] && echo "No JWT found." && return 1
    echo "$myJWT" | cut -d'.' -f2 | base64 -d | jq '.'
}

function getSubscriptionId {
    usage=" getSubscriptionId [jwt]  -- Extract claims from JWT"
    [ -n "$1" ] && myJWT="$1"
    [ -z "$myJWT" ] && export myJWT=$(getJWT)
    [ -z "$myJWT" ] && echo "No JWT found." && return 1
    echo "$myJWT" | cut -d'.' -f2 | base64 -d | jq -r '.gsbc'
}

function getUser {
    usage=" getUser [jwt]  -- Extract claims from JWT"
    [ -n "$1" ] && myJWT="$1"
    [ -z "$myJWT" ] && export myJWT=$(getJWT)
    [ -z "$myJWT" ] && echo "No JWT found." && return 1
    echo "$myJWT" | cut -d'.' -f2 | base64 -d | jq -r '.email'
}

function getDPRawConfig {
    usage=" getDPRawConfig [\$myDataplane] -- Extract raw config for DP"
    [ -n "$1" ] && myDataplane="$1"
    [ -z "$myJWT" ] && export myJWT=$(getJWT)
    [ -z "$myJWT" ] && echo "No JWT found." && return 1
    mySub=$(getSubscriptionId)
    myUser=$(getUser)
    hUser="X-atmosphere-For-User: $myUser"
    subSVC="http://tp-cp-user-subscriptions.cp1-ns.svc.cluster.local:8832"
    dpConfigApi="v1/utm/tables/v3_data_planes"
    filterSub='$filter=subscription_id.eq.'"$mySub"
    filterDP='$filter=dp_id.eq.'"$myDataplane"
    ###curl -H "X-atmosphere-For-User: dmiller@tibco.com" -i "http://tp-cp-user-subscriptions.cp1-ns.svc.cluster.local:8832/v1/utm/tables/v3_data_planes?\$filter=subscription_id.eq.$mySub&\$filter=dp_id.eq.$myDataplane" | tail -1 | jq '.'
    echo >&2 '#+: ' curl "${cOpts[@]}" -i -H "$hUser" -i "$subSVC/$dpConfigApi?${filterSub}&${filterDP}" 
    curl "${cOpts[@]}" -i -H "$hUser" "$subSVC/$dpConfigApi?${filterSub}&${filterDP}" > curl.out
    echo >&2 === 
    head >&2 -1 curl.out 
    echo >&2 === 
    tail -1 curl.out | jq '.' | tee curl.json
    # cat curl.json | jq -r '.data[0].dp_config.k8sDPConfig."--ct-auth-token"' | base64 -d ; echo
}

function cpSetup {
    export myBearer=$(myBearer)
    export cpWebHost=$(cpWebHost)
    export myJWT=$(getJWT)
    export myXatom="X-Atmosphere-Token: $myJWT"
    # orchHostname="$(kubectl get cm/tp-cp-core-dnsdomains -o=jsonpath='{.data.TP_CP_ORCH_HOST}' )"
    # export orchHostUrl="http://$orchHostname:7833"
    # export myCPHOST="$orchHostUrl"
}

function cpDesktop {
    export cpOutside=y
    export myBearer=$(myBearer)
    # export myCPHOST="https://dev.dev-my.msgdp-dev.maas-dev.dataplanes.pro"
    export myJWT=$(getJWT)
}

function getResources {
    # INSIDE CP Pods
    usage='getResources [$myDataplane] '
    [ -n "$1" ] && myDataplane="$1"
    cpWebHost=$(cpWebHost)
    myJWT=$(getJWT)
    require myDataplane myJWT cpWebHost || return 1
    export myXatom="X-Atmosphere-Token: $myJWT"
    qScope="scope=DATAPLANE&scopeId=$myDataplane"
    qLevel="resourceLevel=PLATFORM"
    echo >&2 '#+:curl -H "$myXatom" -i -sS "'"$cpWebHost/v1/resource-instances-details?${qScope}&${qLevel}" 
    curl -H "$myXatom" -i -sS "$cpWebHost/v1/resource-instances-details?${qScope}&${qLevel}" > curl.out 
    echo >&2 === 
    head >&2 -1 curl.out 
    echo >&2 === 
    tail -1 curl.out | jq '.' | tee  curl.json 
}

function getCPresources {
    # INSIDE CP Pods
    usage='getCPresources [$myDataplane] '
    [ -n "$1" ] && myDataplane="$1"
    cpWebHost=$(cpWebHost)
    myJWT=$(getJWT)
    require myDataplane myJWT cpWebHost || return 1
    getResources | egrep 'resource_id":|resource_instance_id":' curl.json | paste - - 
}

function getCPmsgServers {
    usage='getCPmsgServers [$myDataplane] '
    [ -n "$1" ] && myDataplane="$1"
    cpWebHost=$(cpWebHost)
    myJWT=$(getJWT)
    require myDataplane myJWT cpWebHost || return 1
    export myXatom="X-Atmosphere-Token: $myJWT"
    qScope="scope=DATAPLANE&scopeId=$myDataplane"
    qLevel="resourceLevel=PLATFORM"
    qMsg="resourceId=MSGSERVER"
    echo '#+:curl -H "$myXatom" -i -sS "'"$cpWebHost/v1/resource-instances-details?${qScope}&${qLevel}&${qMsg}"'"' 
    curl -H "$myXatom" -i -sS "$cpWebHost/v1/resource-instances-details?${qScope}&${qLevel}&${qMsg}" > curl.out 
    echo >&2 === 
    head -1 curl.out >&2
    echo >&2 === 
    tail -1 curl.out | jq '.' > curl.json 
    egrep 'resource_id":|resource_instance_name":|resource_instance_id":' curl.json | tr -d '\t ' | paste - - -
}

function getDpDetails {
    api="v1/data-plane-details"
    # Outside version
    if [ -n "$cpOutside" ]; then
        usage='getCPmsgServers [$myDataplane] [$myCPHOST]'
        [ -n "$1" ] && myDataplane="$1"
        [ -n "$2" ] && myCPHOST="$2"
        [ -n "$3" ] && myJWT="$3"
        myDataplane=${myDataplane:?"$usage"}
        myCPHOST=${myCPHOST:?"$usage"}
        myJWT=$(getJWT)
        myBearer="Authorization: Bearer $myCicToken"
        echo >&2 '#+: curl -H "$myBearer" -i -sS "'"${myCPHOST}/cp/${api}/$myDataplane"'"'
        curl -H "$myBearer" -i -sS "${myCPHOST}/cp/${api}/$myDataplane" > curl.out 
    else
        usage='getCPmsgServers [$myDataplane] [$cpWebHost] [$myJWT]'
        [ -n "$1" ] && myDataplane="$1"
        [ -n "$2" ] && cpWebHost="$2"
        [ -n "$3" ] && myJWT="$3"
        myDataplane=${myDataplane:?"$usage"}
        cpWebHost=${cpWebHost:?"$usage"}
        myJWT=${myJWT:?"$usage"}
        export myXatom="X-Atmosphere-Token: $myJWT"
        echo >&2 '#+: curl -H "$myXatom" -i -sS "'"$cpWebHost/${api}/$myDataplane"'"'
        curl -H "$myXatom" -i -sS "$cpWebHost/${api}/$myDataplane" > curl.out
    fi
    echo >&2 === 
    head >&2 -1 curl.out 
    echo >&2 === 
    tail -1 curl.out | jq '.' | tee curl.json
}

function getDpRegion {
    usage='getDpRegion [$myDataplane] [$cpWebHost] [$myJWT]'
    [ -n "$1" ] && myDataplane="$1"
    [ -n "$2" ] && cpWebHost="$2"
    [ -n "$3" ] && myJWT="$3"
    require myDataplane cpWebHost myJWT || return 1
    export myXatom="X-Atmosphere-Token: $myJWT"
    api="v1/data-plane-details"
    # Outside version
    # myBearer="Authorization: Bearer $myCicToken"
    # curl -H "$myBearer" -i -sS "${myCPHOST}/tp-cp-ws/${api}/$myDataplane" > curl.out 
    echo >&2 '#+: curl -H "$myXatom" -i -sS "'"$cpWebHost/${api}/$myDataplane"'"'
    curl -H "$myXatom" -i -sS "$cpWebHost/${api}/$myDataplane" > curl.out
    echo >&2 === 
    head >&2 -1 curl.out 
    echo >&2 === 
    # tail -1 curl.out | jq -r '.data[0].running_region'
    tail -1 curl.out | jq -r '.data[0].registered_region'
}

function genCpEmsPayload {
    usage='genCpEmsPayload <json|serverName> [$myDataplane]'
    server=${1:-ems-ft}
    [ -n "$2" ] && myDataplane="$2"
    region=$(getDpRegion)
    require server myDataplane region || return 1
if [ -f "$server" ] ; then
    cat "$server" > server.json
    serverName="$(jq < server.json -r '.groupName')"
else
    serverName="$server"
    cat - <<EOF > server.json
        {
            "groupName": "$serverName",
            "groupType": "ems",
            "description": "dev EMS FT pair",
            "emsStyle": "FT",
            "clientUrl": "tcp://nperf14.na.tibco.com:9103,tcp://nperf14.na.tibco.com:9105",
            "monitorUrl": "http://nperf14.na.tibco.com:9104,http://nperf14.na.tibco.com:9106",
            "dataplaneId": "dp-123",
            "resourceInstanceId": "res-ems-123",
            "registrationUser": "admin",
            "clientMtls": {},
            "monitorMtls": {}
        }
EOF
fi
serverJson="$(cat server.json)"
cat - <<EOF | tee payload.json
{
    "resourceId": "MSGSERVER",
    "payload": {
        "description": "$description",
        "region": "$region",
        "resourceInstanceMetadata": {
            "fields": [
                $serverJson
            ]
        },
        "resourceInstanceName": "$serverName",
        "resourceLevel": "PLATFORM",
        "scope": "DATAPLANE",
        "scopeId": "$myDataplane"
    }
}
EOF
}

function postCPresource {
    usage='postCPresource [server-json-file] [$myDataplane] [$cpWebHost] [$myJWT]'
    [ -n "$1" ] && serverJson="$1"
    [ -n "$2" ] && myDataplane="$2"
    [ -n "$3" ] && cpWebHost="$3"
    [ -n "$4" ] && myJWT="$4"
    serverJson=${serverJson:-"ems-ft"}
    myDataplane=${myDataplane:?"$usage"}
    cpWebHost=${cpWebHost:?"$usage"}
    myJWT=${myJWT:?"$usage"}
    export myXatom="X-Atmosphere-Token: $myJWT"
    noPass='del(.payload.resourceInstanceMetadata.fields[].registrationPass)'
    payload="$(genCpEmsPayload "$serverJson" "$myDataplane" | jq "$noPass" )"

    hJson='Content-Type: application/json'
    api="v1/resource-instances"
    # Inside version
    echo >&2 '#+inside: curl -H "$myXatom" -H "$hJson" -i -sS -X POST "'"${cpWebHost}/${api}"'" -d "$payload"'
    curl -H "$myXatom" -H "$hJson" -i -sS -X POST "${cpWebHost}/${api}" -d "$payload" > curl.out
    # OUTSIDE version
    myBearer="Authorization: Bearer $myCicToken"
    # echo >&2 '#+outside: curl -H "$myBearer" -H "$hJson" -i -sS -X POST "'"${myCPHOST}/cp/${api}"'" -d "$payload"'
    # curl -H "$myBearer" -H "$hJson" -i -sS -X POST "${myCPHOST}/cp/${api}" -d "$payload" > curl.out
    rtc=$?
    echo >&2 === 
    head >&2 -1 curl.out 
    echo >&2 === 
    # cat curl.out ; echo
    [ $rtc -eq 0 ] && echo "$( tail -1 curl.out | jq -r '.resource_instance_id' )"
}

function getCpRsrcByName {
    usage="getCpRsrcByname <resourceName> [$myDataplane] [$cpWebHost] [$myJWT]"
    resourceName="${1:?"$usage   , no resourceName"}"
    [ -n "$2" ] && myDataplane="$2"
    [ -n "$3" ] && cpWebHost="$3"
    [ -n "$4" ] && myJWT="$4"
    getResources | jq '.data[]|select(.resource_instance_name=="'$resourceName'")'
}

function getCpRsrcByRiid {
    usage="getCpRsrcByRiid <resourceName> [$myDataplane] [$cpWebHost] [$myJWT]"
    riid="${1:?"$usage   , no riid"}"
    [ -n "$2" ] && myDataplane="$2"
    [ -n "$3" ] && cpWebHost="$3"
    [ -n "$4" ] && myJWT="$4"
    getResources | jq '.data[]|select(.resource_instance_id=="'$riid'")'
}

function delCPresource {
    usage='delCPresource <resourceInstanceId> [$myDataplane] [$cpWebHost] [$myJWT]'
    resourceInstanceId="${1:?"$usage   , no resourceInstanceId"}"
    [ -n "$2" ] && myDataplane="$2"
    [ -n "$3" ] && cpWebHost="$3"
    [ -n "$4" ] && myJWT="$4"
    myDataplane=${myDataplane:?"$usage"}
    cpWebHost=${cpWebHost:?"$usage"}
    myJWT=${myJWT:?"$usage"}
    export myXatom="X-Atmosphere-Token: $myJWT"
    myBearer="Authorization: Bearer $myCicToken"
    hJson='Content-Type: application/json'
    qScope="scope=DATAPLANE&scopeId=$myDataplane"
    api="v1/resource-instances?${qScope}&resourceInstanceId=$resourceInstanceId"
    # Inside version
    echo >&2 '#+inside: ' 'curl -H "$myXatom" -H "$hJson" -i -sS -X POST "'"${cpWebHost}/${api}" 
    curl -H "$myXatom" -H "$hJson" -i -sS -X DELETE "${cpWebHost}/${api}" > curl.out
    # OUTSIDE version
    # echo >&2 '#+outside: curl -H "$myBearer" -H "$hJson" -i -sS -X POST "'"${myCPHOST}/cp/${api}"'" -d "$payload"'
    # curl -H "$myBearer" -H "$hJson" -i -sS -X POST "${myCPHOST}/cp/${api}" -d "$payload" > curl.out
    rtc=$?
    echo >&2 === 
    head >&2 -1 curl.out 
    echo >&2 === 
    cat curl.out ; echo
}

function putPayload {
    usage='putPayload <lookup-json>'
    lookup=${1:?"$usage"}
    echo "$lookup" > lookup.json
    scope=DATAPLANE
    scopeId=$(echo "$lookup" | jq -r '.scope_id')
    resourceInstanceId=$(echo "$lookup" | jq -r '.resource_instance_id')
    resourceInstanceName=$(echo "$lookup" | jq -r '.resource_instance_name')
    resourceInstanceDescription=$(echo "$lookup" | jq -r '.resource_instance_description')
    serverData=$(echo "$lookup" | jq -r '.resource_instance_metadata.fields[0]')
    cat - <<EOF | tee put-payload.json
    {
        "scope": "$scope",
        "scopeId": "$scopeId",
        "resourceInstanceId": "$resourceInstanceId",
        "resourceInstanceName": "$resourceInstanceName",
        "resourceInstanceDescription": "$resourceInstanceDescription - updated",
        "resourceInstanceMetadata": {
            "fields": [
                $serverData
            ]
        }
    }
EOF
}

function putCPresource {
    usage='putCPresource [server-json-file|name] [$myDataplane] [$cpWebHost] [$myJWT]'
    [ -n "$1" ] && serverJson="$1"
    [ -n "$2" ] && myDataplane="$2"
    [ -n "$3" ] && cpWebHost="$3"
    [ -n "$4" ] && myJWT="$4"
    serverJson=${serverJson:-"ems-ft"}
    myDataplane=${myDataplane:?"$usage"}
    cpWebHost=${cpWebHost:?"$usage"}
    myJWT=${myJWT:?"$usage"}
    export myXatom="X-Atmosphere-Token: $myJWT"

    if [ -f "$server" ] ; then
        serverJson="$(cat "$server" )"
        serverName="$( jq < "$server" -r '.groupName')"
        lookup="$(getCpRsrcByName "$serverName" | jq '.' )"
    else
        lookup="$(getCpRsrcByName "$serverJson" | jq '.' )"
    fi
    resourceInstanceId="$( echo "$lookup" | jq -r '.resource_instance_id' )"
    hJson='Content-Type: application/json'
    qScope="scope=DATAPLANE&scopeId=$myDataplane"
    qRiid="resourceInstanceId=$resourceInstanceId"
    api="v1/resource-instances"
    # Inside version
    echo >&2 '#+: curl -H "$myXatom" ' -H "$hJson" -i -sS -X PUT "${cpWebHost}/${api}?${qScope}&${qRiid}" ' -d "$(putPayload "$lookup" )" '
    curl -H "$myXatom" -H "$hJson" -i -sS -X PUT "${cpWebHost}/${api}?${qScope}&${qRiid}" -d "$(putPayload "$lookup" )" > curl.out
    rtc=$?
    echo >&2 === 
    head >&2 -1 curl.out 
    echo >&2 === 
    [ $rtc -eq 0 ] && tail -1 curl.out && echo
}


function hawkHP {
    # Connection to tp-dp-hawk-console-connect (10.1.5.160) 9687 port [tcp/*] succeeded!
    hawkHost=${1:-tp-dp-hawk-console-connect}
    hawkPort=${2:-9687}
    export hawkHP="$hawkHost:$hawkPort"
    # export hawkHP="10.97.130.111:9687"
    echo "$hawkHP"
}
function hawkCTPath {
    [ -z "$myDataplane" ] && echo >&2 "No myDataplane set." && return 1
    export hawkCurlOpts
    [ -n "$hawkCTPath" ] && echo "$hawkCTPath" && return 0
    hawkCurlOpts+=("-k")
    hawkCurlOpts+=("--header")
    hawkCurlOpts+=("Host: dp-${myDataplane}.platform.local")
    hawkCurlOpts+=("--header")
    hawkCurlOpts+=("Content-Type: application/json")
    if [ -n "$EMS_ADMIN_USER" ] ; then
        # DP path
        # export hawkCTPath="http://localhost:9687"
        export hawkCTPath="https://$(hawkHP)"
    else
        # FIXME
        export hawkCTPath="http://dp-$myDataplane.$MY_NAMESPACE.svc.cluster.local:80/tibco/agent/infra"
    fi
    echo "$hawkCTPath"
}
hawkCurlOpts=()
function hawkStdOpts {
    [ -z "$myDataplane" ] && echo >&2 "No myDataplane set." && return 1
    export hawkCurlOpts=()
    hawkCurlOpts+=("-i")
    hawkCurlOpts+=("-Ss")
    hawkCurlOpts+=("-k")
    hawkCurlOpts+=("--header")
    hawkCurlOpts+=("Host: dp-${myDataplane}.platform.local")
    hawkCurlOpts+=("--header")
    hawkCurlOpts+=("Content-Type: application/json")
}

function hawkLiveness {
    usage='hawkLiveness'
    hawkCTPath=$(hawkCTPath)
    hawkStdOpts
    api="hawkconsole/about"
    echo >&2 '#+: curl -i "${hawkCurlOpts[@]}" ' -X GET  "${hawkCTPath}/$api" '| tee curl.out' 
    curl -i "${hawkCurlOpts[@]}" -X GET  "${hawkCTPath}/$api" | tee curl.out >&2
    echo >&2 ; echo >&2 ===
    tail -1 curl.out | jq '.'
}

#
# CT Restd functions
#

function restdCTPath {
    [ -n "$restdCTPath" ] && echo "$restdCTPath" && return 0
    if [ -n "$EMS_ADMIN_USER" ] ; then
        export restdCTPath="http://localhost:9014"
    else
        # export restdCTPath="http://dp-$myDataplane.$MY_NAMESPACE.svc.cluster.local/tibco/agent/msg/bmdp/restd"
        export restdCTPath="http://dp-$myDataplane.$MY_NAMESPACE.svc.cluster.local/tibco/agent/msg/ct/restd"
    fi
    echo "$restdCTPath"
}

export restdCurlOpts=()
function restdSetStdOptions {
  cookies="tmp.restd.cookies.txt"
  export restdCurlOpts=()
  restdCurlOpts+=("-i")    # :DEBUG:
  restdCurlOpts+=("-c")
  restdCurlOpts+=("$cookies")
  restdCurlOpts+=("-b")
  restdCurlOpts+=("$cookies")
  restdCurlOpts+=("--header")
  restdCurlOpts+=("Host: dp-${myDataplane}.platform.local")
  restdCurlOpts+=("--header")
  restdCurlOpts+=("Content-Type: application/json")
  restdCurlOpts+=(--max-time)
  restdCurlOpts+=(5)
  restdCurlOpts+=(--connect-timeout)
  restdCurlOpts+=(3)
  restdCurlOpts+=("-u")
  restdCurlOpts+=("$(ctBasicAuth)")
}

function restdSendCmd {
    apiPath="${1:?"API path required."}"
    action="${2:-GET}"
    data=$3
    restdUrl="$(restdCTPath)"
    restdSetStdOptions
    echo >&2 '#+: curl -i "${restdCurlOpts[@]}" ' -X "$action"  "${restdUrl}${apiPath}" '| tee curl.out' 
    curl -i "${restdCurlOpts[@]}" -X "$action"  "${restdUrl}${apiPath}" | tee curl.out >&2
    echo >&2 ; echo >&2 ===
    tail -1 curl.out | jq '.'
  return $rtc
}

function emsGetSampleCerts {
    export certDir="/data/hawk/emscerts"
    [ ! -d "$certDir" ] && echo >&2 "Missing: $certDir" && return 1
    sampleCerts="/opt/tibco/ems/current-version/samples/certs"
    cp -r "$sampleCerts"/* "$certDir/"
    echo >&2 "Copied sample certs to $certDir"
}

function emsRestdPath {
    usage="emsRestdPath [\$myInstance] -- Get EMS Restd path"
    [ -n "$emsRestdPath" ] && echo "$emsRestdPath" && return 0
    if [ -n "$EMS_ADMIN_USER" ] ; then
        export emsRestdPath="http://localhost:9014"
    else
        export emsRestdPath="http://dp-$myDataplane.$MY_NAMESPACE.svc.cluster.local/tibco/agent/msg/ems/$myInstance/rest"
    fi
    echo "$emsRestdPath"
}

function emsRestdCmd {
    apiPath="${1:?"API path required."}"
    action="${2:-GET}"
    data=$3
    restdUrl="$(emsRestdPath)"
    restdSetStdOptions
    echo >&2 '#+: curl -i "${restdCurlOpts[@]}" ' -X "$action"  "${restdUrl}${apiPath}" '| tee curl.out' 
    curl -i "${restdCurlOpts[@]}" -X "$action"  "${restdUrl}${apiPath}" | tee curl.out >&2
    echo >&2 ; echo >&2 ===
    tail -1 curl.out | jq '.'
  return $rtc
}

function emsRestdConnect {
    usage='emsRestdConnect '
    restdSetStdOptions
    emsRestdCmd  "/connect" "POST"
}

function emsRestdDisconnect {
    # NOTE: No error-list returned.
    emsRestdCmd  "/disconnect" "POST"
}

function emsRestdServer {
    usage='emsRestdServer'
    restdSetStdOptions
    emsRestdConnect
    emsRestdCmd  "/server" "GET"
}

function emsRestdProxyList {
    usage='emsRestdProxyList '
    emsRestdCmd  "/proxy/servers" 
}


function restdConnectByName {
    usage='restdConnectByName <serverName> '
    groupName=${1:?"$usage"}
    restdSetStdOptions
    # DEBUG: sgParam="server_groups=$groupName&server_tags=active"
    # sgParam="server_groups=$groupName&server_role=primary"
    sgParam="server_groups=$groupName"
    restdSendCmd  "/connect?$sgParam" "POST"
}

function restdConnectByTag {
    usage='restdConnectByTag <serverName> '
    tag=${1:?"$usage"}
    restdSetStdOptions
    sgParam="server_group_tags=$tag"
    # DEBUG: sgParam="server_group_tags=$tag&server_role=primary"
    restdSendCmd  "/connect?$sgParam" "POST"
}

function restdDisconnect {
    # NOTE: No error-list returned.
    restdSendCmd  "/disconnect" "POST"
}

function restdServer {
    usage='restdServer <groupName> '
    groupName=${1:?"$usage"}
    require groupName || return 1
    restdSetStdOptions
    restdConnectByTag "$groupName"
    restdSendCmd  "/server" "GET"
    # restdDisconnect
}

function restdCommand {
    # Assume connection cookie is set
    usage='restdCommand <apiPath> '
    api=${1:?"$usage"}
    [ -n "$2" ] && action="$2" || action="GET"
    data=$3
    if [ -n "$data" ] ; then
        restdSendCmd  "$api" "$action" "$data" 
    else
        restdSendCmd  "$api" "$action" 
    fi
}

function restdProxyList {
    usage='restdProxyList '
    restdSendCmd  "/proxy/servers" 
}

function restdHealth {
    usage='restdProxyList '
    restdSendCmd  "/health" 
}

#
# Hawk integration testing functions
#

function getHawkBasicAuth {
    if [ -n "$hawkToken" ] ; then
        echo -n "$hawkToken" | base64 -d
        return 0
    fi
    # CP side only
    usage=" getHawkBasicAuth [\$myDataplane] -- Extract hawk user:pw from raw config for DP"
    [ -n "$1" ] && myDataplane="$1"
    [ -z "$myJWT" ] && export myJWT=$(getJWT)
    [ -z "$myJWT" ] && echo "No \$hawkToken or JWT found." && return 1
    [ -z "$myDataplane" ] && echo "No \$myDataplane found. => $usage" && return 1
    dpConfig=$(getDPRawConfig $myDataplane)
    echo >&2 ===
    echo "$dpConfig" | jq -r '.data[0].dp_config.k8sDPConfig."--ct-auth-token"' | base64 -d ; echo
    echo >&2 ===
}

function getHawkToken {
    if [ -n "$hawkToken" ] ; then
        echo -n "$hawkToken"
        return 0
    fi
    # CP side only
    usage=" getHawkToken [\$myDataplane] -- Extract hawkToken from raw config for DP"
    [ -n "$1" ] && myDataplane="$1"
    [ -z "$myJWT" ] && export myJWT=$(getJWT)
    [ -z "$myJWT" ] && echo "No JWT found." && return 1
    dpConfig=$(getDPRawConfig $myDataplane)
    echo >&2 ===
    echo "$dpConfig" | jq -r '.data[0].dp_config.k8sDPConfig."--ct-auth-token"' ; echo
    echo >&2 ===
}

function hawkMHealth {
    # # echo curl -i "${cOpts[@]}"  "http://$hawkHP/$hawkHealth"
    # curl -i -Ss --location --header Content-Type: application/json -k http://10.97.130.111:9687/hawkconsole/exporter/hawk/metrics/health
    # # curl -i "${cOpts[@]}"  "http://$hawkHP/$hawkHealth"
    # hawkHP=$(hawkHP)
    hawkCTPath=$(hawkCTPath)
    hawkStdOpts
    [ -n "$(getHawkBasicAuth)" ] && auth=() && auth+=("-u") && auth+=("$(getHawkBasicAuth)")
    apiMetricsHealth="hawkconsole/exporter/hawk/metrics/health"
    echo >&2 '#+: curl -i "${hawkCurlOpts[@]}" "${auth[@]}" ' "$hawkCTPath/$apiMetricsHealth" '| tee curl.out' 
    curl -i "${hawkCurlOpts[@]}" "${auth[@]}"  "$hawkCTPath/$apiMetricsHealth" | tee curl.out >&2
    echo >&2 ; echo >&2 ===
    tail -1 curl.out | jq '.'
}
function hawkAbout {
    # hawkHP=$(hawkHP)
    hawkCTPath=$(hawkCTPath)
    hawkStdOpts
    [ -n "$(getHawkBasicAuth)" ] && auth=() && auth+=("-u") && auth+=("$(getHawkBasicAuth)")
    api="hawkconsole/about"
    echo >&2 '#+: curl -i "${hawkCurlOpts[@]}" "${auth[@]}" ' "$hawkCTPath/$api" '| tee curl.out' 
    curl -i "${hawkCurlOpts[@]}" "${auth[@]}"  "$hawkCTPath/$api" | tee curl.out >&2
    echo >&2 ; echo >&2 ===
    tail -1 curl.out | jq '.'
}

function genMsgScrapePayload {
    usage="genMsgScrapePayload -- Generate Hawk scrape for tp-msg-gateway"
    monUrl=${1:-"http://tp-msg-gateway:8376"}
    groupName="tp-msg-gateway"
    dataplaneId="${myDataplane:-$MY_DATAPLANE}"
    [ -z "$dataplaneId" ]  && echo >&2 "\$myDataplane required." && return 1
    scheme="$(echo "$monUrl" | cut -d: -f1)"
    host="$(echo "$monUrl" | cut -d: -f2 | tr -d '/' )"
    port="$(echo "$monUrl" | cut -d: -f3 )"
    cat - <<EOF
        {
          "serverGroup": "$groupName",
          "serverDetails": [
            {
              "host": "$host",
              "port": $port,
              "endPoint": "/dp/metric/health",
              "httpScheme": "$scheme",
              "scrapingInterval": 60,
              "labels": {
                "group": "$groupName",
                "dataplane_id": "$dataplaneId"
              }
            }
          ]
        }
EOF
}

function hawkRegister {
    ##+:  curl -i -Ss --location --header Content-Type: application/json -k 
    ##+:  -X POST 10.97.130.111:9687/hawkconsole/base/exporter/ems/register 
    ##+:    --data ...
    usage='hawkRegister <json-file> -- Register EMS with Hawk'
    f=${1:?"$usage"}
    # hawkHP=$(hawkHP)
    hawkCTPath=$(hawkCTPath)
    hawkStdOpts
    [ -n "$(getHawkBasicAuth)" ] && auth=() && auth+=("-u") && auth+=("$(getHawkBasicAuth)")
    api="hawkconsole/base/exporter/ems/register"
    data="$(yq < $f '.' -o json)"
    echo >&2 '#+: curl -i "${hawkCurlOpts[@]}" "${auth[@]}" ' -X POST "$hawkCTPath/$api" ' --data "$data" | tee curl.out >&2 '
    curl -i "${hawkCurlOpts[@]}" "${auth[@]}"   -X POST "$hawkCTPath/$api" --data "$data" | tee curl.out >&2
    echo >&2 ; echo >&2 ===
    tail -1 curl.out | jq '.'
}

function hawkUnregister {
    usage='hawkUnregister <server-group-name> -- Unregister EMS with Hawk'
    groupName=${1:?"$usage"}
    hawkCTPath=$(hawkCTPath)
    hawkStdOpts
    [ -n "$(getHawkBasicAuth)" ] && auth=() && auth+=("-u") && auth+=("$(getHawkBasicAuth)")
    data="$(printf '{"serverGroup": "%s"}' "$groupName")"
    api="hawkconsole/base/exporter/ems/unregister"
    echo >&2 '#+: curl -i "${hawkCurlOpts[@]}" "${auth[@]}" ' -X POST "$hawkCTPath/$api" ' --data "$data" | tee curl.out >&2 '
    curl -i "${hawkCurlOpts[@]}" "${auth[@]}"   -X POST "$hawkCTPath/$api" --data "$data" | tee curl.out >&2
    echo >&2 ; echo >&2 ===
    tail -1 curl.out | jq '.'
    #     // Remove a server group from scrape config
    # POST http://<hawkconsole-host>:<hawkconsole-port>/base/exporter/ems/unregister
    # {
    #     "serverGroup": "ems-xyz"
    # }
}

function hawkEHealth {
    # hawkHP=$(hawkHP)
    hawkCTPath=$(hawkCTPath)
    hawkStdOpts
    [ -n "$(getHawkBasicAuth)" ] && auth=() && auth+=("-u") && auth+=("$(getHawkBasicAuth)")
    api="hawkconsole/base/exporter/custom/health"
    echo >&2 '#+: curl -i "${hawkCurlOpts[@]}" "${auth[@]}" ' -X GET "$hawkCTPath/$api" '| tee curl.out' 
    curl  -i "${hawkCurlOpts[@]}" "${auth[@]}" -X GET "$hawkCTPath/$api" | tee curl.out >&2
    echo >&2 ; echo >&2 ===
    tail -1 curl.out | jq '.'
}

# GRV HELPERS
function rvHawkConfig {
    usage="rvHawkConfig [rvMonMetricsUrl]  -- Generate a Hawk rvmon json blob"
    monUrl=${1:-"http://tp-msg-gateway:7585"}
    groupName="rvmon"
    resourceInstanceId="riid-7585"
    dataplaneId="${myDataplane:-$MY_DATAPLANE}"
    [ -z "$dataplaneId" ]  && echo >&2 "\$myDataplane required." && return 1
    scheme="$(echo "$monUrl" | cut -d: -f1)"
    host="$(echo "$monUrl" | cut -d: -f2 | tr -d '/' )"
    port="$(echo "$monUrl" | cut -d: -f3 )"
    cat - <<EOF
        {
          "serverGroup": "$groupName",
          "serverDetails": [
            {
              "host": "$host",
              "port": $port,
              "endPoint": "/metrics",
              "httpScheme": "$scheme",
              "scrapingInterval": 60,
              "labels": {
                "group": "$groupName",
                "resource_instance_id": "$resourceInstanceId",
                "capability_instance_id": "$resourceInstanceId",
                "dataplane_id": "$dataplaneId"
              }
            },
            {
              "host": "$host",
              "port": $port,
              "endPoint": "/metrics/clients",
              "httpScheme": "$scheme",
              "scrapingInterval": 60,
              "labels": {
                "group": "$groupName",
                "resource_instance_id": "$resourceInstanceId",
                "capability_instance_id": "$resourceInstanceId",
                "dataplane_id": "$dataplaneId"
              }
            },
            {
              "host": "$host",
              "port": $port,
              "endPoint": "/metrics/neighbors",
              "httpScheme": "$scheme",
              "scrapingInterval": 60,
              "labels": {
                "group": "$groupName",
                "resource_instance_id": "$resourceInstanceId",
                "capability_instance_id": "$resourceInstanceId",
                "dataplane_id": "$dataplaneId"
              }
            },
            {
              "host": "$host",
              "port": $port,
              "endPoint": "/metrics/profiling",
              "httpScheme": "$scheme",
              "scrapingInterval": 60,
              "labels": {
                "group": "$groupName",
                "resource_instance_id": "$resourceInstanceId",
                "capability_instance_id": "$resourceInstanceId",
                "dataplane_id": "$dataplaneId"
              }
            }
          ]
        }
EOF
}

function rvHawkEnable {
    # POST https://<hawkconsole-host>:<hawkconsole-port>/hawkconsole/base/exporter/ems/register
    groupName="rvmon"
    log "    :$groupName: Enable hawk scraping"
    echo >&2 "#+: enableHawkScraping"
    rvPayload="$(rvHawkConfig)"
    echo "$rvPayload" > tmp.rvHawkPayload.json
    hawkCTPath=$(hawkCTPath)
    hawkStdOpts
    apiRegister="hawkconsole/base/exporter/ems/register"
    [ -n "$(getHawkBasicAuth)" ] && auth=() && auth+=("-u") && auth+=("$(getHawkBasicAuth)")
    # echo >&2 "#+: " curl '"${curlOpts[@]}"' "https://$hawkHost:$hawkPort/$apiRegister"
    echo >&2 "#+: "' curl "${hawkCurlOpts[@]}" "${auth[@]}" ' -X POST "$hawkCTPath/$apiRegister" ' --data "$rvPayload"'
    resp=$(curl "${hawkCurlOpts[@]}" "${auth[@]}" -X POST "$hawkCTPath/$apiRegister" --data "$rvPayload")
    rtc=$?
    [ $rtc -ne 0 ] && echo >&2 "ERROR:  Hawk Register error." && echo >&2 "$resp" && echo >&2 ""
    echo "$resp" | tail -1 | jq '.'  >&2 
    return 0
}

function gatewayMetricHealth {
    echo >&2 '#+: curl -Ss http://tp-msg-gateway:8376/dp/metric/health'
    curl  -Ss http://tp-msg-gateway:8376/dp/metric/health | tee prom.out
}

function gatewayJsonHealth {
    echo >&2 '#+: curl -i -Ss http://tp-msg-gateway:8376/dp/json/health'
    curl -i -Ss http://tp-msg-gateway:8376/dp/json/health | tee curl.out >&2
    echo >&2 ; echo >&2 ===
    tail -1 curl.out | jq '.'
}

function pltHelp {
    echo "$pltFunctionsUsage"
}
echo >&2 "# Use pltHelp for more info"
