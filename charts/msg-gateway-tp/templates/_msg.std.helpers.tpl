

{{/* USAGE}}
        {{- $stsname := printf "sts/%s" $basename -}}
        {{- $jobLabel := printf "-l=tib-msg-jobname=%s-preinstall" $params.msggw.basename -}}
          # Prevent downgrades
          {{ include "msg.rollback.protection" (dict "v" .Chart.Version "cr" $stsname ) | nindent 10 }}
          # Cleanup old hook jobs
          {{ include "msg.oldjob.cleanup" ( $jobLabel ) | nindent 10 }}
.. Especially useful in preinstall jobs, where configMaps are not yet created.
*/}}

{{/* msg.rollback.protection - check workload label to prevent attempted rollbacks 
Pass check-spec {"v": "<newversion>", "cr": "<crNameToCheck>", }
checks via labelName=tib-msgdp-mm-version
*/}}
{{- define "msg.rollback.protection" }}
newVersion="{{ .v }}" ; 
runningVersion=$(kubectl get {{ .cr }} -o=jsonpath='{.metadata.labels.tib-msgdp-mm-version}' ) ; 
[ -z "$runningVersion" ] && runningVersion="1.10.0" ; 
echo "#+: Checking :  semver compare $runningVersion $newVersion " ; 
rtc=$( /usr/local/bin/semver compare $runningVersion $newVersion ) ;
[ "$rtc" -eq 1 ] && echo "ERROR: Downgrades not supported." && exit 1 ; 
{{- end }}

{{/* msg.oldjob.cleanup - Find previous jobs by label and delete them
. == kubectl get jobs label expression to use
*/}}
{{- define "msg.oldjob.cleanup" }}
echo "#+: Cleaning up old hook jobs" ; 
kubectl get jobs {{ . }} | egrep "Complet|Fail" | while read x o ; do
  echo "Deleting job $x" ;
  kubectl delete job $x ; 
done ;
{{- end }}
