uses os2def, os2base, os2SysLib;

const
    mustDie : boolean = FALSE;
    t1count : Longint = 0;
    t2count : Longint = 0;

function Thread1(Parm : Pointer) : longint;
var sem : tMutexSem;
begin
 fmsInit(sem);
 repeat
  fmsRequest(sem);
  fmsRequest(sem);
  fmsRelease(sem);
  fmsRelease(sem);
  Inc(t1count);
 until mustDie;
 EndThread(0);
end;

function Thread2(Parm : Pointer) : longint;
var sem : hMtx;
begin
 if DosCreateMutexSem(nil, sem, 0, FALSE) = 0
  then
 repeat
  DosRequestMutexSem(sem, sem_Indefinite_Wait);
  DosRequestMutexSem(sem, sem_Indefinite_Wait);
  DosReleaseMutexSem(sem);
  DosReleaseMutexSem(sem);
  Inc(t2count);
 until mustDie;
 EndThread(0);
end;

var TimeSem : hEv;
    Timer   : hTimer;
    tid     : Longint;

begin
 if DosCreateEventSem(nil, TimeSem, dc_Sem_Shared, FALSE) <> 0 then Halt;

 Write('Please wait...');
 BeginThread(nil, 8192, Thread1, nil, create_Ready, tid);

 if DosAsyncTimer(5000, hSem(TimeSem), Timer) <> 0 then Halt;
 DosWaitEventSem(TimeSem, sem_Indefinite_Wait);
 mustDie := TRUE; DosWaitThread(tid, dcww_Wait);

 Write(' be patient...');
 mustDie := FALSE; DosResetEventSem(TimeSem, tid);
 BeginThread(nil, 8192, Thread2, nil, create_Ready, tid);

 if DosAsyncTimer(5000, hSem(TimeSem), Timer) <> 0 then Halt;
 DosWaitEventSem(TimeSem, sem_Indefinite_Wait);
 mustDie := TRUE; DosWaitThread(tid, dcww_Wait);

 Writeln;
 Writeln('Fast semaphores: ', (t1count*2)/5:1:2, ' transactions per second');
 Writeln('OS/2 semaphores; ', (t2count*2)/5:1:2, ' transactions per second');
 Writeln('Fast sem/OS2 sem ratio = ', t1count/t2count:1:2);
end.

