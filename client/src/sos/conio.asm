;
; ADTPro - Apple Disk Transfer ProDOS
; Copyright (C) 2008 by David Schmidt
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

;---------------------------------------------------------
; INIT_SCREEN
; 
; Sets up the screen for behaviors we expect
;---------------------------------------------------------
INIT_SCREEN:
	; Prepare the system for our expecations
	clc
	CALLOS OS_OPEN, OPEN_PARMS	; Open the console
	bcs Local_Quit
	lda OPEN_REF
	sta WRITE_REF			; Save off our console file references
	sta WRITE1_REF
	sta CONSREAD_REF

	lda #INIT_SCREEN_DATA_END-INIT_SCREEN_DATA
	sta WRITE_LEN
	lda #<INIT_SCREEN_DATA
	sta UTILPTR
	lda #>INIT_SCREEN_DATA
	sta UTILPTR+1
	jsr WRITEMSG_RAW
					; Ask for device number of the console
	CALLOS OS_GET_DEV_NUM, GET_DEV_NUM_PARMS
	bcs Local_Quit
	lda GET_DEV_NUM_REF
	sta D_STATUS_NUM		; Save off our console device references
	sta D_CONTROL_NUM

	lda #$80
	sta D_CONTROL_DATA
	lda #$0d
	sta D_CONTROL_DATA+1
	lda #$02
	sta D_CONTROL_CODE
	CALLOS OS_D_CONTROL, D_CONTROL_PARMS	; Turn data entry termination on

	rts

Local_Quit:
	jmp QUIT

INIT_SCREEN_DATA:
	.byte 16, 0	; Set 40 columns
	.byte 21, $0f	; Make return do newline
	.byte 28	; Clear screen
INIT_SCREEN_DATA_END:

;---------------------------------------------------------
; HOME
; 
; Clears the screen
;---------------------------------------------------------
HOME:
	lda #$1c
	jsr COUT
	rts

;---------------------------------------------------------
; SHOWLOGO
; 
; Prints the logo on the screen
;---------------------------------------------------------
SHOWLOGO:
	ldx #$0d
	ldy #$03
	jsr GOTOXY
	lda #PMLOGO1	; Start with MLOGO1 message
	sta ZP
	tay
LogoLoop:
    	lda #$0d	; Get ready to HTAB $0d chars over
	jsr HTAB	; Tab over to starting position
	jsr WRITEMSG
	inc ZP
	inc ZP		; Get next logo message
	ldy ZP
	cpy #PMLOGO5+2	; Stop at MLOGO5 message
	bne LogoLoop

	jsr CROUT
    	lda #$12
	jsr HTAB
	ldy #PMSG01	; Version number
	jsr WRITEMSG

	rts

;---------------------------------------------------------
; WRITEMSG - Print null-terminated message number in Y
;---------------------------------------------------------
; Entry - clear and print at the message area (row $16)
WRITEMSGAREA:
	lda #$16
	jsr TABV
; Entry - print message at left border, current row
WRITEMSGLEFT:
	lda #$1e		; Clear line
	jsr COUT
WRITEMSG:
	lda MSGTBL,Y
	sta UTILPTR		; Point UTILPTR at our message
	lda MSGTBL+1,Y
	sta UTILPTR+1

	clc
	tya
	ror		; Divide Y by 2 to get the message length out of the table
	tay
	lda MSGLENTBL,Y
	sta WRITE_LEN
WRITEMSG_RAW:
	clc
	CALLOS OS_WRITEFILE, WRITE_PARMS
	jmp ERRORCK		; Retrun through error handler for SOS errors

;---------------------------------------------------------
; SHOWHMSG - Show host-initiated message #Y at current
; cursor location.  We further constrain messages to be
; even and within the host message range.
; Call SHOWHM1 to clear/print at message area.
;---------------------------------------------------------
SHOWHM1:
	sty SLOWY
	ldx #$00
	ldy #$16
	jsr GOTOXY
	jsr CLREOP
	ldy SLOWY

SHOWHMSG:
	tya
	and #$01	; If it's odd, it's garbage
	cmp #$01
	beq HGARBAGE
	tya
	clc
	cmp #PHMMAX
	bcs HGARBAGE	; If it's greater than max, it's garbage
	jmp HMOK
HGARBAGE:
	ldy #PHMGBG
HMOK:
	lda HMSGTBL,Y
	sta UTILPTR
	lda HMSGTBL+1,Y
	sta UTILPTR+1
	clc
	tya
	ror		; Divide Y by 2 to get the message length out of the table
	tay
	lda HMSGLENTBL,Y
	sta WRITE_LEN
	jmp WRITEMSG_RAW	; Call the regular message printer
	
;---------------------------------------------------------
; GOTOXY - Position the cursor
;---------------------------------------------------------
GOTOXY:
	stx WRITEMSG_XY+1
	sty WRITEMSG_XY+2
	lda #<WRITEMSG_XY
	sta UTILPTR
	lda #>WRITEMSG_XY
	sta UTILPTR+1
	lda #$03
	sta WRITE_LEN
	jmp WRITEMSG_RAW	; Finish through WRITEMSG_RAW

WRITEMSG_XY:
	.byte 26, $00, $00	; $1a/26 is the code for absolute position

