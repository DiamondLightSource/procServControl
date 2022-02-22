# procServControl

Support module to provide control over procServ instances in EPICS.

The most important PVs provided are:

$(P):START - Start IOC

$(P):STOP - Stop IOC

$(P):RESTART - Restart IOC

$(P):IOCOUT - Last 20 lines of IOC output

## Requirements

- This expects procServ version 2.7.0, but earlier versions should work.

- The version of EPICS base tested was R3.12.14.7, but any version will work.

- Asyn can be used for establishing the TCP/IP connection to procServ. Any version
 of Asyn will work.

## Example IOC startup

```bash
dbLoadDatabase "dbd/autoProcServControl.dbd"
drvAsynIPPortConfigure("IOC1port", "localhost:7001", 100, 0, 0)
dbLoadRecords "${PROCSERVCONTROL}/db/procServControl.template", "P=PV_PREFIX,PORT=IOC1port"
```
