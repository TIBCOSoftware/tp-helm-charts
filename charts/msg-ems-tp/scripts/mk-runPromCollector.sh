#!/bin/bash 
#
# Copyright (c) 2023. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

bootDir=${1:-"/logs/$MY_POD_NAME/boot"}
outfile="$bootDir/runPromCollector.sh"

export MY_POD_NAME=${MY_POD_NAME:-$(hostname)}
export EMS_TCP_PORT=${EMS_TCP_PORT:-"9011"}
export EMS_PROM_PORT=${EMS_PROM_PORT:-"9091"}

# Generate Server Config
cat - <<EOF > $bootDir/servers.xml
<?xml version="1.0"?>
<EMS-StatsLoggerConfig>
    <ConnectionNode alias="$MY_POD_NAME" url="tcp://localhost:$EMS_TCP_PORT" user="admin" password="" logDir="./log" logFile="\$N-\$D.csv" logCleanup="30">
	<QueueMonitor pattern="demo.&gt;" logDir="./log" logFile="\$N-\$D-Queues.csv"/>
	<TopicMonitor pattern="demo.&gt;" logDir="./log" logFile="\$N-\$D-Topics.csv"/>
    </ConnectionNode>
</EMS-StatsLoggerConfig>
EOF
# Generate start script
cat - <<EOF > $outfile
#!/bin/bash
TIBEMS_ROOT=/opt/tibco/ems/current-version
TIBEMS_LIB=\$TIBEMS_ROOT/lib
TIBEMS_BIN=\$TIBEMS_ROOT/bin
CLASSPATH=\$TIBEMS_LIB/emsStatsLogger.jar:\$TIBEMS_LIB/tibjmsadmin.jar:\$TIBEMS_LIB/jms-2.0.jar:\$TIBEMS_LIB/tibjms.jar

java -cp \$CLASSPATH EmsStatsPromCollector -config $bootDir/servers.xml -interval 60 -serverStatsPort $EMS_PROM_PORT -queueStatsPort 9092 -topicStatsPort 9093 -debug
EOF
chmod +x $outfile

# Generate CSV Logger
cat - <<EOF > $bootDir/runLogger.sh
#!/bin/bash
TIBEMS_ROOT=/opt/tibco/ems/current-version
TIBEMS_LIB=\$TIBEMS_ROOT/lib
TIBEMS_BIN=\$TIBEMS_ROOT/bin
CLASSPATH=\$TIBEMS_LIB/emsStatsLogger.jar:\$TIBEMS_LIB/tibjmsadmin.jar:\$TIBEMS_LIB/jms-2.0.jar:\$TIBEMS_LIB/tibjms.jar

java -cp \$CLASSPATH EmsStatsLogger -config $bootDir/servers.xml -debug
EOF
chmod +x $bootDir/runLogger.sh
