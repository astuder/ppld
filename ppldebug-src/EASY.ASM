; Easy.ASM
; Lotsa routines.. No one knows what kind of
 
F8change        db      0               ; if goto in line then just wait on
                                        ; change of linenumba.
f8changefrom    dw      0
                         
F8stop          db      0
F8waitfor       dw      0         
                          
oldint9         dd      0
                        
BotBar          db      '  f2 - Set Breakpoints f4 - Here  f7 - Trace  f8 - Step over  ctrl+brk - Halt   ',0
TopBar          db      'pplDebug '
                db      PPLDver, ' '    ; 6
                db      date            ; 5
                db      '             (c)1995/96 by eULE! and Chicken / Tools 4 Fools',0
                                                                                                       
; Symbolic file header start
SymHeaderStart  equ     $
SymHeaderSize   equ     24                  
SymRevisionNum  equ     1                  
                         
SymMagic        db      'SYM'
SymRevision     db      1               ; No kind of downwards compatibility
SymSize         dw      0, 0
SymSource       dw      0, 0            ; far on source.
SymIndex        dw      0, 0            ; far on conversion table of offsets to line numbers.
SymVars         dw      0, 0            ; far on table of variable number string conversion
SymFuncs        dw      0, 0            ; far on sourceoffset of functions table.
; End of header                                        
                                          
Magic           db      'SYM'           ; compare here.
SymAborted      db      0               ; != 0 when int9 not hooked and no rek flag set. Do not deinstall or .. fuckup               
SymHandle       dw      0               ; file handle of SYM
                                                           
SymLines        dw      0                                  
AktH            dw      0               ; left - right scrolling
AktLine         dw      0               ; akt cursor line  
pIP             dw      0               ; real command couter. 
                                                           
SymText         dw      0,0             ; far on beginning of Symbolic file segment
MaxFree         dw      0               ; maximum segments found 
PPERestart      db      0               ; Ctrl und F2 - restart ppe..
                                                           
RevisionError   db      'Symbolic file is either garbage or another revision.', 0
FileProblems    db      'Fatal File Error.', 0     
NotEnoughMem    db      'Out of memory error.', 0  
CouldNotOpen    db      'Could not open symbolic file', 0
PressKey	db	'Press any key to abort debugging.', 0
                                               
MemString       db      "Segments Free Mem Found!",0       
MemString2      db      "Segments Allocated!",0

MinDispStart	equ	0
MaxDispLines	equ	21
SourceDispS    	db	MinDispStart 	; start disp of source code ?
SourceDispLines	db	MaxDispLines	; Count of lines to display
                                                                  
WindowFlag	db	0		; bit 1 : Var-part or other ?
					; bit 2 : Wherefrom take VarNums
DebugInfo proc near                                   
                                                      
                pusha                                 
                push    ds                            
                push    es                            
                                                      
                                                      
                mov     di,160*27                     
                push    cs                            
                pop     ds                            
                mov     si,offset PPESegStr           
                mov     ah,Color2                     
                xor     bp, bp                        
                call    outputstring                  
                                                      
                mov     di,160*27+28                  
                mov     ax,es 
                mov     dl,Color2
                call    outputhex              
                                                                        
                push    cs    
                pop     ds    
                mov     si,offset PPEOfsStr
                mov     ah,Color2
                call    outputstring 
                                           
                add     di,2  
                mov     ax,bx 
                mov     dl,Color2
                call    outputhex        
                              
                pop     es    
                pop     ds    
                popa                         
                
                ret           
                              
PPESegStr       db      "PPE Position: ",0
PPEOfsStr       db      ":",0     
                                               
DebugInfo endp                    
                                  
;--------------------------------------------------------------------
;ID von PPE im Segment ES ermitteln + speichern
;--------------------------------------------------------------------
                                  
SaveID proc near                  
                                  
                mov     cs:PPE_ID,es             
                ret               
                                  
PPE_ID          dw      0         
PPE_IP          dw      0               ; real ip in offset, not line.
                                  
