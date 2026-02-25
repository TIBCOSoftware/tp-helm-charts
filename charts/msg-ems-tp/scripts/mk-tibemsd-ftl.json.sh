#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

outfile=${1:-tibemsd-ftl.json}
srvBase="${EMS_SERVICE}"
svcname="${srvBase}"
namespace=$MY_NAMESPACE
realmPort="${FTL_REALM_PORT-9013}"
emsTcpPort="${EMS_TCP_PORT:-9011}"
emsSslPort="${EMS_SSL_PORT:-9012}"
EMS_FTL_SPIN="${EMS_FTL_SPIN:-disabled}"
EMS_MAX_MEMORY=${EMS_MAX_MEMORY:-4GB}
subData="/data"
pstoreData="/data"

# export LD_LIBRARY_PATH=/opt/tibco/ftl/lib
# /opt/tibco/ems/current-version/bin/tibemsjson2ftl -url "http://localhost:$ftlport" -json $initTibemsdJson
export insideSvcHostPort="${svcname}.${namespace}.svc:${emsTcpPort}"
export insideActiveHostPort="${svcname}active.${namespace}.svc:${emsTcpPort}"

# GET EMS ADMIN LIST
adminList=""
if [ -n "$EMS_CP_OWNER" ] ; then 
    # adminList="$adminList"' {"name":"dmiller@tibco.com"},'
    # adminList="$adminList"' {"name":"bhorst@tibco.com"},'
    adminList="$adminList"' {"name":"'$EMS_CP_OWNER'"},'
    gemsDescription="CP Owner with admin priviledges"
    gemsList='{"name":"'$EMS_CP_OWNER'"}'
    gemsList="$gemsList"',{"name":"'$EMS_ADMIN_USER'"}'
    msgGemsGrp='{"description":"'"$gemsDescription"'","members":['"$gemsList"'],"name":"msg-gems-admin"},'
fi
if [ -n "$EMS_ADMIN_USER" ] ; then 
    adminList="$adminList"' {"name":"'$EMS_ADMIN_USER'"},'
    tibAdminUser='{ "description":"Tibco DP Admin credentials", "name":"'$EMS_ADMIN_USER'", "password":"locked" },'
fi

cat - <<EOF > $outfile
{
  "acls": [
    {
      "type": "admin",
      "group": "msg-gems-admin",
      "all": true
    }
  ],
  "bridges":[],
  "channels":[],
  "durables":[],
  "factories": [ 
    {
      "jndinames":[],
      "name":"FTConnectionFactory",
      "ssl":{
        "ssl_issuer_list":[],
        "ssl_trusted_list":[]
      },
      "type":"generic",
      "url":"tcp:\/\/$insideActiveHostPort,tcp:\/\/$insideSvcHostPort",
      "connect_attempt_timeout": 5000,
      "connect_attempt_count": 300,
      "connect_attempt_delay": 850,
      "reconnect_attempt_timeout": 5000,
      "reconnect_attempt_count": 300,
      "reconnect_attempt_delay": 850
    },
    {
      "jndinames":[],
      "name":"FTTopicConnectionFactory",
      "ssl":{
        "ssl_issuer_list":[],
        "ssl_trusted_list":[]
      },
      "type":"topic",
      "url":"tcp:\/\/$insideActiveHostPort,tcp:\/\/$insideSvcHostPort",
      "connect_attempt_timeout": 5000,
      "connect_attempt_count": 300,
      "connect_attempt_delay": 850,
      "reconnect_attempt_timeout": 5000,
      "reconnect_attempt_count": 300,
      "reconnect_attempt_delay": 850
    },
    {
      "jndinames":[],
      "name":"FTQueueConnectionFactory",
      "ssl":{
        "ssl_issuer_list":[],
        "ssl_trusted_list":[]
      },
      "type":"queue",
      "url":"tcp:\/\/$insideActiveHostPort,tcp:\/\/$insideSvcHostPort",
      "connect_attempt_timeout": 5000,
      "connect_attempt_count": 300,
      "connect_attempt_delay": 850,
      "reconnect_attempt_timeout": 5000,
      "reconnect_attempt_count": 300,
      "reconnect_attempt_delay": 850
    }
  ],
  "groups":[
    $msgGemsGrp
    {
      "description":"Administrators",
      "members":[
        $adminList
        {
          "name":"admin"
        }
      ],
      "name":"\$admin"
    }
  ],
  "model_version":"1.0",
  "queues":[
    {
      "expiration":"4day",
      "maxbytes":"4GB",
      "name":">",
      "secure":true,
      "store":"\$sys.failsafe"
    }
  ],
  "routes":[],
  "stores":[
          {
            "name":"\$sys.meta",
            "type":"ftl"
          },
          {
            "name":"\$sys.failsafe",
            "type":"ftl"
          },
          {
            "name":"\$sys.nonfailsafe",
            "type":"ftl"
          }
        ],
  "tibemsd":{
    "user_auth": "local,oauth2",
    "oauth2_server_validation_key": "/data/boot/cp-oauth2.jwks.json",
    "oauth2_user_claim": "email",
    "oauth2_group_claim": "gsbc",
    "always_exit_on_disk_error":true,
    "authorization":false,
    "console_trace": "DEFAULT,+CONNECT",
    "handshake_timeout":60,
    "destination_backlog_swapout":"20000",
    "ftl_spin":"$EMS_FTL_SPIN",
    "large_destination_memory":"3200MB",
    "max_client_msg_size":"2MB",
    "max_connections":"3000",
    "max_msg_memory":"$EMS_MAX_MEMORY",
    "max_stat_memory":"64MB",
    "msg_swapping":true,
    "network_thread_count":3,
    "reserve_memory":"32MB",
    "routing":false,
    "server":"$srvBase",
    "server_heartbeat_client":5,
    "server_timeout_client_connection":16,
    "client_heartbeat_server": 5,
    "client_timeout_server_connection":16,
    "disconnect_non_acking_consumers":true,
    "ssl":{
      "ssl_cert_user_specname":"CERTIFICATE_USER",
      "ssl_issuer_list":[],
      "ssl_password":"\$man\$WjtSRCpaXu7hoTkDlcEPr6KNKRr",
      "ssl_server_identity":"\/data\/certs\/server.cert.pem",
      "ssl_server_key":"\/data\/certs\/server.key.pem",
      "ssl_trusted_list":[
      ]
    },
    "statistics_cleanup_interval":30,
    "statistics":true
  },
  "tibrvcm":[],
  "topics":[
    {
      "expiration":"4day",
      "maxbytes":"4GB",
      "name":">",
      "secure":true,
      "store":"\$sys.failsafe"
    }
  ],
  "transports":[],
  "users":[
    {
      "description":"Administrator",
      "name":"admin",
      "password":null
    },
    $tibAdminUser
    {
      "description":"server-user",
      "name":"$srvBase",
      "password":"locked"
    }
  ]
}

EOF
