uses use32, os2base, Crt;

const
    MustDie : boolean = FALSE;

var testSem : hMUX;

function myThread(Parm : Pointer) : longint;
var i : Integer;
begin
 repeat
  DosRequestMutexSem(testSem, sem_Indefinite_Wait);
  textAttr := byte(Parm);
  For I := 0 to 9 do
   begin
    Write(I);
    DosSleep(0);                      {Give other threads more chances to run}
   end;
  DosReleaseMutexSem(testSem);
 until MustDie;
 EndThread(0);
end;

var a   : longint;
    pid : array[0..15] of Longint;

begin
 if DosCreateMutexSem(nil, testSem, dc_Sem_Shared, FALSE) <> 0 then Halt;
 for a := 1 to 15 do
  BeginThread(nil, 8192, myThread, pointer(a), create_Ready, pid[a]);
 ReadKey;
 mustDie := TRUE;
 for a := 1 to 15 do
  DosWaitThread(pid[a], dcww_Wait);
end.

