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

- A patch is required to procServ v2.7.0 to change the restart-character from `^R` to `^X`:
```
diff -ur procServ-2.7.0/procServ.cc procServ-2.7.0-patched/procServ.cc
--- procServ-2.7.0/procServ.cc	2017-01-18 14:30:17.000000000 +0000
+++ procServ-2.7.0-patched/procServ.cc	2018-12-06 11:11:12.173337693 +0000
@@ -60,7 +60,7 @@
 char   *ignChars = NULL;         // Characters to ignore
 char   killChar = 0x18;          // Kill command character (default: ^X)
 char   toggleRestartChar = 0x14; // Toggle autorestart character (default: ^T)
-char   restartChar = 0x12;       // Restart character (default: ^R)
+char   restartChar = 0x18;       // Restart character (default: ^X)
 char   quitChar = 0x11;          // Quit character (default: ^Q)
 char   logoutChar = 0x00;        // Logout client connection character (default: none)
 int    killSig = SIGKILL;        // Kill signal (default: SIGKILL)
```

## Example IOC startup

```bash
dbLoadDatabase "dbd/autoProcServControl.dbd"
drvAsynIPPortConfigure("IOC1port", "localhost:7001", 100, 0, 0)
dbLoadRecords "${PROCSERVCONTROL}/db/procServControl.template", "P=PV_PREFIX,PORT=IOC1port"
```
