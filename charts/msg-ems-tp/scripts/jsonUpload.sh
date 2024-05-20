export LD_LIBRARY_PATH=/opt/tibco/ems/current-version/lib:/opt/tibco/ftl/current-version/lib
tibemsjson2ftl -url $FTL_REALM_URL -json running.tibemsd.json 
