#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

[ -n "$LOG_DIR" ] && mkdir -p "$LOG_DIR" && cd "$LOG_DIR"
fmtTime="--rfc-3339=ns"
function log
{ echo "$(date "$fmtTime"): $*" ; }
ststmp="tmp.sts"

echo "Upgrading Statefulsets ..." ; 
kubectl get sts -o wide -l=release=${MY_RELEASE} | tee sts.out
egrep -v '^NAME' sts.out > $ststmp ; mv $ststmp sts.pending
[ "$HEALTH_ACTION" = "skip-redeploy" ] && log "Skipping pod redeploys as requested." && exit 0

# PULSAR RECOMMENDED UPGRADE ORDER is: zookeeper, bookkeeper, broker, proxy
export STS_NAME="${MY_GROUP}-zoo"
echo ""
log "UPGRADING STS = $STS_NAME ..."
bash < /boot/health-watcher.sh 
[ $? -ne 0 ] && log "ERROR: failed to restart zookeepers $STS_NAME" && exit 1
egrep -v "^$STS_NAME" sts.pending > $ststmp ; mv $ststmp sts.pending

kubectl scale sts/${MY_GROUP}-recovery --replicas=0
export STS_NAME="${MY_GROUP}-bookie"
echo ""
log "UPGRADING STS = $STS_NAME ..."
bash < /boot/health-watcher.sh 
[ $? -ne 0 ] && log "ERROR: failed to restart $STS_NAME" && exit 1
egrep -v "^$STS_NAME" sts.pending > $ststmp ; mv $ststmp sts.pending
kubectl scale sts/${MY_GROUP}-recovery --replicas=1
egrep -v "^$MY_GROUP-recovery" sts.pending > $ststmp ; mv $ststmp sts.pending

export STS_NAME="${MY_GROUP}-broker"
echo ""
log "UPGRADING STS = $STS_NAME ..."
bash < /boot/health-watcher.sh 
[ $? -ne 0 ] && log "ERROR: failed to restart $STS_NAME" && exit 1
egrep -v "^$STS_NAME" sts.pending > $ststmp ; mv $ststmp sts.pending

# DEBUG:
cat sts.pending
echo "======================"

cat sts.pending | while read STS_NAME other ; do 
    echo ""
    log "UPGRADING STS = $STS_NAME ..."
    bash < /boot/health-watcher.sh 
    [ $? -ne 0 ] && log "ERROR: failed to restart $STS_NAME" && exit 1
done
exit 0
