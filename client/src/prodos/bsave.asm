;
; ADTPro - Apple Disk Transfer ProDOS
; Copyright (C) 2006 - 2008 by David Schmidt
; david__schmidt at users.sourceforge.net
;
; This program is free software; you can redistribute it and/or modify it 
; under the terms of the GNU General Public License as published by the 
; Free Software Foundation; either version 2 of the License, or (at your 
; option) any later version.
;
; This program is distributed in the hope that it will be useful, but 
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
; or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License 
; for more details.
;
; You should have received a copy of the GNU General Public License along 
; with this program; if not, write to the Free Software Foundation, Inc., 
; 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
;

	.import ASMEND

;---------------------------------------------------------
; BSAVE - Save ADTPro parameters
;---------------------------------------------------------
; Out: carry = 0 -> no err
;      carry = 1 -> a MLI error occured (acc=err)
;
BSAVE:
	CALLOS OS_CREATE, FILE_CR
	CALLOS_CHECK_POS	; Branch + if no error
	cmp #$47		; File exists already?
	beq :+			; Don't care!
	ldy #PMNOCREATE
	jmp BSAVE_MSGEND 
:
	CALLOS OS_OPEN, FILE_OP	; open file
	CALLOS_CHECK_POS	; Branch + if no error
	ldy #PMNOCREATE
	jmp BSAVE_MSGEND 
:
	LDA FILE_OPN		; copy file number
	STA FILE_WRN
	STA FILE_CLN

WRITE:
	CALLOS OS_WRITEFILE, FILE_WR
	CALLOS_CHECK_POS	; Branch + if no error
	ldy #PMNOCREATE
	jmp BSAVE_MSGEND 
:	ldy #PMSG14		; All was OK

BSAVE_MSGEND:
	jsr BLOAD_END		; Close up the file
	jsr WRITEMSGAREA
	jsr PAUSE
	rts

;---------------------------------------------------------
; BLOAD - Load ADTPro parameters
;---------------------------------------------------------
; Out: carry = 0 -> no err
;      carry = 1 -> a MLI error occured (acc=err)
;
BLOAD:
	CALLOS OS_OPEN, FILE_OP
	CALLOS_CHECK_NEG	; Branch to BLOAD_END on error
	lda FILE_OPN		; copy file number
	sta FILE_RDN
	sta FILE_CLN

	CALLOS OS_READFILE, FILE_RD
:	; This colon (label) assigns the branch point for CALLOS_CHECK_NEG - to BLOAD_END
BLOAD_END:
	CALLOS OS_CLOSE, FILE_CL
	rts

;==============================*
;                              *
;     GET CURRENT PREFIX       *
;                              *
;==============================*

GET_PREFIX:
	LDX DEVCNT		; nbr of active units
	INX
	STX ZDEVCNT		; +1 saved in work field

	CALLOS OS_GET_PREFIX, GET_PFX_PLIST ; get the current prefix
	CALLOS_CHECK_POS	; Branch forward on success
	jmp GP_ANOTHER		; error

:	LDA CUR_PFX		; len=0 -> no prefix
	BNE GP_DONE

; It is possible to execute ADTPRO from BASIC.SYSTEM
; using a command like -/xxx/yyy/ADTPRO

	LDX KEYBUFF		; len in keyboard buffer=0?
	BEQ GP_ANOTHER		; yes, try with active devices list

	LDA KEYBUFF+1		; first character
	CMP #'/'
	BNE GP_ANOTHER		; no prefix before ADTPRO

GP_SLASH:
	LDA KEYBUFF,X		; search the slash before ADTPRO
	CMP #'/'
	BEQ GP_COPY

	DEX
	BNE GP_SLASH

GP_COPY:
	STX CUR_PFX		; copy the name
:	LDA KEYBUFF,X
	STA CUR_PFX,X
	DEX
	BNE :-
	BEQ GP_SET		; try to set prefix

GP_ANOTHER:
	LDA DEVICE		; is there a last used device?
	BNE GP_DEVNUM		; yes, begin with this one

GP_PREV:
	DEC ZDEVCNT		; previous unit
	BNE GP_NOTDONE		; not finished

	; Error!  Let the world know...
	jmp GP_DONE

GP_NOTDONE:
	LDX ZDEVCNT
	LDA DEVLST,X		; load device information (format DSSS000)

GP_DEVNUM:
	AND #%11110000
	STA UNIT		; set: current unit

	CALLOS OS_ONL, TBL_ONLINE ; retrieve the volume name (without /)
	CALLOS_CHECK_POS	; Branch forward on success
	jmp GP_PREV		; unit error. Try next one

:	LDA CUR_PFX+1		; 1st byte=DSSSLLLL
	AND #$0F		; keep only length
	BEQ GP_PREV		; len=0 -> error. Try next unit

	ADC #2			; len+2 (for the 2 added '/' - see below)
	TAX
	STX CUR_PFX		; save length
	LDA #'/'
	STA CUR_PFX+1		; replace DSSSLLLL with first / (volume name)
	STA CUR_PFX,X		; add / to the end to have: /name/

GP_SET:	CALLOS OS_SET_PREFIX, GET_PFX_PLIST ; do a 'set prefix' on the current pathname
	BCS GP_PREV		; error -> try another unit

GP_DONE:
	rts


ZDEVCNT:	.byte 0

; Online

TBL_ONLINE:
         .byte 2
UNIT:    .byte 0          ; unit
         .addr CUR_PFX+1  ; 16 bytes buffer for a specific unit

; Set Prefix

TBL_SET_PFX:
         .byte 1
         .addr CUR_PFX    ; addr of pathname

CUR_PFX:	.res 64

; Get Prefix

GET_PFX_PLIST:
	.byte 1
	.addr CUR_PFX

; Table for open

FILE_OP:	.byte 3
FILE_NAME:	.addr CONFIG_FILE_NAME	; addr len+name
FILE_BUF_PTR:	.addr BIGBUF+1024	; 1024 bytes buffer
FILE_OPN:	.byte 0		; opened file number

; Table for create

FILE_CR:	.byte $07
		.addr CONFIG_FILE_NAME	; addr len+name
		.byte $C3		; Full access
		.byte $06		; BIN file
		.addr $FFFF		; Aux data - load addr
		.byte $01			; Standard seedling file
		.byte $00, $00		; Creation date
		.byte $00, $00		; Creation time

; Table for read

FILE_RD:	.byte 4
FILE_RDN:	.byte 0			; opened file number
FILE_RADR:	.addr PARMS		; loading addr
FILE_RLEN:	.addr PARMSEND-PARMS	; max len
FILE_RALEN:	.addr $FFFF		; real len of loaded file

; Table for write

FILE_WR:	.byte 4
FILE_WRN:	.byte 0			; opened file number
FILE_WADR:	.addr PARMS		; loading addr
FILE_WLEN:	.addr PARMSEND-PARMS	; max len
FILE_WALEN:	.byte 0,0		; real len of loaded file

; Table for close

FILE_CL:	.byte 1
FILE_END:
FILE_CLN:	.byte 0			; opened file number