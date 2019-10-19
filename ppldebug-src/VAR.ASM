; Variable Handling                                          
; Lotsa shit.. this ain't a bug, this is a feature.               
; e!

; handling is about to get like this: 
; call   procedure which displays at any rate all of the variable part.
;  - decision: active or not ? if not then display in dark colors..
;  - do all the shit with finding out where to start. allow negative numbers
;    but filter them out at next step (empty string)
;  - Loop:                                                            
;          - Call corresponding X2string procedure for variable 
; 	   - del line with color
; 	   - Print whatever string we got with respcting left and right 
; 	     bounds, check for all this shit. (only in this proc..!)
; 	   - get new input.. 
; 	   - if we have to edit something then transform into string, edit
; 	     and then reverse. This might even be done with ppe functions. 
;             (but hasn't got priority now.. ;)
                
                                                                     
RefSeg		dw 	0, 0		; Main reference segment.    
                                                                     
Conv2String	dw 	offset UnknownType, offset UnknownType	; 1/2
     		dw 	offset UnknownType, offset UnknownType  ; 3/4
 		dw 	offset UnknownType, offset UnknownType  ; 5/6   
		dw 	offset UnknownType, offset UnknownType  ; 7/8   
		dw 	offset UnknownType, offset UnknownType  ; 9/a     
		dw 	offset UnknownType, offset UnknownType  ; b/c   
		dw 	offset UnknownType, offset UnknownType  ; d/e     
		dw 	offset UnknownType, offset UnknownType  ; f/10  
		dw 	offset UnknownType			; 11    
ConvMax		equ	($-Conv2String) /2                              
                                                                        
VHDisp		dw	0                                               
MaxVar		dw	0
Aktvar		dw	1
StringBuffer	db	2024+28 dup (0)	       	; asciiz - should be allocated !  
; expects ds on cs
VarWindow	proc 	                   
  		
  		pusha                      

		mov	ax, -1
		int	28h		; e-debug
  		      
		mov	cx, MaxDispLines
		sub 	cl, SourceDispLines
		or	cx, cx             
		je	@@NoVarDisp        
		                           
		push	cx                 
		shr	cx, 1                   
		mov	bx, AktVar
		sub 	bx, cx             
		pop 	cx    			; bx _can_ be negative
		              
		mov	di, 28*160		; init on this firm line..
	       	              
@@OutPutLoop:                                                  
	    	call 	VarNametoString		; returns dx on last char (offset)
		jc	@@NoValidVar                                              
	     	call	VarToString 		; var num in bx -> var into stringbuffer[dx]
@@NoValidVar:	                            
		mov    	ah, 1fh
		cmp	bx, AktVar
		je	@@ThisColor 
		mov	ah, 0fh
@@ThisColor:                        
		call 	outputBuffer		; decides whether to use real colors
		add	di, 160

		inc	bx		; increase disp var..		                                                    
		dec	cx   		; how many lines have we got
		jne	@@OutPutLoop                                
		                                                    
@@NoVarDisp:                                                        
	    	popa                                                
		ret                                                 
VarWindow	endp	 	                                    
		                                                    
; req: bx on variable number to treat                               
; back: dx on last char of text (with trailing :) or whatever.                
; no different colors for this sorry.
; expects cld
VarNameToString	proc            
	       	                
	       	push	ds      
		push	si      
		push	di      
		push	es                                   
		push	ax      
		                               
		cmp	bx, MaxVar
         	ja	@@NotValid		; unsigned compare
                                
		mov	di, cs                                 
		mov	es, di                                 
		call  	GetVarName	       	; ds:si points.
		jc	@@NotValid
		                                                    
       		mov 	di, offset StringBuffer    
@@CopyLoop:                                        
		lodsw	                                         
		or	al, al                                   
		je	@@killit                   
	       	or	ah, ah                     
		je	@@onechar                  
		stosw                              
		jmp	short @@CopyLoop           
@@OneChar:                                         
		stosb                                        
@@KillIt:                                                                                         
		clc	      		; was valid              
		mov  	ax, ' :'                                 
		stosw                                            
		mov	dx, di
@@OuttaHere:		                                         
	    	pop	ax                                       
		pop	es                                       
		pop	di                                          
		pop	si                                       
		pop 	ds                                       
		ret                                              
@@NotValid:                                                      
		mov	byte ptr StringBuffer, 0	; (empty)
		stc                     ; do not even convert..
		jmp 	short @@OuttaHere
VarNameToString	endp                                      
		                         
; req: dx on charoffs into StringBuffer
;      bx on Variable number (valid)                         
; back: Stringbuffer	 	
; save some reqs dont fuckking forget..
VarToString	proc 
           	locals
	 	pusha 		                                               
		mov  	si, offset Conv2String                                 
		mov	ax, bx                                                 
		mov	bp, bx                                                 
                                                                               
		push 	es	; ------------------------GetVarType macro     
		push	ax                                                     
		call	GetVarDef                                              
		mov	bx, es:[bx+2]                                          
		pop 	ax                                                     
		pop 	es      ; --------------------------                                    
                                                                               
		cmp	bx, ConvMax	; is this within the range of known vars ? 
		ja	@@UKT
		shl	bx, 1                                                  
		call 	Conv2String[bx]	; bp number of var, dx on offset into stringbuffer
     	       	jmp    	short @@Converted
@@UKT:                                                                             
	   	call	UnknownType
@@Converted:                                                                   
		popa                                                           
		ret                                                            
VarToString	endp                          
                
;============================================================================
; ::::::::::::::::Converting Routines (to string)::::::::::::::::::::::::::::
;============================================================================
UkText		db	'what the heck is this ?', 0
UkTextL		equ	($-UkText)                  
; sets es, is allowed to dest anything
UnknownType	proc                                                
		                                               
		mov	di, cs                                 
		mov	es, di                                 
		mov	di, dx                                 
		mov	si, offset UkText                      
		mov	cx, UkTextL
		              
		rep 	movsb
		ret
UnknownType	endp	      	
                              
; API API API API API API API API API APA PIA PIAP IAP IAPI APIAPIA PIAP IAPI 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Gets a variable (number ax's) type                              
; destroys nothing but bx, where it gives back ax's type          
; ds-> refseg...                                                  
GetVarType	macro                           
		push 	es                                        
		push	ax                                        
		call	GetVarDef                                 
		mov	bx, es:[bx+2]                             
		pop 	ax                                        
		pop 	es                                          
endm
                                                                                         
                                            
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Number of variable in bx    
; returns ds:si on variable name..        
; changes nothing. (ds -> resident)             
; invalid var numbers do a stc
GetVarName	proc                                         
                                          
                push	cs                                        
                pop 	ds                      
	  	lds	si, dword ptr SymVars   
		                                
@@ThisOne?:                                     
	   	cmp	word ptr ds:[si], bx    
		je	@@VarFound              
		cmp	word ptr ds:[si], -1
		je	@@VarNotFound
		add	si, 32                  
		jmp	short @@ThisOne?        
@@VarFound:                                     
		add	si, 4		; make it point on name
		clc
		ret
@@VarNotFound:
		stc
		ret
GetVarName	endp		                
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Expects number of variable in ax                                           
; returns es:bx on the variable definition                                   
; expects ds to be on refseg................................................ 
                                                                  
GetVarDef	proc                                              
		                                                  
		push	ax                                        
		les 	bx, dword ptr RefSeg                      
		les	bx, dword ptr es:bx[4]                    
		shl	ax, 2                                     
		add	bx, ax			; now es:bx on index table
		les	bx, es:[bx-4]                             
		les	bx, es:[bx+6]                             
		                                                  
		pop	ax                                        
		ret                                               
GetVarDef	endp                                              
                                                                  
;========================================================================                         
GetRefSeg   	proc near                                         
	 	                                                  
		push	es                                        
		push	bx                                        
                           
		les 	bx, [bp+06] 		; pcb ver dep ?   
		mov	cs:RefSeg, bx                             
		mov	cs:RefSeg[2], es                          
                                                
		pop 	bx                                        
		pop 	es                                        
		ret                                               
GetRefSeg	endp                                              
                                                                  
; Variable Part key definitions. stc when non executive..         
                                                                  
VarKeys		proc near ; do not call just definitions          
       			  ; procedure so I can seek for it easier...;)   
		    	                                                 
@@Tab:		and 	WindowFlag, not 1   	; switch var off..       
		stc                                                      
		ret           
		                
@@up:		cmp	AktVar, 1
    		je	@@AupIg                 
		dec	AktVar                                    
@@AupIg:	stc                             
		ret                             
  	                                        
@@down:	 	mov	ax, AktVar              
		cmp	ax, MaxVar              
		jae	@@AdwnIg                
		inc	AktVar                  
@@AdwnIg:	stc                             
		ret                             
                                                
VarIndex	dw  	0f09h, offset @@Tab     
		dw	48e0h, offset @@up      
		dw  	50e0h, offset @@down                                    
VarKeyMax	=   	($ - VarIndex) shr 2    
                                                
VarKeys		endp                            
                                                
InitVar		proc	                
		pusha                           
		push	ds
		push	es              
                
		push	cs              
		pop	ds                      
		                                                
	    	les	di, dword ptr SymVars	                                 
                xor	cx, cx                                                   
			  	                                                 
		cmp	word ptr es:[di], 0ffffh                                 
		je	@@NoVars                                                 
@@ScanEnd:                                                                       
		add	di, 20h		; record size                            
	  	inc	cx    		                                         
		cmp 	word ptr es:[di], 0ffffh		; last variable ?
		jne	@@ScanEnd                                               
                                                                                
@@NoVars:                                                                       
       		mov	MaxVar, cx                                              
		
		pop	es              
		pop	ds
		popa                                                            
		ret                                                             
InitVar		endp	  	                                                
		                                                                
;String output with checking left and right shit. ah -> color                   
; di on the beginning of the line                                               
; I hope ds will be on cs then ...                                              
OutputBuffer	proc	                                                        
	    	pusha                                                           
		                                                                
		test	byte ptr VarWindow, 1                                            
		jne 	@@NoLowCol                                              
	   	mov 	ah, 08h                                                 
@@NoLowCol:                                                                     
		mov	cl, 50h
		call	ClearEol                                                
		                                                                
		mov	dx, VHDisp                                              
		mov	si, offset StringBuffer					
		push	0b800h          
		pop	es              
		mov	cx, di          
		add	cx, 160		; shit is easier to compare..
		                        
		or	dx, dx                                    
		je	@@ShitLoop      
		push 	ax              
		mov 	ax, MoreLeft    
		stosw                   
	   	pop 	ax              
@@ShitLoop:                      
		lodsb
	    	or  	dx, dx
		jne	@@Eat
		or	al, al
		je	@@OutHere
		stosw	         
	     	cmp	di, cx   
	     	jbe	@@ShitLoop		; write all chars..
	     	jmp	short @@Endit 
@@Eat:                                
		dec	dx            
		jmp	short @@ShitLoop
@@Endit:                              
		cmp     byte ptr ds:[si], 0                         
		je	@@OutHere
		sub	di, 2
		mov	ax, MoreRight
		stosw
@@OutHere:
		popa             
		ret 
OutputBuffer	endp