#!/bin/sh
# go to the bin/arch directory
cd "$(dirname "$0")"
# globals
INIT_ROOT=/dls_sw/prod/etc/init
source $INIT_ROOT/functions
SOFTIOCS=$(GetConfigDir $INIT_ROOT)/soft-iocs
REALIOCS=$(GetConfigDir $INIT_ROOT)/real-iocs
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

# Check the real-iocs file for soft-iocs (Windows IOCs run through WinProcServ)
if [ -s "$REALIOCS" ]; then
    sed '/^#/d;/^\s*$/d' "$REALIOCS" | (
        while read IOC HOST PORT IOCARGS; do
            # softioc argument in column 4 provided
            if [ "$IOCARGS" == "softioc" ]; then
                cat <<EOF >> $ST_FILE
drvAsynIPPortConfigure("${IOC}port", "${HOST}:${PORT}", 100, 0, 0)
dbLoadRecords "${PROCSERVCONTROL}/db/procServControl.template", "P=${IOC},PORT=${IOC}port"
EOF
            # Or we look for a soft-iocs entry in the Windows host
            elif [ -s $INIT_ROOT/$HOST/soft-iocs ]; then
                sed '/^#/d;/^\s*$/d' $INIT_ROOT/$HOST/soft-iocs | (
                    while read HOSTIOC HOSTPORT HOSTIOCARGS; do
                        if [ "${HOSTIOC,,}" == "${IOC,,}" -a "$PORT" == "$HOSTPORT" ]; then
                            cat <<EOF >> $ST_FILE
drvAsynIPPortConfigure("${IOC}port", "${HOST}:${PORT}", 100, 0, 0)
dbLoadRecords "${PROCSERVCONTROL}/db/procServControl.template", "P=${IOC},PORT=${IOC}port"
EOF
                        fi
                    done
                )
            fi
        done
    )
fi

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

if [ -s "$REALIOCS" ]; then
    sed '/^#/d;/^\s*$/d' "$REALIOCS" | (
        while read IOC HOST PORT IOCARGS; do
            if [ "$IOCARGS" == "softioc" ]; then
                cat <<EOF >> $ST_FILE
seq(procServControl,"P=${IOC}")
EOF
            elif [ -s $INIT_ROOT/$HOST/soft-iocs ]; then
                sed '/^#/d;/^\s*$/d' $INIT_ROOT/$HOST/soft-iocs | (
                    while read HOSTIOC HOSTPORT HOSTIOCARGS; do
                        if [ "$HOSTIOC" == "$IOC" -a "$PORT" == "$HOSTPORT" ]; then
                            cat <<EOF >> $ST_FILE
seq(procServControl,"P=${IOC}")
EOF
                        fi
                    done
                )
            fi
        done
    )
fi

# Now start the IOC
exec ./autoProcServControl $ST_FILE