SaveID endp                       
                                  
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같
; intr 9 - Keyboard interrupt hook. (temp)                                   
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같
HookIn proc near        ; should dest nothing  
                push    es        
                push    ds        
                push    bx        
                push    dx                 
                push    ax        
                                     
                mov     ax, 3509h 
                int     21h       
                                  
                mov     word ptr cs:oldint9[2], es
                mov     word ptr cs:oldint9[0], bx
                                  
                mov     bx, cs                                        
                mov     ds, bx    
                mov     dx, offset int9
                mov     ax, 2509h 
                int     21h       
                                  
                pop     ax        
                pop     dx                     
                pop     bx        
                pop     ds        
                pop     es                 
                ret               
endp HookIn                       
                                     
HookOut proc near                 
                                  
                push    ds        
                push    dx                       
                push    ax        
                                  
                mov     ds, word ptr cs:oldint9[2]
                mov     dx, word ptr cs:oldint9[0]
                mov     ax, 2509h 
                int     21h       
@@Abort:                     
                pop     ax        
                pop     dx   
                pop     ds                     
                ret          
endp Hookout                               
                   
; and this one does in contrary to win95 what it says and just that.
int9 		proc 		; interrupt                    
                   
                pushf        
                call    dword ptr cs:oldint9
                                     
                push    ax      
                push    bx      
                push    es       
                                                 
                mov     bx, 40h  
                mov     es, bx   
                mov     bx, es:[1ah]
                mov     ax, es:[bx]                    
                                 
                cmp     ax, 0000h          ; ctrl+brk
                jne     @@normkey                 
                                           
                mov     ax, es:[1ch]
                mov     es:[1ah], ax       ; del keys
                                
                push    es     
                mov     ax, 40h
                mov     es, ax 
                mov     byte ptr es:[49h], 83h          ; eat this asshole. CTRL BREAK sets this on something weird.
                pop     es		; no more messing up with my screen..
                               
                mov     cs:trace, 1        ; only switch on here. Comes first, ev. switched off then in Keyroutine
                mov     cs:f8stop, 0       ; no f8/f4 bpoints anymore     
                mov     cs:f8Change, 0     ; do not wait for change either.
@@normkey:                     
                                     
                pop     es     
                pop     bx     
                pop     ax     
                iret           
endp int9                                        
;--------------------------------------------------------------------
;80x50 mode setzen           
;--------------------------------------------------------------------
                                
InitScreen proc near            
                                  
                pusha           
                push    es      
                push    ds      
                                     
                mov     ax, 83h
                int     10h             ; avoid deleting   
                mov     ax,1112h                        
                int     10h             ; 80x50
                                                    
                mov     ax,0b800h   
                mov     es,ax       
                mov     cx,80*25    
                xor     ax,ax                    
                mov     di,80*25*2  
                rep     stosw       
                                    
                push    cs          
                pop     ds          
                mov     si,offset TopBar
                mov     di,80*25*2  
                mov     ah,Color1   
                xor     bp, bp  
                call    outputstring 
                                    
                mov     si,offset BotBar
                mov     di,80*49*2       
                mov     ah,Color1
                call    outputstring                                                    
                                
                pop     ds      
                pop     es    
                popa                       
                ret                              
                                                      
                                                     
InitScreen endp                                      
                                                     
;--------------------------------------------------------------------
;ds:dx = filename of symbolic file                   
;--------------------------------------------------------------------
                                                     
LoadSymbolic    proc near                               
                locals                                     
                              
                pusha                                
                push    ds                           
                push    es                           
                                                                                        
                mov     cs:SymText[2], 0
                              
                mov     ax,3d00h                     
                int     21h                          
                mov     bp, offset CouldNotOpen
                jc      short @@failed                     
                mov     cs:SymHandle, ax
                                                     
                call    AllocIt                      
                jc      short @@failed2
                              
                call    LoadIt    
                jc      short @@failed3
                              
                call    InitIt
	    	call 	initvar		; get the maxVar
@@harmlos:                          
                mov     cs:SymAborted, 0
                clc          
                pop     es   
                pop     ds     
                popa                       
                ret         
                             
@@failed3:      mov     ah, 49h
                mov     es, cs:SymText[2]
                int     21h                     ; free mem                      
                            
