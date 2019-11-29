#!/bin/sh
# go to the bin/arch directory
cd "$(dirname "$0")"
# globals
INIT_ROOT=/dls_sw/prod/etc/init
source $INIT_ROOT/functions
SOFTIOCS=$(GetConfigDir $INIT_ROOT)/soft-iocs
REALIOCS=$(GetConfigDir $INIT_ROOT)/real-iocs
ST_FILE="/tmp/stautoProcServControl.cmd"
ASYN_DB_FILE="/tmp/asyndb.cmd"
SEQ_FILE="/tmp/seq.cmd"
TOP=$(cd ../..; pwd)
PROCSERVCONTROL=$(cd ../../../..; pwd)

# Make a startup script, first the header
cat <<EOF > $ASYN_DB_FILE
cd $TOP
epicsEnvSet "EPICS_TS_MIN_WEST", '0'
dbLoadDatabase "dbd/autoProcServControl.dbd"
autoProcServControl_registerRecordDeviceDriver(pdbbase)
EOF

# IocInit
echo iocInit >> $SEQ_FILE


sed '/^#/d;/^\s*$/d' "$SOFTIOCS" | (
    while read IOC PORT IOCARGS; do
        # Make asyn ports and database bits
        if [ "$IOC" != "autoProcServControl" ]; then
            cat <<EOF >> $ASYN_DB_FILE
drvAsynIPPortConfigure("${IOC}port", "localhost:${PORT}", 100, 0, 0)
dbLoadRecords "${PROCSERVCONTROL}/db/procServControl.template", "P=${IOC},PORT=${IOC}port"
EOF
            # Sequencers
            cat <<EOF >> $SEQ_FILE
seq(procServControl,"P=${IOC}")
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
                # Make asyn ports and database bits
                cat <<EOF >> $ASYN_DB_FILE
drvAsynIPPortConfigure("${IOC}port", "${HOST}:${PORT}", 100, 0, 0)
dbLoadRecords "${PROCSERVCONTROL}/db/procServControl.template", "P=${IOC},PORT=${IOC}port"
EOF
                # Sequencers
                cat <<EOF >> $SEQ_FILE
seq(procServControl,"P=${IOC}")
EOF
            # Or we look for a soft-iocs entry in the Windows host
            elif [ -s $INIT_ROOT/$HOST/soft-iocs ]; then
                sed '/^#/d;/^\s*$/d' $INIT_ROOT/$HOST/soft-iocs | (
                    while read HOSTIOC HOSTPORT HOSTIOCARGS; do
                        if [ "${HOSTIOC,,}" == "${IOC,,}" -a "$PORT" == "$HOSTPORT" ]; then
                            # Make asyn ports and database bits
                            cat <<EOF >> $ASYN_DB_FILE
drvAsynIPPortConfigure("${IOC}port", "${HOST}:${PORT}", 100, 0, 0)
dbLoadRecords "${PROCSERVCONTROL}/db/procServControl.template", "P=${IOC},PORT=${IOC}port"
EOF
                            # Sequencers
                            cat <<EOF >> $SEQ_FILE
seq(procServControl,"P=${IOC}")
EOF
                        fi
                    done
                )
            fi
        done
    )
fi

# merge asyn_db and seq files together and add to ST_FILE
cat $ASYN_DB_FILE $SEQ_FILE > $ST_FILE

# Now start the IOC
exec ./autoProcServControl $ST_FILE
