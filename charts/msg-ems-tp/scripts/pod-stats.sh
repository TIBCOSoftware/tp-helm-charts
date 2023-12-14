#!/bin/bash
#
# Copyright (c) 2023. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
usage="
$cmd -- monitor pod resources as csv in ./pod-mon.csv
    also enforces a POD PID limit of $POD_MAX_THREADS for node protection
ENV OPTIONS:
    POD_STATS_INTERVAL  - override default collection interval of 20s
    POD_MON_CSV         - override ./pod-mon.csv summary filename
    POD_DISK_CSV        - override ./pod-disk.csv summary filename
    POD_MAX_THREADS     - override default max threads of 15000
    POD_MON_DISK        - enable low-disk monitoring with a list of directories
    POD_DISK_ALERT_SH   - path to script for low_disk alerts (optional)
"
csvfile="${POD_MON_CSV:-./pod-mon.csv}"
diskcsv="${POD_DISK_CSV:-./pod-disk.csv}"
sampleWait="${POD_STATS_INTERVAL:-20}"
maxThreads="${POD_MAX_THREADS:-15000}"
podDiskThreshold="${POD_DISK_THRESHOLD:-95}"
podDiskList="${POD_DISK_MON}"
podDiskAlert="${POD_DISK_ALERT_SH}"
## more portable, but no milliseconds:  
## fmtTime="+%y%m%dT%H:%M:%S"
## Ubuntu preferred: 
fmtTime="--rfc-3339=ns"

# Set signal traps
function log
{ echo "$(date "$fmtTime"): $*" ; }

function do_shutdown
{ log "-- Shutdown received (SIGTERM): host=$HOSTNAME" && exit 0 ; }
function do_sighup
{ log "-- Got SIGHUP: host=$HOSTNAME" ; }
trap do_shutdown SIGINT
trap do_shutdown SIGTERM
trap do_sighup SIGHUP

function memusage
{
    rawpod=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes )
    podcache=$(egrep '^cache'  /sys/fs/cgroup/memory/memory.stat | cut -f2 -d' ')
    usage=$(( $rawpod - $podcache ))
    usageMb=$(( $usage / 1000000 ))
    usageMi=$(( $usage / 1048576 ))
    echo $usageMi
}

export lastrawcpu="sv.lastrawcpu"
function cpuusage {
    rawcpu_ns=$(cat /sys/fs/cgroup/cpuacct/cpuacct.usage)
    rawcputick=$(date "+%s" )
    if [ "$1" = "0" ] ; then
        # avoid divide by zero :)
        sleep 2
        pass=1
    elif [ -f "$lastrawcpu" ] ; then
        set $(cat $lastrawcpu)
    fi
    lastrawcpu_ns=${1:-0}
    lastrawcputick=${2:-0}
    if [ "$lastrawcputick" -gt 0 ] ; then 
        deltacpu=$(( $rawcpu_ns - $lastrawcpu_ns ))
        deltatime=$(( $rawcputick - $lastrawcputick ))
        millicpu=$(( $deltacpu / $deltatime / 1000000 ))
        # echo >&2 "Computing: $deltacpu,$deltatime,$millipcu"
        echo "$millicpu"
    else
        # echo >&2 "Initializing: $lastrawcpu_ns,$rawcpu_ns"
        # Initlial history
        echo "-1" 
    fi
    echo "$rawcpu_ns $rawcputick" > $lastrawcpu
}

function df_csv_hdr() {
    [ -z "$podDiskList" ] && return 0
    hdr=''
    for x in $(echo $podDiskList | tr ',' ' ') ; do 
        # fs-0df702f12a7e210cb.efs.us-west-2.amazonaws.com:/dmiller/data  8.0E  547G  8.0E   1% /data
        dhdr="UsedB$x,Used%$x"
        hdr="${hdr},${dhdr}"
    done
    echo "$hdr"
}

function df_usage_csv() {
    [ -z "$podDiskList" ] && return 0
    csvdata=''
    for x in $(echo $podDiskList | tr ',' ' ') ; do 
        # fs-0df702f12a7e210cb.efs.us-west-2.amazonaws.com:/dmiller/data  8.0E  547G  8.0E   1% /data
        [ -n "$csvdata" ] && csvdata="$csvdata,"
        data=$(df -h $x 2>/dev/null | tail -1 )
        [ -z "$data" ] && csvdata="${csvdata}$bused,$pstrip" &&  continue
        set $data
        fsys="$1"
        bused="$3"
        pused="$5"
        pstrip="${pused/\%/}"
        csvdata="${csvdata}$bused,$pstrip"
        if [ "$pstrip" -gt $podDiskThreshold ] ; then
            log " WARN LOW-DISK: $data" >&2
            [ -n "$podDiskAlert" ] && $podDiskAlert -d "$x" -b "$bused" -p "$pstrip" -f "$fsys"
        fi
    done
    echo "$csvdata"
}

function rotate_log() {
    usage="rotate_log <file> -- move versions 0>1>2>..."
    file=${1:?"$usage - filename required."}
    [ ! -f "$file" ] &&  return 0
    vmax="${2:-20}"
    for ver in $(seq $vmax -1 0) ; do
        [ -f "$file.$ver" ] && mv "$file.$ver" "$file.$(($ver + 1))"
    done
    mv "$file" "$file.0"
}

echo "# ===== $cmd ====="
log " DISK MONITORING: $podDiskList"
! which "$podDiskAlert" && export podDiskAlert='' && echo "NO DISK ALERTING."
ulimit -a
echo "#============================"
initcpu=$(cpuusage 0 0)
rotate_log "$csvfile"
echo "datetime,ram(Mi),cpu(m),nFDs,nPids" > $csvfile
diskhdr="$(df_csv_hdr)"
[ -n "$diskhdr" ] && rotate_log $diskcsv && echo "$diskhdr" > $diskcsv

while true
do
    dtime="$(date "$fmtTime" )"
    ramUse=$(memusage)
    cpuUse=$(cat /sys/fs/cgroup/cpuacct/cpuacct.usage)
    totalFDs=0
    totalPids=0
    for pid in /proc/[0-9]*
    do
        pnum=$(basename $pid)
        threadcount="$(ps -L $pnum | wc -l)"
        fdcount="$(ls -1 $pid/fd/ | wc -l)"
        totalFDs=$(( totalFDs + fdcount))
        totalPids=$(( totalPids + threadcount))
        if [ "$threadcount" -gt "$maxThreads" ] ; then
            echo "$dtime: ERROR ABORTING: pids=$threadcount - over max thread limit!"
            echo "StackDump-start:---------------"
            jstack $pnum 
            kill -SIGABRT "$pnum"
            echo "StackDump-end:---------------"
        fi
    done
    if [ "$totalPids" -gt "$maxThreads" ] ; then
        echo "$dtime: ERROR ABORTING POD: pod pids=$totalPids - over max pid limit!"
        kill 1
    fi
    # std-Timestamp(like logs), cpu, ram, nFDs, nPids, <disk1-used>, <disk2-used> ...
    echo "$dtime,$ramUse,$(cpuusage),$totalFDs,$totalPids" >> $csvfile
    [ -n "$diskhdr" ] && echo "$dtime,$(df_usage_csv)" >> $diskcsv

    # Do not delay pod restarts!
    for x in $(seq $sampleWait) ; do 
        sleep 1
    done
done
