from iocbuilder import AutoSubstitution, Device
from iocbuilder.modules.asyn import Asyn
from iocbuilder.modules.seq import Seq
from iocbuilder.modules.busy import Busy

class procServControl(AutoSubstitution, Device):
    '''Controls the procServ for an IOC'''

    Dependencies = (Asyn,Seq,Busy)
    LibFileList = ["procServControl"]
    DbdFileList = ["procServControl"]

    ## Parse this template file for macros
    TemplateFile = 'procServControl.template'

    def PostIocInitialise(self):
        print 'seq(procServControl,"P=%(P)s")' % self.args

class procServControlGui(AutoSubstitution):
    TemplateFile = 'procServControlGui.template'
    