@@failed2:      mov     ah, 3eh
                mov     bx, cs:SymHandle        
                int     21h                     ; close file before abort
                          
@@failed:       mov     di,160*30
                push    cs       
                pop     ds       
                mov     si, bp    
                mov     ah, Color2    
                xor     bp, bp    
                call    outputstring
                mov	di, 160*31
                mov	si, offset Presskey
                call	outputstring
                                 
                mov     cs:SymAborted, -1                  
                                                           
@@endfail:      stc            
                pop     es           
                pop     ds    
                popa          
                ret                     
                              
                                                 
LoadSymbolic endp             
                              
; carry und bp = offset errormsg
AllocIt proc near               ; Allocate Memory for PPE and load header.
                push    ds    
                mov     ax, cs
                mov     ds, ax
                                    
                mov     cs:SymText[2], 0
                
                mov     ax, 5800h   
                int     21h             ; get UMB link state 
                push    ax                                  
                                       
                mov     ax, 5801h      
                mov     bx, 02h         
                int     21h             ; link UMBs    
                                                   
                mov     ah, 48h         
                mov     bx, -1            
                int     21h             
                mov     cs:MaxFree, bx  
                                        
                mov     di,160*26       
                mov     ax,bx           
                mov     dl,Color2                
                call    outputhex       
                                    
                add     di,2    
                push    cs      
                pop     ds      
                mov     si,offset MemString
                mov     ah,Color2
                xor     bp, bp  
                call    outputstring
                
                call    LoadHeader
                jc      @@fatal               ; falsche Version/Corrupted File
                                     
                mov     ax, cs:SymSize
                shr     ax, 4   
                mov     bx, cs:SymSize+2
                shl     bx, 12  
                add     bx, ax          
                inc     bx                      ; shr Size of File and round up
                                  
                mov     ah, 48h
                int     21h                     ; Allocate Symbolic Memory.  
                jc      short @@failed2
                mov     cs:SymText[2], ax       ; save segment in SymText
                                      
                mov     di,160*26+80
                mov     ax,bx            
                mov     dl,Color2
                call    outputhex    
                           
                add     di,2
                push    cs     
                pop     ds 
                mov     si,offset MemString2     
                mov     ah,Color2
                call    outputstring
                           
                mov     ax,5801h        
                pop     bx 
                int     21h       
                clc        
                pop     ds              ; fuck forgotten pops
                ret        
                              
@@failed2:                     
                mov     bp, offset NotEnoughMem
@@fatal:        mov     ax,5801h
                pop     bx      
                int     21h                     ; restore UMB link status         
                stc            
                pop     ds
                ret            
                                     
AllocIt endp                   
                               
; destroys ax, bx, cx, dx, si, di but saves ds
; carry and bp = offset of errormsg 
LoadHeader proc                     
                push    ds       
                                                   
                mov     ah, 3fh  
                mov     bx, cs:SymHandle
                mov     cx, SymHeaderSize
                push    cs               
                pop     ds              
                mov     dx, offset SymHeaderStart
                int     21h                    ; Load Symbolic Header
                jc      @@FileProb
                            
                mov     bx, 3
                mov     di, offset SymMagic
                mov     si, offset Magic
@@Compare:                       
                mov     al, [si+bx-1]
                cmp     al, [di+bx-1]             ; right ?
                jne     @@RevisionError
                dec     bl 
                jne     @@compare    
                                     
                cmp     SymRevision, SymRevisionNum    ; current Revision Number
                jne     @@RevisionError
                             
                clc     
@@Fatal:                
                pop     ds
                ret     
                        
@@FileProb:             
                mov     bp, offset FileProblems
                stc       
                jmp     short @@Fatal
                          
@@RevisionError:          
                mov     bp, offset RevisionError
                stc     
                jmp     short @@fatal                   
                                     
LoadHeader endp                      
                                     
; carry and bp=msg 
LoadIt proc near                                 
                xor     dx, dx        
                mov     ds, cs:SymText[2]
                            
