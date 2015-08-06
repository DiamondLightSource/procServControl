TOP = ../..
include $(TOP)/configure/CONFIG

PROD_IOC = autoProcServControl
DBD += autoProcServControl.dbd
autoProcServControl_DBD += base.dbd
autoProcServControl_DBD += asyn.dbd
autoProcServControl_DBD += drvAsynIPPort.dbd
autoProcServControl_DBD += busySupport.dbd
autoProcServControl_DBD += procServControl.dbd
autoProcServControl_SRCS += autoProcServControl_registerRecordDeviceDriver.cpp
autoProcServControl_LIBS += procServControl
autoProcServControl_LIBS += busy
autoProcServControl_LIBS += seq
autoProcServControl_LIBS += pv
autoProcServControl_LIBS += asyn
autoProcServControl_LIBS += $(EPICS_BASE_IOC_LIBS)
autoProcServControl_SRCS += autoProcServControlMain.cpp

include $(TOP)/configure/RULES

