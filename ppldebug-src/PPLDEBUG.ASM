.286			; As much as I love the 80386/80468 instruction set ;)
date            equ     '11/19'         ; compilation date.
PPLDver         equ     'v1.3b'         ; max 5 chars - and please.. fill with spaces..
; PPLDEBUG.ASM          - Main File                    
                            
Color1 		equ 6fh
Color2 		equ 0eh  
TheresmoreColor equ 14    
                
nojumps                        
                          
                
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같�
;       Resident part of PPLDEBUG.
; Caution.. everything from here to cs goes resident..
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같�
                                   
resident segment 'resident_code' 
         assume cs:resident, ds:resident, ss:sseg
                                
                dw      200h dup (0)                                          
altstack:                      
                
install         dw      0abbah
        
oldintf1        dd      0
Rec_level       db      0               ; increase on install. (Recursion of debugger not allowed at the moment. Later maybe ;)
ignore          dw      0
trace           dw      0
              
entry           db      9ah
                dw      offset debug
p1              dw      seg debug
                db      90h                ; nop

MoreLeft	equ	(TheresMoreColor shl 8) + 0aeh
MoreRight	equ	(theresMoreColor shl 8) + 0afh		; the double <'s...
        
include BREAK.ASM       ; All breakpoint List handling      
include easy.asm        ; Basically main debugging routines
include vAR.asm		; all variable handling..
                                  
locals @@                          
                              
;--------------------------------------------------------------------
;debugger entry point (called by debug.ppe)
;ax = abba (magic debug launch)
;bx = offest ppe entry point (0 = autodetect)
;cx = ignore cx steps (for launching debugged ppe)
;ds:dx = name of symbolic-file
;--------------------------------------------------------------------
                
launch          proc       
                locals                
                           
      		cmp	ax, 0abbah	; install ?
                jz      @@ok                       
                cmp     ax, 0BAABh       ;remover  
                jnz     @@nuthin                   
                                                   
                cmp     cs:SymAborted, 0           
                jne     @@PPEAborted 
                                    
                dec     cs:rec_level           
                Call    Hookout
@@PPEAborted:                
                call    UnloadSymbolic  ; the ppe run overlay gets kicked anyways. So no removal of links there.
                cmp     cs:PPErestart, 1           
                jne     @@nuthin                   
                mov     ax, 1234h       ; restartcode
@@nuthin:       iret                    ; no other handlers served.
                                                   
@@ok:           cmp     cs:rec_level, 0            
                jne     @@nuthin                   
                                                   
                mov     bp,sp                      
                mov     ax,[36+bp]                 
                                                   
                pusha                              
                push    ds                         
                push    es                                                  
                call    InitScreen      ;80x50 initialisieren
                call    LoadSymbolic                     
                jc      short @@failed                   
                                                                        
                cmp     bx, 0            ; Autodetect (tm)
                jnz     short @@no_search                
                call    ScanVersion                      
                cmp     bx, -1          
                je      short @@Unload  
                                      
@@no_search:    inc     cx            
                mov     cs:ignore, cx    ; nice piece of brain lost here.
                mov     cs:trace, 1        
                                             
                push    cs                   
                pop     ds                   
                mov     es,ax                
                                             
                mov     si, offset cs:entry  
                mov     di, bx               
                mov     cx, 3                
                cld                          
                rep     movsw            ; write far jmp on debugging routine in PCB
                                                                                
                CAll    HookIn   
                inc     rec_level                                               
                jmp     short @@start    ; everything fine
@@unload:                                                 
                call    UnloadSymbolic   ; error as the syms were already loaded. Unload.
@@start:                                      
@@failed:                             
                pop     es            
                pop     ds            
                popa            
                iret        
launch		endp
                            
;--------------------------------------------------------------------
                            
xss       dw 0                     
xsp       dw 0              
xbx       dw 0                                                     
                    