@@looper:       mov     ah, 3fh
                mov     bx, cs:SymHandle
                mov     cx, 08000h
                int     21h   
                jc      short @@uups
                cmp     ax, 8000h     
                jb      short @@fertig   
                mov     dx,ds
                add     dx,800h
                mov     ds,dx  
                xor     dx,dx        
                test    cs:SymSize,7fffh
                jne     short @@looper
                           
@@fertig:       mov     ah, 3eh
                mov     bx, cs:SymHandle          
                int     21h                      ; close file 
                          
@@uups:         mov     bp, offset FileProblems		; load offset on error message
                ret                   
LoadIt endp                           
                                      
; Relocate all those far pointers + Init Breakpoints anew.
InitIt proc near                      
                                      
                mov     ax, word ptr cs:SymVars
                sub     ax, cs:SymIndex
                mov     dx, word ptr cs:SymVars[2]      
                sbb     dx, cs:SymIndex[2]     
                mov     bx, 6         
                div     bx                      ; ppe with zero lines ? -> don't create a symbolic file then
                mov     cs:SymLines, ax
                                      
                mov     si, offset SymSource    ; erster der 4 Pointer
                mov     cx, 4         
@@UpDateHeadV:                       
                push    word ptr cs:[si+2]   
                push    word ptr cs:[si]   
                call    RelocatePointer
                pop     word ptr cs:[si] 
                pop     word ptr cs:[si+2]
                add     si, 4
                dec     cx   
                jne     @@UpDateHeadV           ; Update all header pointers
                                                                      
                mov     ds, cs:SymIndex[2]                    
                mov     si, cs:SymIndex                       
                mov     cx, cs:SymLines                       
@@Evenmore:
                mov     ax, ds:[si+2]
                mov     bx, ds:[si+4]
                push    ax
                shr     ax, 4
                shl     bx, 12
                add     bx, ax
                add     bx, cs:SymSource[2]
                pop     ax
                and     ax, 0fh
                add     ax, cs:SymSource
                mov     ds:[si+2], ax 
                mov     ds:[si+4], bx           ; reloziere auf basis von source
                                           
                add     si, 6         
                loop    @@evenmore               
                                                      
                mov     cs:f8Stop, 0  
                mov     cs:f8change, 0
                mov     cs:BActive, 0
                mov     cs:PPERestart, 0
                ret                   
                                      
InitIt endp                           
                                      
; expects a far pointer on the stack (top:offset, bottom:seg)
; returns far pointer normalised (+SymText)
RelocatePointer proc                        
                                             
                mov     bp, sp               
                mov     ax, [bp+2]      ; offset
                mov     bx, [bp+4]      ; segment        
                                 
                sub     ax, SymHeaderSize       ; Is not loaded..
                push    ax                  
                shr     ax, 4
                shl     bx, 12          ; only 4 bits from upper part
                add     bx, ax           
                add     bx, cs:SymText[2]
                pop     ax            
                and     ax, 0fh       
                   
                mov     [bp+2], ax    
                mov     [bp+4], bx    
                ret                   
RelocatePointer endp                  
                                      
                                      
;--------------------------------------------------------------------
;Unloads Symbolic, free allocated memory
;--------------------------------------------------------------------
                                         
UnloadSymbolic proc near            
                
                pusha                        
                push    es                   
                push    ds                   
                                             
                cmp     word ptr cs:SymText[2], 0
                je      short @@NoNo             
                                             
                mov     ah,49h               
                mov     es, cs:SymText[2]
                int     21h                      
                                             
                mov     word ptr cs:SymText[2], 0
                                        
@@NoNo:         push    cs              
                pop     ds              
                mov     si,offset terminated
                mov     di,80*2*27+28    
                mov     ah,Color2
                xor     bp, bp   
                call    outputstring
                              
                mov     ax, 83h      
                int     10h  
                mov     ax, 1114h
                int     10h             ; reset screen w/o deleting the PCB shit
                      
                mov     ax, 40h
                mov     es, ax
                and     byte ptr es:[87h], not 80h
                
                pop     ds                       
                pop     es           
                popa                 
                ret                  
                                     
terminated      db      'terminated',0
                                     
