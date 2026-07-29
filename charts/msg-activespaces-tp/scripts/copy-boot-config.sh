#!/bin/bash

uplabel=${UPGRADE_LABEL:-tib-msg-config-upgrade}
modlabel=${CONFIG_MODIFIED_LABEL:-tib-msg-config-modified}
usage="$0 <from> <to> [options] -- Copy to pod, new boot config files
.. used to copy pod chart config files to PV directories for use
.. by default - only copies missing in the target directory.
.. if upgrade label (UPGRADE_LABEL) is force, refresh during upgrade restart
.. if upgrade label is safe, only update if modified label (CONFIG_MODIFIED_LABEL) is not yes

Options:
    $uplabel    - set pod label to for config refresh on upgrade:  (force|safe|upgrade)
    $modlabel   - dynamic pod label to flag configFiles as protected or user modified (yes|no)
"
from=${1:-$COPY_FROM}
to=${2:-$COPY_TO}
[ -z "$from" ] && echo "$usage    ; missing COPY_FROM" && exit 1
[ -z "$to" ] && echo "$usage    ; missing COPY_TO" && exit 1
labelfile=${POD_LABEL_FILE:-/podinfo/labels}
upgradeDefault=$(egrep "^$uplabel=" $labelfile | cut -d= -f2 | tr -d '"')
upgrade=${UPGRADE_ACTION:-$upgradeDefault}
modifiedDefault=$(egrep "^$modlabel=" $labelfile | cut -d= -f2 | tr -d '"')
modified=${CONFIG_MODIFIED_FLAG:-$modifiedDefault}
inventory=
echo "upgrade=$upgrade modified=$modified"

# Safe means - no mods if any changes, or only protect changed files ?? 
[[ ! "$modified" =~ t|true|yes ]] && [[ "$upgrade" =~ safe|upgrade ]] && upgrade=force

# NOTE: find -type f $from on ConfigMap mounts are not normal filenames
# .. for now only support a single level to get dot files
mkdir -p "$to"
(find $from -type f  )  | while read frompath ; do 
    fname=$(basename $frompath)
    if [ -f $to/$fname ] ; then 
        if  [ "$upgrade" = force ] ; then 
            rm -f $to/$fname ; 
            echo "force upgrade: $to/$fname"
        else
            echo "skipping: $to/$fname"
        fi
    fi
    if [ ! -f $to/$fname ] ; then
        echo "copying: $to/$fname"
        cp $frompath $to/$fname
        [[ $fname =~ [.]sh$ ]] && chmod +x $to/$fname
        [[ $fname =~ ^mk- ]] && chmod +x $to/$fname && (cd $to && ./$fname)
    fi 
done
## PATCH uplabel to done
if [ -n "$upgrade" ] && [[ ! "$upgrade" =~ done ]] ; then 
    echo "Setting label : $uplabel=done"
    spec=$(printf '{"metadata":{"labels":{"%s":"%s"}}}' "$uplabel" "done" )
    echo "#+: " kubectl patch pod/$MY_POD_NAME --type=merge -p="$spec"
    kubectl patch pod/$MY_POD_NAME --type=merge -p="$spec"
fi
