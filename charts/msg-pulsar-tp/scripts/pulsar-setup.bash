
# Copyright (c) 2023-2024 Cloud Software Group, Inc. All Rights Reserved. Confidential and Proprietary.
# This file is intended to be sourced on pod startup

# DEBUG: for x in "$@" ; do echo ".. $x .." ; done
# SET ZONE INFORMATION
# TODO: error out if get nodes is not available and bookie replica count > 3
# export MY_POD_ZONE=$(kubectl get node $MY_NODE_NAME -o=jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}' )

[ -z "$WATCHDOG_MAIN" ] && [ -n "$1" ] && export WATCHDOG_MAIN=$1
[ -z "$WATCHDOG_MAIN_ARGS" ] && [ -n "$2" ] && export WATCHDOG_MAIN_ARGS=$2

export TCM_WATCHDOG_HOSTPORT=${WATCHDOG_HOSTPORT:-0.0.0.0:12502}
export WATCHDOG_LOGDIR="${WATCHDOG_LOGDIR:-/pulsar/logs}"
export TCM_WATCHDOG_LOG_FILE=${WATCHDOG_LOG_FILE:-$WATCHDOG_LOGDIR/watchdog.${HOSTNAME}.log}
export WATCHDOG_MAIN=${WATCHDOG_MAIN:-bin/pulsar}
export WATCHDOG_MAIN_ARGS=${WATCHDOG_MAIN_ARGS:-""}
export TCM_WATCHDOG_CONFIG=${TCM_WATCHDOG_CONFIG:-$WATCHDOG_LOGDIR/watchdog.yml}
# DEBUG:
# export WATCHDOG_MAIN=/usr/local/watchdog/bin/wait-for-shutdown.sh

# PROCESS CONF FILES
# TODO: MSGDP-507 - allow moving /pulsar/conf to /pulsar/data/conf for better volume management
for x in $(/bin/ls -1 /pulsar-conf ) ; do
    [ ! -f "/pulsar/conf/$x" ] && cp -r /pulsar-conf/$x /pulsar/conf/$x 
done

# PROCESS BOOT FILES
# bash /boot/mk-watchdog.yml.sh $TCM_WATCHDOG_CONFIG
datadir="/pulsar/data"
certdir="$datadir/certs"
( mkdir -p $WATCHDOG_LOGDIR ; cd $WATCHDOG_LOGDIR ; for x in /boot/mk-*.sh ; do bash < $x ; done | tee -a boot.out )

# PROCESS CERTS
# FUTURE: Chart Cert override options
# ( mkdir -p $certdir ; cd $certdir ; 
#     if [ -f $(echo /boot-certs/*.pem | cut -f1 -d' ' ) ] ; then
#         cp /boot-certs/* ./ ; fi )
# ( cd $certdir ; 
#     for x in server.cert.pem server_root.cert.pem server.key.pem ; do 
#         [ ! -f "$x" ] && cp /opt/tibco/ems/current-version/samples/certs/$x $x ; done ) ;

env | sort > $WATCHDOG_LOGDIR/pulsar-setup.env
# APACHE CHART ASSUMES /pulsar working directory!