UnloadSymbolic endp                  
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같�
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같�
; F8 Handling

                                           
;----------------------------------------------------------------------------
; ax - line number to start with.                
; carry set if there is a goto on the current line.
                                                   
tabou           db      'GOTO'                
SearchNextLine proc near    
                push    ds
                push    es           
                push    bx
                push    dx
                push    cx           
                push    di  
                push    si     
                            
                lds     si, dword ptr cs:SymIndex
                                 
                mov     cx, ax          ; save ax 
                xor     dx, dx                    
                mov     bx, 6                     
                mul     bx                        
                                                  
                add     si, ax                    
                                                  
                add     si, 2                     
                les     di, ds:[si]               
                add     si, 6      
                        
                call    searchGoto                
                jc      @@OutOfRange
                        
                mov     bx, cs:PPE_ID
                mov     es, bx   
                mov     bx, cs:PPE_IP
                mov     dx, es:[bx]            
                cmp     dx, 0a9h        ; endproc
                je      @@outofrange
                cmp     dx, 0abh        ; endfunc
                je      @@outofrange
                cmp     dx, 2ah         ; return
                je      @@outofrange
                            
                mov     ax, cx        
                inc     ax            
                call    search_valid  
                clc         
@@Abort:                       
                pop     si
                pop     di           
                pop     cx        
                pop     dx
                pop     bx
                pop     es           
                pop     ds
                               
                ret          
@@outofrange:                    
                stc            
                jmp     short @@abort           ; coward version, this would be a more serious error.  
searchnextLine endp         
                                      
; ax - number of line to start with.
; returns ax - number of next code line. 
Search_valid proc near
                push    es            
                push    di
                push    dx  
                push    bx
                                     
                mov     bx, 6
                xor     dx, dx
                mul     bx  
                les     di, dword ptr cs:SymIndex
                add     di, ax
                mov     bx, es:[di]
                add     bx, 4
                call    getline   
                               
                pop     bx
                pop     dx            
                pop     di   
                pop     es
                ret       
search_valid endp         
                                      
; carry - isgoto ?        
; hardest. scan for string begins, then scan for ends. accept only gotos out of end.
searchgoto proc near            ; es:di -> aktline        (es:di destroyed.)
                push    ds           
                push    si      
                push    ax      
                push    cx
                                     
                push    cs        
                pop     ds      
                cld                
@@Parse_string:                  
                               
                mov     al, es:[di]
                inc     di            
                          
                cmp     al, 0ah                 ; eostring ?
                clc                
                je      @@Abort
                                      
                cmp     al, '"'
                jne     @@no_skip
                                                 
@@in_string:                         
                mov     al, es:[di]
                inc     di         
                cmp     al, '"'    
                jne     @@in_string             ; caution.. no open strings.. 
                jmp     short @@Parse_string    ; or we'll have a nice 'closed' loop
                                
@@No_skip:                      
                mov     si, offset tabou
                push    di      
                dec     di     
                mov     cx, 4         
                repz    cmpsb   
                pop     di      
                jne     @@Parse_string          ; No exception found
                                
                stc                   
@@Abort:                                                                                              
                pop     cx
                pop     ax                       
                pop     si           
                pop     ds  
                ret         
searchgoto endp                
                                     
                                         
;--------------------------------------------------------------------------
; output cursor line information. (line^h_displacement)                              
slash           db      '^', 0                                                                     
LineInformation proc near                              
                pusha                                  
                                                       
                mov     ax, cs:aktLine                 
                mov     di, 27*160+70*2                
                mov     dl, 8      
                call    outputhex                      
                                                       
                push    ds   
                mov     ax, cs
                mov     ds, ax
                mov     si, offset slash
                xor     bp, bp
                mov     ah, 7
                call    outputstring                     
                pop     ds           
                                   
                add     di, 2 
                mov     ax, cs:AktH
                call    outputhex
                                 
                popa             
                ret                   
LineInformation endp         
;--------------------------------------------------------------------
; Main debugging routine           
;bx = source-pos, es = ppe-seg                    
;--------------------------------------------------------------------                           
                                                                     