;---------------------------------------------------------
; TABV - Vertical tab to accumulator value
; VTABS TO ROW IN A-REG
;---------------------------------------------------------
TABV:
	sta WRITEMSG_VT+1
	lda #<WRITEMSG_VT
	sta UTILPTR
	lda #>WRITEMSG_VT
	sta UTILPTR+1
	lda #$02
	sta WRITE_LEN
	jmp WRITEMSG_RAW	; Finish through WRITEMSG_RAW
	rts
	

WRITEMSG_VT:
	.byte $19,$16		; $19/25d is the code for vertical position

;---------------------------------------------------------
; HTAB - Horizontal tab to column in accumulator
;---------------------------------------------------------
HTAB:
	sta WRITEMSG_HT+1
	lda #<WRITEMSG_HT
	sta UTILPTR
	lda #>WRITEMSG_HT
	sta UTILPTR+1
	lda #$02
	sta WRITE_LEN
	jmp WRITEMSG_RAW

WRITEMSG_HT:
	.byte $18,$16

;---------------------------------------------------------
; GETCHR1
; 
; Read a character from the console
;---------------------------------------------------------
READ_CHAR:
GETCHR1:
RDKEY:
	jsr ECHO_OFF
	lda #$01
	sta CONSREAD_COUNT
	clc
	CALLOS OS_READFILE, CONSREAD_PARMS
	jsr ERRORCK
	lda CONSREAD_INPUT
	rts

ERRORCK:
	bcs SOS_ERROR
NoError:
	rts
SOS_ERROR:
	jmp QUIT

;---------------------------------------------------------
; READ_LINE
;
; Read a line of input from the console
;---------------------------------------------------------
READ_LINE:
	jsr ECHO_ON
	lda #$ff
	sta CONSREAD_COUNT
	CALLOS OS_READFILE, CONSREAD_PARMS
	jsr ERRORCK				; Output is available at CONSREAD_INPUT
						; for CONSREAD_COUNT bytes
	jsr ECHO_OFF

	rts
	
;---------------------------------------------------------
; ECHO_ON|OFF - turn keypress echo on or off
;---------------------------------------------------------
ECHO_ON:
	lda #$05
	jsr COUT		; Turn cursor on
	lda #$80
	sta D_CONTROL_DATA
	jmp ECHO_GO
ECHO_OFF:
	lda #$06
	jsr COUT		; Turn cursor off
	lda #$00
	sta D_CONTROL_DATA
ECHO_GO:
	lda #$0B
	sta D_CONTROL_CODE
	CALLOS OS_D_CONTROL, D_CONTROL_PARMS	; Turn screen echo on
	clc
	rts

;---------------------------------------------------------
; Character output
; 
; Send one character to the console from Accumulator
; Special case: CROUT, which prints a carriage return
;---------------------------------------------------------
CROUT:	; Output return character
	lda #$0d
COUT:	; Character output routine (print to screen)
COUT1:	; Character output
	sta WRITE1_DATA
	CALLOS OS_WRITEFILE, WRITE1_PARMS
	clc
	rts

;---------------------------------------------------------
; CLRMSGAREA - Clear out the bottom part of the screen
;---------------------------------------------------------
CLRMSGAREA:
	lda #<CLRMSGAREA_DATA
	sta UTILPTR
	lda #>CLRMSGAREA_DATA
	sta UTILPTR+1
	lda #$03
	sta WRITE_LEN
	jsr WRITEMSG_RAW

CLRMSGAREA_DATA:
	.byte $19,$16,$1d

;---------------------------------------------------------
; INVERSE - Invert/highlight the characters on the screen
;
; Inputs:
;   A - number of bytes to process
;   X - starting x coordinate
;   Y - starting y coordinate
;---------------------------------------------------------
INVERSE:
	sta INUM
	jsr GOTOXY
	lda #$12		; Code for start printing in inverse
	jsr COUT
	ldx INUM
:	jsr READVID
	jsr COUT		; Reflect the characters on screen, inverted!
	dex
	bne :-
	lda #$11		; Code for start printing normally
	jsr COUT
	rts

INUM:	.byte $00

;---------------------------------------------------------
; SET_INVERSE - Set output to inverse mode
; SET_NORMAL - Set output to normal mode
;---------------------------------------------------------
SET_INVERSE:
	lda #$12		; Code for start printing in inverse
	jsr COUT
	rts
SET_NORMAL:
	lda #$11		; Code for start printing normally
	jsr COUT
	rts

;---------------------------------------------------------
; PRBYTE: Print Byte routine (HEX value)
;---------------------------------------------------------
PRBYTE:	
	PHA		; PRINT BYTE AS 2 HEX
	LSR		; DIGITS, DESTROYS A-REG
	LSR
	LSR
	LSR
	JSR PRHEXZ
	PLA
PRHEX:	AND #$0F	; PRINT HEX DIG IN A-REG
PRHEXZ:	ORA #$B0	;  LSB'S
	CMP #$BA
	BCC MyCOUT
	ADC #$06
MyCOUT:	JMP COUT
	rts

;---------------------------------------------------------
; READVID:
; 
; Read character under cursor
;---------------------------------------------------------
READVID:
	lda #$11
	sta D_STATUS_CODE
	CALLOS OS_D_STATUS, D_STATUS_PARMS
	clc
	lda D_STATUS_DATA
	rts

;---------------------------------------------------------
; TODO: Still Stubs
;---------------------------------------------------------
CLREOP:	; Clear to end of screen
CLREOL:	; Clear to end of line
WAIT:	; Monitor delay: # cycles = (5*A*A + 27*A + 26)/2

rts