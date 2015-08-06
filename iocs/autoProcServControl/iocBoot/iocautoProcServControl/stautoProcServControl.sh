#!/bin/sh
# go to the bin/arch directory
cd "$(dirname "$0")"
# globals
SOFTIOCS=/dls_sw/prod/etc/init/$(hostname -s)/soft-iocs
ST_FILE="/tmp/stautoProcServControl.cmd"
TOP=$(cd ../..; pwd)
PROCSERVCONTROL=$(cd ../../../..; pwd)

# Make a startup script, first the header
cat <<EOF > $ST_FILE
cd $TOP
epicsEnvSet "EPICS_TS_MIN_WEST", '0'
dbLoadDatabase "dbd/autoProcServControl.dbd"
autoProcServControl_registerRecordDeviceDriver(pdbbase)
EOF

# Make asyn ports and database bits
sed '/^#/d;/^\s*$/d' "$SOFTIOCS" | (
    while read IOC PORT IOCARGS; do
        if [ "$IOC" != "autoProcServControl" ]; then
            cat <<EOF >> $ST_FILE
drvAsynIPPortConfigure("${IOC}port", "localhost:${PORT}", 100, 0, 0)
dbLoadRecords "${PROCSERVCONTROL}/db/procServControl.template", "P=${IOC},PORT=${IOC}port"
EOF
        fi
    done
)

# IocInit
echo iocInit >> $ST_FILE

# Start sequencers
# Make asyn ports and database bits
sed '/^#/d;/^\s*$/d' "$SOFTIOCS" | (
    while read IOC PORT IOCARGS; do
        if [ "$IOC" != "autoProcServControl" ]; then
            cat <<EOF >> $ST_FILE
seq(procServControl,"P=${IOC}")
EOF
        fi
    done
)

# Now start the IOC
exec ./autoProcServControl $ST_FILE
