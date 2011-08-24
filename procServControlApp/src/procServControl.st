program procServControl("P=P")

%% #include <stdio.h>
%% #include <stdlib.h>
%% #include <string.h>
%% #include <unistd.h>
option +r;

/* This defines the number of lines and max line length */
#define LINELENGTH 256
#define NLINES 20

/* This is LINELENGTH*NLINES. It must match NELM on the IOCOUT and
 * PROCOUT waveform records */
#define NELM 5120

/* Inputs */
string port;			assign port			to "{P}:PORT";

/* Outputs */
string iocname;			assign iocname		to "{P}:IOCNAME";
int autorestart;		assign autorestart	to "{P}:AUTORESTART";
int status;				assign status		to "{P}:STATUS";
#define RUNNING 0
#define SHUTDOWN 1
#define PROCSERVSTOPPED 2
char iocout[NELM];		assign iocout		to "{P}:IOCOUT";

/* Commands */
int start;				assign start 		to "{P}:START";
int stop;				assign stop 		to "{P}:STOP";
int restart;			assign restart 		to "{P}:RESTART";
int toggle;				assign toggle 		to "{P}:TOGGLE";

/* Flags */
monitor start;			evflag startMon;	sync start startMon;
monitor stop;			evflag stopMon;		sync stop stopMon;
monitor restart;		evflag restartMon;	sync restart restartMon;
monitor toggle;			evflag toggleMon;	sync toggle toggleMon;

/* Internal variables for storing output lines*/
char iocLine[NLINES][LINELENGTH];
int iocLineI;
int lastcommand;
#define NONE 0
#define IOCOUT 1
#define AUTORESTART 2
#define IOCNAME 3
#define STATUS 4

/* These are needed to tie up the ppasynUser with the state machine */
int stateIndex;
#define NSTATEMACHINES 256
%% static int stateIndexGlobal = 0;

/* C functions and asyn things */
%% #include <asynOctetSyncIO.h>
%% static asynUser* pasynUsers[NSTATEMACHINES];
%% static void createAsynUser(struct UserVar *pVar);
%% static void getNextLine(struct UserVar *pVar);
%% static void writeControlChar(struct UserVar *pVar, const char *controlChar);

ss ssUserInput {
	state INIT {
		entry {
		}
		
		when() {
			/* Clear all event flags */
			efClear(startMon);
			efClear(stopMon);
			efClear(restartMon);
			efClear(toggleMon);			
		} state MONITORINPUTS		
	}
	
	state MONITORINPUTS {
	
		entry {
		}
		
		when(efTestAndClear(startMon) && (start == 1)) {
			if (status == SHUTDOWN) {
				%% writeControlChar(pVar, "\x18");
			}			
            start = 0;
            pvPut(start, SYNC);			
		} state MONITORINPUTS
		
		when(efTestAndClear(stopMon) && (stop == 1)) {
			if (status == RUNNING) {		
				if (autorestart == 1) {
					%% writeControlChar(pVar, "\x14");
				}			
				%% writeControlChar(pVar, "\x18");				
			}
            stop = 0;
            pvPut(stop, SYNC);					
		} state MONITORINPUTS
		
		when(efTestAndClear(restartMon) && (restart == 1)) {
			if (status == RUNNING) {		
				if (autorestart == 0) {
					%% writeControlChar(pVar, "\x14");
				}			
				%% writeControlChar(pVar, "\x18");				
			}
            restart = 0;
            pvPut(restart, SYNC);		
		} state MONITORINPUTS

		when(efTestAndClear(toggleMon) && (toggle == 1)) {
			if (status == RUNNING) {		
				%% writeControlChar(pVar, "\x14");
			}
            toggle = 0;
            pvPut(toggle, SYNC);			
		} state MONITORINPUTS
	}
}		

ss ssProcServInput {
	state INIT {
		entry {
		}
		
		when() {
			/* Get the asyn port name */
			pvGet(port, SYNC); 
			/* Connect the asyn port */
			%% createAsynUser(pVar);
		} state MONITORINPUTS		
	}
	
	state MONITORINPUTS {
	
		entry {
		}
		
		when() {
			/* This sets lastcommand state */
			%% getNextLine(pVar);						
		} state PROCESSINPUT
	}
	
	state PROCESSINPUT {
		entry {
		}

		when(lastcommand == NONE) {
		} state MONITORINPUTS
		
		when(lastcommand == IOCOUT) {
			pvPut(iocout, SYNC);					
		} state MONITORINPUTS
		
		when(lastcommand == AUTORESTART) {
			pvPut(autorestart, SYNC);
			pvPut(iocout, SYNC);			
		} state MONITORINPUTS
		
		when(lastcommand == IOCNAME) {
			pvPut(iocname, SYNC);
			pvPut(iocout, SYNC);			
		} state MONITORINPUTS
		
		when(lastcommand == STATUS) {
			pvPut(status, SYNC);
			pvPut(iocout, SYNC);			
		} state MONITORINPUTS		
	}
}	
	