initstack macro            
          cli                   
          mov  cs:xss, ss          
          mov  cs:xsp, sp
          mov  cs:xbx, bx
          mov  sp, offset altstack                
          mov  bx, cs
          mov  ss, bx            
          sti   
endm                            
                
reststack macro 
          cli   
          mov  sp, cs:xsp 
          mov  ss, cs:xss
          mov  bx, cs:xbx 
          sti                      
endm                                                      
                                                                   
;--------------------------------------------------------------------
; Main debugging routine, called after each statement     
;--------------------------------------------------------------------
dEBUG           proc                                      
                                                          
                locals                                    
               
	       	call 	getrefseg
                initstack
                push    ds                                
                push    es                                
                pusha                                     
;ignore steps (after launching in debug.ppe)              
                                                          
                cmp     cs:ignore, 0
                jz      @@No_ignore                       
                                                          
                dec     cs:ignore                         
                jnz     @@ignore_this                     
                                                          
                call    SaveID                  ;store 16byte ID of traced PPE
                                                          
;start debugger if trace is ON                            
                                                          
@@No_ignore:    mov     bx, cs:xbx                        
                                                          
                mov     ax, es                            
                cmp     ax, cs:PPE_ID                     
                jne     short @@ignore_this               
                                                          
                call    DebugInfo                         
                call    MainDebug                         
                                
@@ignore_this:  popa
                pop     es      
                pop     ds      
                reststack
                
do_end          db      26h, 8bh, 07h                    ;MOV AX, ES:[BX]
                db      89h, 46h, 0fah                   ;MOV [BP-6], AX
                retf
                                                         ;oder MOV [BP-12], AX
Fix_List        db      0fah,0eeh,-1                    ;fix f걊 MOV [BP-x]             
endp debug                                                                     
                                                                               
;--------------------------------------------------------------------          
;ax 16bit Hex auf Screen dumpen, dl = Farbe                                    
;di = pos, zur갷k di = neue pos
;--------------------------------------------------------------------
                          
hex       db   '0123456789abcdef'
                    
outputhex proc near       
                                                                       
                push    es
                push    ds 
                push    bx         
                push    cx 
                push    ax       
                           
                add     di, 6    
                push    cs         
                pop     ds      
                mov     bx, 0b800h       
                mov     es,bx                  
                        
                mov     bx, ax
                mov     cx, 4
@@do_output:                    
                push    bx     
                and     bx, 0fh 
                mov     al, ds:hex[bx]
                mov     ah, dl      
                mov     es:[di], ax                                    
                sub     di, 2   
                pop     bx                  
                shr     bx, 4       
                loop    @@do_output
                add     di, 10   
                                 
                pop     ax
                pop     cx         
                pop     bx        
                pop     ds              
                pop     es                     
                ret                            
                                         
endp outputhex                           
                                         
;----------------------------------------------------------------------
; al 8bit hex int to output
; dl color
; di -> screenpos|returns di set on next coord.
;----------------------------------------------------------------------
                             
outputbhex proc              
                cld          
                push    es   
                push    ax       
                push    dx   
                push    bx      
                             
                mov     bx, 0b800h
                mov     es, bx
                xor     bx, bx
                mov     ah, dl          ; color
                mov     dl, al          ; byte
                             
                mov     bl, al
                shr     bl, 4
                mov     al, byte ptr cs:hex[bx]
                stosw        
                             
                mov     bl, dl
                and     bl, 0fh
                mov     al, byte ptr cs:hex[bx]
                stosw        
                                 
                pop     bx
                pop     dx      
                pop     ax
                pop     es
                ret
outputbhex      endp                         
                             
;-----------------------------------------------------------------------------
; ClearEol - di auf curs pos, cl auf Zeichen zu l봲chen., ah auf color
; setzt cld voraus..
; zerst봱t nichts
;-----------------------------------------------------------------------------

