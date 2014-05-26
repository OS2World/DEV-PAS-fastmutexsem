{$A-,B-,D+,E-,F-,G-,I-,L+,N-,O-,P-,Q-,R-,S-,T-,V-,X+,Y+}
{&AlignCode-,AlignData-,AlignRec-,Asm-,Cdecl-,Delphi+,W-,Frame-,G3+}
{&LocInfo+,Optimise+,OrgName-,SmartLink+,Speed-,Z-,ZD-}
Unit os2SysLib;

Interface uses os2def, os2base;

type
    { Fast MUTEX semaphore type }
      tMutexSem = record
       Next  : Pointer;                { Next thread ID requesting ownership }
       Owner : TID;     { Current semaphore owner; bit 31 = semaphore in use }
       Count : Longint;                   { For recursive semaphore requests }
      end;

{ Initialize an [F]ast [M]utex [S]emaphore }
 Function  fmsInit(var Sem : tMutexSem) : boolean;
{ Request a semaphore; wait until semaphore is available }
 Function  fmsRequest(var Sem : tMutexSem) : boolean;
{ Release semaphore; return TRUE if o.k.; FALSE if caller is not owner }
 Function  fmsRelease(var Sem : tMutexSem) : boolean;
{ Check if semaphore is owned; DO NOT RELY ON THIS! }
 Function  fmsCheck(var Sem : tMutexSem) : boolean;

Implementation

function fmsInit; assembler {&uses none};
asm             mov     ecx,Sem
           lock bts     [ecx].tMutexSem.Owner,31      {Lock semaphore updates}
                jnc     @@ok
                mov     al,0
                ret     4
@@ok:           xor     eax,eax
                mov     [ecx].tMutexSem.Next,eax
           lock xchg    [ecx].tMutexSem.Owner,eax
                mov     al,1
end;

function fmsRequest; assembler {&uses none};
asm             mov     eax,fs:[12]            {Get ^Thread Information Block}
                push    dword ptr [eax]                      {Owner : Longint}
                push    eax                                   {Next : Pointer}
@@testSem:      mov     ecx,Sem[4+4]                      {+4+4 since &frame-}
           lock bts     [ecx].tMutexSem.Owner,31
                jnc     @@semFree
                push    0          {There is no hurry since semaphore is busy}
                call    DosSleep                  {Go to sleep for a while...}
                add     esp,4
                jmp     @@testSem

@@semFree:      mov     edx,[ecx].tMutexSem.Owner        {Get semaphore owner}
                btr     edx,31                     {Reset `semaphor busy` bit}
                cmp     edx,[esp+4]                     {Owner = current TID?}
                jne     @@notOur
                inc     [ecx].tMutexSem.Count
           lock btr     [ecx].tMutexSem.Owner,31           {Release semaphore}
                add     esp,4+4
                mov     al,1
                ret     4

@@notOur:       mov     eax,esp
                xchg    eax,[ecx].tMutexSem.Next
                test    edx,edx                                   {Owner = 0?}
                jz      @@notBusy
                mov     [esp],eax                              {Save ^nextTID}
           lock btr     [ecx].tMutexSem.Owner,31           {Release semaphore}
                push    dword ptr [esp+4]                            {Our TID}
                call    SuspendThread                     {Sleep until wakeup}
                add     esp,4+4
                mov     al,1
                ret     4

@@notBusy:      xchg    eax,[ecx].tMutexSem.Next
                inc     edx
                mov     [ecx].tMutexSem.Count,edx          {Request count = 1}
                pop     eax                                    {Skip ^nextTID}
                pop     eax
           lock xchg    [ecx].tMutexSem.Owner,eax {Set owner&unlock semaphore}
                mov     al,1
end;

function fmsRelease; assembler {&uses none};
asm
@@testSem:      mov     ecx,Sem
           lock bts     [ecx].tMutexSem.Owner,31      {Lock semaphore updates}
                jnc     @@semFree
                push    0
                call    DosSleep
                add     esp,4
                jmp     @@testSem
@@semFree:      mov     eax,fs:[12]
                mov     eax,[eax]
                bts     eax,31              {Set bit 31 in EAX for comparison}
                cmp     eax,[ecx].tMutexSem.Owner
                je      @@isOur
           lock btr     [ecx].tMutexSem.Owner,31           {Release semaphore}
                mov     al,0
                ret     4

@@isOur:        dec     [ecx].tMutexSem.Count             {Request count = 1?}
                jz      @@scanChain
           lock btr     [ecx].tMutexSem.Owner,31           {Release semaphore}
                mov     al,1
                ret     4

@@scanChain:    mov     edx,eax
                mov     eax,ecx
                mov     ecx,[ecx].tMutexSem.Next                    {^nextTID}
                test    ecx,ecx
                jnz     @@scanChain
                mov     ecx,Sem
                cmp     eax,ecx
                je      @@onlyOwner                  {Thread is only in chain}
                mov     [edx].tMutexSem.Next,0      {Remove thread from chain}
                mov     [ecx].tMutexSem.Count,1       {Set request count to 1}
                mov     eax,[eax].tMutexSem.Owner
                push    eax                          {ResumeThread(TID = EAX)}
           lock xchg    [ecx].tMutexSem.Owner,eax{Make thread semaphore owner}
                call    ResumeThread                          {Wake up thread}
                mov     al,1
                ret     4

@@onlyOwner:    xor     eax,eax
           lock xchg    eax,[ecx].tMutexSem.Owner
                mov     al,1
end;

function fmsCheck; assembler {&uses none};
asm             mov     eax,Sem
                mov     eax,[eax].tMutexSem.Owner
                and     eax,7FFFFFFFh
                setz    al
end;

end.

