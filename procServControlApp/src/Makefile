TOP=../..

include $(TOP)/configure/CONFIG

# -------------------------------
# Build an Diamond Support Module
# -------------------------------

LIBRARY_IOC += procServControl

# xxxRecord.dbd will be installed into <top>/dbd
DBD += procServControl.dbd

# The following are compiled and added to the support library
procServControl_SRCS += procServControl.st

# We need to link against the EPICS Base libraries
procServControl_LIBS += $(EPICS_BASE_IOC_LIBS)

include $(TOP)/configure/RULES