MainDebug proc near                                                  
                pusha                                                
                push    ds                                           
                push    es                                           
                                                                     
                push    cs          ; schlauer so.                                           
                pop     ds
                        
                mov     PPE_IP, bx           ; save real offset
                                                                  
                call    GetLine                                   
                                 
                mov     pIP, ax              ; save real pos
                           
                call    IsinList                ; Breakpoint ?
                jnc     @@Nobreakpoint
                mov     F8stop, 0
                mov     F8change, 0
                mov     trace, 1
                jmp     short @@No_Step_over
@@NoBreakPoint:                                            
                                            
                cmp     f8Change, 1
                jne     @@No_change_wait
                           
                cmp     ax, f8changefrom
                jne	@@NoFarJump
                jmp	@@NoKey
@@NoFarJump:                
                                                  
                mov     f8change, 0
@@no_change_wait:                  
                cmp     F8stop, 1
                jne     @@no_step_over 
                                     
                cmp     ax, cs:F8WaitFor
                jne     @@Nokey      
                mov     f8stop, 0
                                           
@@No_step_over:                      
                mov     dx, ax        
                mov     AktLine, ax
@@NoWayOut:     mov     ax, Aktline
	    	mov	bl, SourceDispLines
                mov 	bh, 0
                mov	cx, bx	 	   	; how many lines
                shr	bx, 1			; div 2 rounded..
                sub     ax, bx			; and start displaying earlier
                mov	bl, SourceDispS		; bh is empty   
              	add	bl, 28			; lower half of the screen
		mov	di, bx
		shl	bx, 2 
		add	di, bx                     
		shl	di, 5 			; (bx + (bx*4)) * 32 =  bx*160
                                                                
@@looper:       mov     bh, 2fh
                cmp     ax, dx                   ; pIP line. P - 1
                je      short @@okcolor                          
                mov     bh, 1fh                                   
                cmp     ax, cs:AktLine           ; Cursor Line P - 2                 
                je      short @@okcolor                          
                mov     bh, 4fh
                call    IsInList                 ; BreakPoint P - 3
                jc      short @@okColor 
                mov     bh, 0fh                  
@@okcolor:      call    PrintLine                                  
                                                                                
                add     di,80*2                                                 
                inc     ax                                                      
                                                                                
                loop    @@looper                                                
                                                                                
                call    Lineinformation                                         

	       	call 	VarWindow		; output this information if needed
                cmp     Trace,0                                                 
                je      short @@NoKey                                           
@@anyKey:                                                                        
	 	test 	WindowFlag, 1	                                        
	 	jne	@@VarOn          	; Var Window on so var key shit.
	 	mov	si, offset DebugIndex                                   
		mov	cl, keyMax                                              
		jmp	short @@KeyHandling                                     
@@VarOn:			                                                
		mov	si, offset VarIndex                                     
	      	mov	cl, VarKeyMax                                           
@@KeyHandling:                                                                  
	      	call    KeyRoutine                                              
                jc      short @@nowayout                        
@@noKey:                               
                pop     es                                      
                pop     ds                                      
                popa                                            
                ret                                             
                                                               
MainDebug endp                                                  
                                                               
; si -> offset of the appropriate key index table. Multi usable ;)
; cl -> number of keys in that keytable
; may return a carry flag                                                       
KeyRoutine proc near                                            
                locals           
                push    ds                   
                pusha
                mov	bp, sp 
@@another_key:                                              
                call    getkey
                jc      @@another_key        
                                             
                push    cs                   
                pop     ds                   
                               
                mov	si, bp[2]
                mov	cx, bp[0ch]	; saved with pusha
                cld                          
                                             
                mov     dx, ax          ; dx - key pressed
@@key_search:                                             
                lodsw                        
                cmp     ax, dx               
                jne     @@not_found          
                lodsw                        
                mov     bx, ax               
                call    bx
                jmp     short @@Keys_done    
@@Not_found:                                     
                add     si, 2           ; advance counter over command.
                dec     cl                   
                jnz     @@key_search         
                jmp     short @@another_key            
@@keys_done:                                           
                popa                                   
                pop     ds                              
                ret             ; procedure end        
