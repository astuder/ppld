; break.asm             (for printing)
; all breakpoint handling.    
                                     
Max_points      equ     20                      ; max user bpoints.
                                       
BActive         db      0               
BList           dw      Max_points dup (0)      ; all Lines of all bpoints.
                
;----------------------------------------------------------------------------
; ax - line to scan for.
; returns carry if in list
;----------------------------------------------------------------------------
                          
IsInList proc near        
                push    ds
                push    si
                push    ax
                push    bx
                push    dx
                          
                mov     bx, cs
                mov     ds, bx
                mov     si, offset Blist
                mov     bl, BActive
                mov     dx, ax  
                                
@@Scan_All:               
                or      bl, bl
                je      @@NotFound      
                                        
                lodsw                   ; get next breakpoint line
                cmp     dx, ax          
                je      @@found         
                dec     bl
                jmp     short @@Scan_all
                          
@@NotFound:               
                clc       
@@End_Proc:               
                pop     dx
                pop     bx
                pop     ax
                pop     si
                pop     ds
                ret
@@Found:        stc
                jmp     short @@end_proc       
IsInList endp                           
                                        
                                        
;----------------------------------------------------------------------------
; ax - offset to add                    
; Succeds always                        
;----------------------------------------------------------------------------
                                        
add2list proc near                      
                assume ds:resident      
                pusha                   
                push    ds              
                                        
                mov     bx, cs          
                mov     ds, bx          
                                        
                xor     bx, bx                   
                mov     bl, BActive     
                cmp     bl, Max_Points  
                je      @@failure       
                                        
                shl     bx, 1   
                add     bx, offset BList
                mov     [bx], ax
                inc     Bactive 
                                      
@@Failure:
                pop     ds
                popa               
                ret             
add2list endp                       
                                
;같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같같�
; Deletes a breakpoint and closes the gap to the end.
; ax - Line Nummer of Breakpoint to delete
; ds muss auf cs(resident) zeigen    
; Die Procedur geht davon aus, dass ein Breakpoint existiert.
                                                             
deletePoint proc near                                        
                pusha                                        
                push    es
                push    ds
                pop     es
                cld     
                                                             
                mov     si, offset BList
                mov     dx, ax
                xor     bx, bx 
@@search:       lodsw     
                inc     bl
                cmp     ax, dx
                jne     @@search
                          
                mov     bh, Bactive
                sub     bh, bl          ; how many to move ?
                
                or      bh, bh
                je      @@onlyDec
                          
                lea     di, [si-2]
                  
@@Close_Gap:      
                movsw              
                dec     bh         
                jne     @@Close_gap                          
                
@@OnlyDec:      dec     BActive
                               
                pop     es     
                popa            
                ret             
deletePoint endp                      
