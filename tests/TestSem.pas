uses use32, os2base, os2SysLib, Crt;

const
    MustDie : boolean = FALSE;

var testSem : tMutexSem;

function myThread(Parm : Pointer) : longint;
var i : Integer;
begin
 repeat
  fmsRequest(testSem);
  textAttr := byte(Parm);
  For I := 0 to 9 do
   begin
    Write(I);
    DosSleep(0);                      {Give other threads more chances to run}
   end;
  fmsRelease(testSem);
 until MustDie;
 EndThread(0);
end;

var a   : longint;
    pid : array[0..15] of Longint;

begin
 fmsInit(testSem);
 for a := 1 to 15 do
  BeginThread(nil, 8192, myThread, pointer(a), create_Ready, pid[a]);
 ReadKey;
 mustDie := TRUE;
 for a := 1 to 15 do
  DosWaitThread(pid[a], dcww_Wait);
end.