ClearEol	proc
		push	di
		push	es
		push	cx
		push	ax
		                 
		push	0b800h
		pop	es      
				            
		mov	al, 20h
		xor	ch, ch   
		rep	stosw
		
	 	pop	ax
		pop	cx
		pop	es
		pop	di
		ret
ClearEol	endp		             
                             
;--------------------------------------------------------------------
;ds:si string auf Screen dumpen (bis 0, max 80 Zeichen), ah = farbe
;di = pos                    
;bp = Horitz displacement in string.                                      
;--------------------------------------------------------------------
                                    
OutputString    proc            
                locals                
                                    
                pusha               
                push    ds          
                push    es          
                                    
                mov     bx,0b800h   
                mov     es,bx       
                             
	      	mov	cx, 80 

		or 	bp, bp
		je	@@Do_output
		push	ax
		mov	ax, MoreLeft
		stosw                                                     
		pop  	ax       
		inc	bp
		dec	cl      
@@do_output:                   
       	      	lodsb          
                cmp     al,0                                       
                je      short @@EndeString                         
                cmp     al,13                                      
                je      short @@EndeString                         
                cmp     al,10                                                                                     
                je      short @@EndeString                                                                        
                or      bp, bp                                                                                    
                je      @@nodec_bp                                                                                
                dec     bp                                                                                        
                jmp     short @@do_output       ; do not count this here                                          
@@nodec_bp:                                                                                                       
		cmp	cl, 1 	     		; on last char output the double > if there are more chars to come
		jne	@@OutPut
	 	cmp	byte ptr ds:[si], 0	; was this the last char ?
		je	@@OutPut 
		cmp	byte ptr ds:[si], 13
		je	@@OutPut
		cmp	byte ptr ds:[si], 10
		je	@@OutPut
		mov	ax, MoreRight
@@OutPut:	stosw                
                loop    @@do_output 
                                    
@@EndeString:                       
                pop     es         
                pop     ds    
                popa          
                ret           
                           
endp outputstring     
                                
;--------------------------------------------------------------------
;warten auf Tastendruck, ax = Taste
;--------------------------------------------------------------------
                    
getkey proc near                
                    
                push    es
                push    bx
                    
                mov     bx,0040h   
                mov     es,bx
                         
@@wait:         mov     bx,es:[1ah]
                cmp     bx,es:[1ch]
                jz      short @@nokey
                mov     ax,es:[bx] 
                mov     bx,es:[1ch]
                mov     es:[1ah],bx
                                   
                pop     bx         
                pop     es         
                clc                
                ret                
                                   
@@nokey:        pop     bx         
                pop     es         
                stc                
                ret               
                                  
endp getkey                       
                                  
                                               
;--------------------------------------------------------------------
;Scans for PPLDebug Hook -> bx = offset
;--------------------------------------------------------------------
                          
ScanVersion proc                ; bx to the rite offset..
                                                         
                push    ax                               
                push    cx                               
                push    bp                               
                push    si                               
                push    di                               
                push    es                               
                push    ds                               
                                                         
                cld                     ; the famous direction flag.
                                                         
                mov     es,ax           ; ppeseg         
                push    cs                               
                pop     ds                               
                                                         
                xor     bp,bp                            
@@ScanNext:     mov     al,cs:fix_list+bp                
                cmp     al,0ffh                            
                je      short @@RealNo          
                mov     cs:do_end+5,al          ; change the scanfor until
                                                ; found or no more possible 
                                                ; fixes there.                 
                xor     di,di            
@@ScanByte:     push    di               
                mov     si,offset do_end 
                mov     cx,3             
                repe    cmpsw            
                jnz     @@nomatch        
                pop     di               
                jmp     @@setBx          
                                         
@@noMatch:      pop     di               
                inc     di               
                cmp     di, 0ffffh-6     
                jb      @@ScanByte       
                jmp     @@NotFound       
                                         
@@setBx:        mov     bx,di            
                jmp     short @@outofhere
                                         
@@NotFound:     inc     bp               
                jmp     short @@ScanNext 
                                         