/* C functions */
%{
static void createAsynUser(struct UserVar *pVar) {
	int i;
	pVar->stateIndex = stateIndexGlobal++;
	if (stateIndexGlobal > NSTATEMACHINES) {
		printf("***Error: too many procServ state machines defined\n");
		return;
	}
	asynUser *pasynUser = NULL;
	pasynOctetSyncIO->connect(pVar->port, 0, &pasynUser, NULL);
	pasynOctetSyncIO->setInputEos(pasynUser, "\r\n", 2);
	pasynOctetSyncIO->setOutputEos(pasynUser, "", 0);			
	pasynUsers[pVar->stateIndex] = pasynUser;	
	for (i = 0; i < NLINES; i++) {
		strcpy(pVar->iocLine[i], "");				
	}			
	pVar->iocLineI = 0;	
}			

static void getNextLine(struct UserVar *pVar) {
	asynUser *pasynUser = pasynUsers[pVar->stateIndex];
	char buffer[LINELENGTH];
	char temp[LINELENGTH];
	size_t bytes;
	int eomReason;
	int i, index, yesNo;
	
	/* Check asynUser is connected */
	pasynManager->isConnected(pasynUser, &yesNo);
	if (yesNo == 0) {
		if (pVar->status == PROCSERVSTOPPED) {
	    	pVar->lastcommand = NONE;
			sleep(1);		    	
	    } else {
		    pVar->status = PROCSERVSTOPPED;
	    	pVar->lastcommand = STATUS;
	    }
		return;
	} else if (pVar->status == PROCSERVSTOPPED) {
		/* need to set the right eos */
		pasynOctetSyncIO->setInputEos(pasynUser, "\r\n", 2);
		pasynOctetSyncIO->setOutputEos(pasynUser, "", 0);	
		pVar->status = SHUTDOWN;	
	}
	
	/* read from the asyn port and NULL terminate it, then copy to lines */
    if (pasynOctetSyncIO->read(pasynUser, buffer, LINELENGTH, 0.1, &bytes, &eomReason)) {
    	pVar->lastcommand = NONE;
    	return;    
    }
    buffer[LINELENGTH-1] = '\0';
	strcpy(pVar->iocLine[pVar->iocLineI], buffer);
	    
    /* put the \n joined strings into the iocout array */
	pVar->iocLineI = (pVar->iocLineI + 1) % NLINES;
	bytes = 0;
	for (i = 0; i < NLINES; i++) {
		index = (pVar->iocLineI + i)%NLINES;
		strcpy(pVar->iocout + bytes, pVar->iocLine[index]);
		bytes += strlen(pVar->iocLine[index]);
		sprintf(pVar->iocout + bytes++, "\n");
	}            	
	pVar->lastcommand = IOCOUT;    
	
	/* If it was a procServ command, parse it */ 
    if (buffer[0] == '@' && buffer[1] == '@' && buffer[2] == '@') {
    	/* grab ioc name */
    	if (sscanf(buffer, "@@@ Child \"%s started as: %s", pVar->iocname, temp) == 2) {
    		pVar->iocname[strlen(pVar->iocname)-1] = '\0';
    		pVar->lastcommand = IOCNAME;
    		return; 
    	}
    	/* grab current status */
    	if (sscanf(buffer, "@@@ Child \"%*s %s", temp)) {
    		if (strcmp(temp, "PID:") == 0) {
    			pVar->status = RUNNING;
    		} else if (strcmp(temp, "is") == 0) {
    			pVar->status = SHUTDOWN;
    		} else {
    			return;
    		}
    		pVar->lastcommand = STATUS;    		
    		return; 
    	}
    	if (sscanf(buffer, "@@@ Restarting child %s", temp)) {
    		pVar->lastcommand = STATUS;
   			pVar->status = RUNNING;
    		return; 
    	}
    	if (sscanf(buffer, "@@@ Child process is shutting %s", temp)) {
    		pVar->lastcommand = STATUS;
   			pVar->status = SHUTDOWN;
    		return; 
    	}
    	/* grab current autorestart */
    	if (sscanf(buffer, "@@@ Toggled auto restart to %s", temp)) {
    		pVar->lastcommand = AUTORESTART;
    		if (strcmp(temp, "ON") == 0) {
    			pVar->autorestart = 1;
    		} else {
    			pVar->autorestart = 0;
    		}
    		return; 
    	}    
    	if (sscanf(buffer, "@@@ Use ^X to kill the child, auto restart is %s", temp)) {
    		pVar->lastcommand = AUTORESTART;
    		if (strcmp(temp, "ON,") == 0) {
    			pVar->autorestart = 1;
    		} else {
    			pVar->autorestart = 0;
    		}
    		return; 
    	}      		    	
    }
}    
   	
static void writeControlChar(struct UserVar *pVar, const char *controlChar) {
	size_t bytes;
	asynUser *pasynUser = pasynUsers[pVar->stateIndex];
	int yesNo;
	
	/* Check asynUser is connected */
	pasynManager->isConnected(pasynUser, &yesNo);
	if (yesNo == 0) {
		return;
	}	
	
	pasynOctetSyncIO->write(pasynUser, controlChar, 1, 1.0, &bytes);
}	

}%
	
				