KeyRoutine endp                                        
                                                       
;______________________________________________        
                                                       
DebugKeys 	proc		; do not call directly.
                                                       
@@f9:           mov     trace, 0        ; Run mode     
                clc                                      
                ret                                      
                                                         
@@f7:           mov     trace, 1        ; trace single step
                clc                                      
                ret                                      
                                          
@@down:         mov     ax, cs:SymLines    ; arrow down
                dec     ax                          
                cmp     Aktline, ax   
                jae     @@Ignore_down
                inc     Aktline
@@Ignore_Down:                              
                stc                         
                ret                                     
                                            
@@up:           cmp     Aktline, 0      ; arrow up
                je      @@Ignore_up         
                dec     Aktline
@@Ignore_up:                                
                stc                         
                ret                         
                                                     
@@Pup:          mov     cl, SourceDispLines
		dec	cl
		je	@@NoScroll
@@do_pup:                                   
                call    @@up                
                dec     cl                 
                jnz     @@Do_pup           
                                                 
                ret                          
                                                       
@@Pdown:        mov     cl, SourceDispLines          ; page down, scroll 20
		dec	cl
		je	@@NoScroll
	   	
@@do_pdown:     call    @@down             
                dec     cl                              
                jnz     @@do_pdown         
                ret                  
                                      
@@CpUp:         mov     aktline, 0
@@NoScroll:
                stc                       
                ret                       
                                          
@@CpDown:       mov     ax, Symlines
                dec     ax                
                mov     AktLine, ax       
                stc                       
                ret                       
                                          
@@F8:                          
                mov     ax, pIP                                  
                call    searchnextline          ; nice ;)
                jc      @@no_Bpoint              
                mov     f8change, 0     
                mov     F8stop, 1         
                mov     F8waitfor, ax      
                jmp     short @@out        
@@No_bpoint:                               
                mov     f8Stop, 0
                mov     f8change, 1
                mov     ax, pIP
                mov     f8changefrom, ax
                mov     trace, 1           
@@out:                                     
                clc                        
                ret                        
                                           
@@left:         cmp     aktH, 0
                je      @@Ignore_left
                dec     AktH
@@Ignore_left:  stc       
                ret               
                          
@@right:        cmp     aktH, 400
                je      @@Ignore_right           
                inc     aktH 
@@Ignore_right: stc       
                ret                  
                                      
; go up to the next valid line
@@f4:           mov     ax, aktline
                call    Search_valid
                mov     f8waitfor, ax
                mov     f8stop, 1
                clc           
                ret                                       
                              
; go left in 10 steps
@@cleft:        mov     cl, 16
@@go_left:                    
                call    @@left   
                dec     cl       
                jnz     @@go_left
                stc               
                ret           
; goto right 10 step.                         
@@cright:       mov     cl, 16
@@go_right:                
                call    @@right
                dec     cl           
                jnz     @@go_right    
                stc           
                ret           
; Exit debugger & PPE                                 
@@altx:                 ; dirt, dirt, dirt. Works, btw.
                mov     ax, PPE_ID
                mov     es, ax  
                mov     bx, ppe_ip
                mov     word ptr es:[bx], 1
                mov     trace, 0
                stc                        
                ret
; Set/delete Breakpoints.                        
@@F2:           mov     ax, AktLine
                mov     dx, ax
                call    Search_valid
                cmp     ax, dx
                jne     @@No_Valid_Line
                call    IsInList
                jc      @@delete_this
                call    add2list                ; add breakpoint
@@No_Valid_Line:
                stc      
                ret      
@@delete_this:                               
                call    deletePoint          
                stc                          
                ret                          
@@CtrlF2:                                    
                mov     PPERestart, 1        
                jmp     short @@altx                                   
                                              
@@Ctrlup:                                    
	  	cmp	SourceDispS, MinDispStart
	  	je	@@Ignorecup              
		dec	SourceDispS
		inc	SourceDispLines
@@IgnoreCUp:                                 
            	stc                   
	 	ret                   
		                             