@@RealNo:       mov     bx,-1            
@@OutofHere:                             
                pop     ds
                pop     es
                pop     di
                pop     si
                pop     bp
                pop     cx
                pop     ax
                ret
                                  
endp ScanVersion
                                   
;END OF RESIDENT CODE------------------------------------------------
                          
resident 	ends
                        
;--------------------------------------------------------------------
                              
Cseg segment public 'Main_code' 
assume cs:cseg, ds:cseg, es:cseg, ss:sSeg
                        
regnr           dw   6  ;1 = Lone Runner
                        ;2 = Cyberpunk & qube
                        ;3 = Invi
                        ;4 = Carcass
                        ;5 = Master Of The Matrix
                        ;6 = Calvin + Zengo
                                  
ppld$           db   'pplDebug ',PPLDver,'                 (c)1995/96 by eULE! and Chicken / Tools 4 Fools', 13, 10
                db   '$'                         
uninstall$      db   'pplDebug already installed, Removing ! ',13,10,'$'
err1$           db   'Unable to remove, please reboot to clean.$'
                                                           
;include         init.asm           
                                    
;--------------------------------------------------------------------
;resize resident segment            
;--------------------------------------------------------------------
                                    
Resize proc near                    
                                    
                locals              
                                    
                mov     dx,cs       
                mov     cx,seg resident
                sub     dx,cx       
                add     dx,10h      
                                    
                mov     ax,3113h    
                int     21h         
endp                                
                                    
;-----------------------------------------------------------------------------  
                                                                              
dosmsg    macro         ; puts out a msg via DOS ah=9                         
          mov  ah, 9                                                          
          int  21h                                                            
          endm                                                                
                                                                              
;-----------------------------------------------------------------------------
;main ppldebug code to install it resident
;--------------------------------------------------------------------
                                    
main            proc                
                assume ds:resident
                                    
                push    es
                                    
                push    word ptr 0  
                pop     es          
                mov     si,0f1h*4   
                lodsw               
                mov     es, es:[si] 
                mov     si, offset install
                cmp     es:[si], word ptr 0abbah
                jne     short @@goon                    ; install
                                                                 
                push    cs                                       
                pop     ds                                       
                mov     dx,offset uninstall$                     
                dosmsg                                           
                   
                assume  es:resident
                push    ds
                mov     ds, word ptr es:oldintf1[2]
                mov     dx, word ptr es:oldintf1[0]
                mov     ax, 25f1h
                int     21h
                pop     ds 
                assume  es:nothing
                                        
                push    es                
                mov     ax, es            
                sub     ax, 10h           
                mov     es, ax            
                mov     ah, 49h            
                int     21h             ; remove es (resident)
                jnc     @@removed       
                mov     dx, offset err1$
                dosmsg                  
                mov     ax, 4c01h       
                int     21h             
@@removed:                              
                pop     es              
                                        
                mov     word ptr es:[si], 0        
                               
                pop     es     
                                             
                mov     ax,4c00h
                int     21h        
                              
@@goon:         pop     es    
                              
                push    cs    
                pop     ds    
                mov     dx,offset ppld$
                dosmsg        
                                     
                mov     ax,seg resident
                mov     ds,ax    
                                               
                mov     es, word ptr es:[2ch]   ; es : psp seg 
                mov     ah, 49h     
                int     21h             ; kill env.
                                    
                mov     ax, 35f1h   
                int     21h             ; save oldint for turbo shells (ie)
                mov     word ptr oldintf1[0], bx
                mov     word ptr oldintf1[2], es
                                   
                                         
                mov     dx,offset launch
                mov     ax,25f1h
                int     21h             ;set debug int.
                           
;                call    InitNames
                call    resize          ;terminate with the rite tsr size..
endp                
cseg 		ends             
                 
;.. tha stack .. 
                                  
sseg      segment stack
          dw  40h dup (0)    
ends                         
end main 
