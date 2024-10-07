export LD_LIBRARY_PATH=/opt/tibco/ems/current-version/lib:/opt/tibco/ftl/current-version/lib
export ftlUrl="${EMS_FTL_REALM_URL:-$FTL_REALM_URL}"
tibemsjson2ftl -url "$ftlUrl" -json running.tibemsd.json -download