@@CtrlDwn:                             
	      	mov	al, SourceDispS
		inc	al             
		mov	ah, MaxDispLines
		sub	ah, al                   
		je	@@IgnoreCDwn             
		mov	SourceDispS, al          
		mov	SourceDispLines, ah
@@IgnoreCDwn:                                    
		stc	                         
	 	ret                             
                                      
@@Tab:		cmp	SourceDispLines, MaxDispLines
		je	@@TabOk       
		or	WindowFlag, 1 
@@TabOk:	stc                   
		ret                   
                                                 
; Key definitions follow here.                   
; the keyroutines can count on ds being set on resident. 
; other regs are variable and change from version to version.
; they end with a ret and their carry decides over the jump back to 
; display or further execution.                  
debugindex	dw      4300h, offset @@f9      ; run (nonstop)
                dw      4100h, offset @@f7      ; step into     
                dw      48e0h, offset @@up       
                dw      50e0h, offset @@down        
                dw      49e0h, offset @@Pup      
                dw      51e0h, offset @@pdown    
                dw      84e0h, offset @@CpUp     
                dw      76e0h, offset @@CpDown   
                dw      4200h, offset @@F8      ; trace over
                dw      4be0h, offset @@left                
                dw      4de0h, offset @@right    
                dw      3e00h, offset @@f4      ; run up to here                        
                dw      73e0h, offset @@CLeft   ; 10 left
                dw      74e0h, offset @@CRight  ; 10 right
                dw      2d00h, offset @@altx     
                dw      3c00h, offset @@F2       
                dw      5f00h, offset @@CtrlF2  ; Restart
                                                 
                dw	8de0h, offset @@CtrlUp   
                dw	91e0h, offset @@CtrlDwn  
		dw     	0f09h, offset @@Tab	; for switching between windows
KeyMax		equ     ($ - DebugIndex) shr 2
                                                 
DebugKeys	endp                             
                                         
                       
                                         
;-------------------                                    
;bx = source-pos, zur갷k line# in ax                    
;-------------------                                    
                                                        
GetLine proc near                                       
                                                        
                push    bx                              
                push    cx                              
                push    si                              
                push    ds                              
                                                        
                sub     bx,4    
                lds     si, dword ptr cs:SymIndex
                xor     cx, cx
                                                         
@@next:         lodsw                    
                cmp     ax, bx            
                je      short @@dadaenter            
                ja      short @@lotto    
                add     si,4             
                inc     cx          
                cmp     cx, cs:SymLines
                jne     short @@next
                jmp     short @@lotto
                            
@@dada:         add     si,4
                lodsw       
                cmp     ax,bx
                jne     short @@lotto
@@dadaenter:    inc     cx            
                cmp     cx, cs:SymLines     
                jne     short @@dada
                                                 
@@lotto:        mov     ax, cx           ; bingo du idiot. (2 chicken..)
                dec     ax               
                            
                pop     ds  
                pop     si  
                pop     cx  
                pop     bx  
                ret                 
                               
                            
GetLine endp                
                            
;---------------------      
;ax = Line#, di = cursor-pos, bh = farbe
;---------------------      
                                
PrintLine proc near                   
                                           
                pusha                                               
                push    ds                                          
                                                                    
                test	WindowFlag, 1
                je	@@NoLowCol
		mov	bh, 8
@@NoLowCol:		                
                
                push    ax                                          
                                                                    
                push    cs                                          
                pop     ds                                          
	 	mov	cl, 80                                      
		mov	ah, bh                                      
	 	call	ClearEol                                    
                pop     ax          
                                   
                inc     ax         
                je      short @@outofrange
                cmp     ax, cs:SymLines
                jae     short @@outofrange		; debug purps.
                dec     ax            
                                    
                mov     si, 6        
                mul     si                       
                mov     bp, ax            
                add     bp, cs:SymIndex
                mov     ds, cs:SymIndex[2]
                mov     si, ds:[bp+2]
                mov     ds, ds:[bp+4]
                mov     ah, bh      
                mov     bp, cs:AktH 
                call    outputstring
                                
@@outofrange:   pop     ds      
                popa            
                ret             
                                
                                
PrintLine endp                  
                                      
