*
* ADTPro - Apple Disk Transfer ProDOS
* Copyright (C) 2006 by David Schmidt
* david__schmidt at users.sourceforge.net
*
* This program is free software; you can redistribute it and/or modify it 
* under the terms of the GNU General Public License as published by the 
* Free Software Foundation; either version 2 of the License, or (at your 
* option) any later version.
*
* This program is distributed in the hope that it will be useful, but 
* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
* or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License 
* for more details.
*
* You should have received a copy of the GNU General Public License along 
* with this program; if not, write to the Free Software Foundation, Inc., 
* 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*

*---------------------------------------------------------
* PRINTVOL
* 
* Prints on-line volume information 
*---------------------------------------------------------
PRINTVOL
	JSR HOME	Clear screen
	jsr DRAWBDR
	jsr ONLINE
	rts

*---------------------------------------------------------
* PRT1VOL
*
* Inputs:
*   X register holds the index to the device table
*   Y register is preserved
* Prints one volume's worth of information
* Called from ONLINE
*---------------------------------------------------------
PRT1VOL
	tya
	pha
	stx SLOWX

	lda #H_SL	"Slot" starting column
	sta <CH

	lda DEVICES,X
	and #$70	Mask off length nybble
	lsr
	lsr
	lsr
	lsr		Acc now holds the slot number
	clc
	adc #$B0
	sta PRTSVA
	jsr COUT1

	lda #H_DR	"Drive" starting column
	sta <CH
	lda DEVICES,X
	and #$80
	cmp #$80
	beq PR.DR2
	lda #$B1
	jmp PR.OUT
PR.DR2	lda #$B2
PR.OUT	jsr COUT1

	lda #H_VO	"Volume" starting column
	sta <CH
	lda DEVICES,X
	and #$0f
	sta PRTSVA
	beq PR.VO.DONE
	ldy #$00
PR.LOOP	lda DEVICES+1,X
	ora #$80
	jsr COUT1
	inx
	iny
	cpy PRTSVA
	bne PR.LOOP

	lda #H_SZ	"Size" starting column
	sta <CH

	lda SLOWX	Get a copy of original X into Acc

	beq PR.num
	lsr
	lsr
	lsr
PR.num	tax
	lda CAPBLKS,X
	sta PRTPTR
	lda CAPBLKS+1,X
	sta PRTPTR+1
	jsr PRTNUMB

PR.vo.DONE
	jsr crOUT

	ldx SLOWX
	pla
	tay
	rts

PRTSVA	.db $00
P.OFF	.db $00

*---------------------------------------------------------
* DRAWBDR
* 
* Draws the volume picker decorative border
*---------------------------------------------------------
DRAWBDR
	lda #$09
	sta <CH
	lda #$00
	jsr TABV
	ldy #PMSG18	'SELECT TRANSFER VOLUME'
	jsr SHOWMSG

	lda #$07	Column
	sta <CH
	lda #$02	Row
	JSR TABV
	ldy #PMSG19	'VOLUMES CURRENTLY ON-LINE:'
	jsr SHOWMSG

	lda #H_SL	"Slot" starting column
	sta <CH
	lda #$03	Row
	JSR TABV
	ldy #PMSG20	'SLOT  DRIVE  VOLUME NAME      BLOCKS'
	jsr SHOWMSG

	lda #H_SL	"Slot" starting column
	sta <CH
	lda #$04	Row
	JSR TABV
	ldy #PMSG21	'----  -----  ---------------  ------'
	jsr SHOWMSG

	lda #$00	Column
	sta <CH
	lda #$14	Row
	JSR TABV
	ldy #PMSG22	'CHANGE VOLUME/SLOT/DRIVE WITH ARROW KEYS'
	jsr SHOWMSG

	lda #$04	Column
	sta <CH
	lda #$15	Row
	JSR TABV
	ldy #PMSG23	'SELECT WITH RETURN, ESC CANCELS'
	jsr SHOWMSG

	lda #$05	starting row for slot/drive entries
	JSR TABV
	rts

*---------------------------------------------------------
* PREPPRG
* 
* Sets up the progress screen
*
* Input:
*   NUMBLKS
*   NUMBLKS+1 contain the total capacity of the volume
*---------------------------------------------------------
PREPPRG
	stx SLOWX	Preserve X
	jsr HOME
	lda #H_NUM1	Column
	sta <CH
	lda #V_MSG	Row
	JSR TABV
	ldy #PMSG09
	jsr SHOWMSG
	inc <CH		Space over one character

	lda NUMBLKS
	sta PRTPTR
	lda NUMBLKS+1
	sta PRTPTR+1
	jsr PRTNUM

	lda #$00	Column
	sta <CH
	lda #V_BUF-2	Row
	jsr TABV
	jsr HLINE		Print out a row of underlines
	lda #V_BUF+1	Row
	jsr TABV
	jsr HLINE
	ldx SLOWX	Restore X
	rts

*---------------------------------------------------------
* HLINE - Prints a row of underlines at current cursor position
*---------------------------------------------------------
HLINE
	lda #$df
	ldx #$28
HLINE.1	jsr COUT1
	dex
	bne HLINE.1
	rts


*---------------------------------------------------------
* SHOWMSG - SHOW NULL-TERMINATED MESSAGE #Y AT current
* cursor location.
* Call SHOWM1 to clear/print at message area.
*---------------------------------------------------------
SHOWM1	sty SLOWY
	lda #$00
	sta <CH
	lda #$16
	jsr TABV
	jsr CLREOP
	ldy SLOWY

SHOWMSG	lda MSGTBL,Y
	sta <UTILPTR
	lda MSGTBL+1,Y
	sta <UTILPTR+1

	ldy #$00
MSGLOOP	lda (UTILPTR),Y
	beq MSGEND
	jsr COUT1
	iny
	bne MSGLOOP
MSGEND	rts


*---------------------------------------------------------
* PRTNUM
*
* Prints a right-justified, zero-padded 5-digit number from
* a pointer in PRTPTR/PRTPTR+1 (lo/hi)
*---------------------------------------------------------
PRTNUM
	lda #CHR_0
	sta PADCHR
	jmp PRTIT
PRTNUMB	lda #CHR_SP
	sta PADCHR

PRTIT	lda PRTPTR+1
	cmp #$27
	bcs PRTN.1
	jmp OXXXX	Number is less than $2700
PRTN.1	bne PRTNUM1	Number is > $2700
	lda PRTPTR
	cmp #$10
	bcs PRTN.2
	jmp OXXXX	Number is less than $2710
PRTN.2	jmp PRTNUM1	Number is >= $2710

OXXXX	lda PADCHR
	jsr COUT1
	lda PRTPTR+1
	cmp #$03
	bcs PRTN.3
	jmp OOXXX	Number is less than $0300
PRTN.3	bne PRTN.4	Number is >= $0300
	lda PRTPTR
	cmp #$E8
	bcs PRTN.4
	jmp OOXXX	Number is less than $03e8
PRTN.4	jmp PRTNUM1	Number is >= $03e8

OOXXX	lda PADCHR
	jsr COUT1
	lda PRTPTR+1
	cmp #$00
	bcs PRTN.5
	jmp OOOXX	Number is less than $0064
PRTN.5	bne PRTNUM1	Number is >= $0064
	lda PRTPTR
	cmp #$64
	bcs PRTNUM1

OOOXX	lda PADCHR
	jsr COUT1
	lda PRTPTR
	cmp #$0a
	bcs PRTN.7
	jmp OOOOX	Number is less than $000a
PRTN.7	jmp PRTNUM1	Number is >= $000a

OOOOX	lda PADCHR
	jsr COUT1

PRTNUM1	ldx PRTPTR	LO
	lda PRTPTR+1	HI
	jsr PRDEC

	rts

PADCHR	.db CHR_0
PRTPTR	.db $00,$00

*---------------------------------------------------------
* CHROVER - Write new contents without advancing cursor
*---------------------------------------------------------
CHROVER	ldy <CH
	sta (BASL),Y
	rts

*---------------------------------------------------------
* INVERSE - Invert the characters on the screen
*
* Inputs:
*   A - number of bytes to process
*   X - starting x coordinate
*   Y - starting y coordinate
*---------------------------------------------------------
INVERSE
	clc
	sta INUM
	stx <CH		Set cursor to first position
	txa
	adc INUM
	sta INUM
	tya
	jsr TABV
	ldy <CH
INV.1	lda (BASL),Y
	and #$BF
	eor #$80
	sta (BASL),Y
	iny
	cpy INUM
	bne INV.1
	rts

INUM	.db $00


*---------------------------------------------------------
* Messages
*---------------------------------------------------------

MSGTBL	.da MSG01,MSG02,MSG03,MSG04,MSG05,MSG06,MSG07,MSG08
	.da MSG09,MSG10,MSG11,MSG12,MSG13,MSG14,MSG15,MSG16
	.da MSG17,MSG18,MSG19,MSG20,MSG21,MSG22,MSG23,MSG24
	.da MSG25,MSG26,MSG27,MSG28,MSG29,MSG30,MSG31,MSG32
	.da MSG33,MSG34,MSG35,MSG36,MSG37,MSG38
	.da MSG10a,MSG10b,MSG10c,MSG10d,MSG10e

MSG01	.as -'0.02'
	.db $00
MSG02	.as -'(S)END (R)ECEIVE (D)IR (C)D'
	.db $8d,$8d,$00
MSG03	.as -'CONFI(G) (?)ABOUT (Q)UIT:'
	.db $00
MSG04	.db $8d
	.as -'GOODBYE - THANKS FOR USING ADTPRO!'
	.db $8d,$8d,$00
MSG05	.as -'RECEIVING'
	.db $00
MSG06	.as -'  SENDING'
	.db $00
MSG07	.as -'  READING'
	.db $00
MSG08	.as -'  WRITING'
	.db $00
MSG09	.as -"00000 OF"
	.db $00
MSG10	.db $20,$20,$20,$A0,$A0,$20,$20,$20
	.db $A0,$A0,$20,$A0,$A0,$A0,$20,$8D
	.db $00
MSG11	.db $20,$A0,$A0,$20,$A0,$20,$A0,$A0
	.db $20,$A0,$A0,$20,$A0,$20,$8D
	.db $00
MSG12	.db $20,$A0,$A0,$20,$A0,$20,$A0,$A0
	.db $20,$A0,$A0,$A0,$20,$8D
	.db $00
MSG13	.as -'FILENAME: '
	.db $00
MSG14	.as -'COMPLETE'
	.db $00
MSG15	.as -' - WITH ERRORS'
	.db $00
MSG16	.as -'PRESS A KEY TO CONTINUE...'
	.db $00
MSG17	.as -"PRODOS VERSION AND ENHANCEMENTS BY DAVID"
	.as -"SCHMIDT. BASED ON WORKS BY PAUL GUERTIN,"
	.as -"MARK PERCIVAL, KNUT ROLL-LUND + OTHERS."
	.db $00
MSG18	.as -'SELECT TRANSFER VOLUME'
	.db $00
MSG19	.as -'VOLUMES CURRENTLY ON-LINE:'
	.db $00
MSG20	.as -'SLOT  DRIVE  VOLUME NAME      BLOCKS'
	.db $00
MSG21	.as -'----  -----  ---------------  ------'
	.db $00
MSG22	.as -'CHANGE VOLUME/SLOT/DRIVE WITH ARROW KEYS'
	.db $00
MSG23	.as -'SELECT WITH RETURN, ESC CANCELS'
	.db $00
MSG24	.as -'CONFIGURE ADTPRO PARAMETERS'
	.db $00
MSG25	.as -'CHANGE PARAMETERS WITH ARROW KEYS'
	.db $00
MSG26	.as -'SSC SLOT'
	.db $00
MSG27	.as -'BAUD RATE'
	.db $00
MSG28	.as -'ENABLE SOUND'
	.db $00
MSG29	.as -'SPACE TO CONTINUE, ESC TO STOP: '
	.db $00
MSG30	.as -'END OF DIRECTORY, TYPE SPACE: '
	.db $00
MSG31	.as -'<NO NAME>'
	.db $00
MSG32	.as -'<I/O ERROR>'
	.db $00
MSG33	.as -'<NO DISK>'
	.db $00
MSG34	.as -'FILE EXISTS'
	.db $00
MSG35	.as -'IMAGE/DRIVE SIZE MISMATCH!'
	.db $8d,$00
MSG36	.as -'UNABLE TO OPEN FILE'
	.DB $8d,$00
MSG37	.as -'UNABLE TO CHANGE DIRECTORY'
	.DB $8d,$00
MSG38	.as -'FILE FORMAT NOT RECOGNIZED'
	.DB $8d,$00
MSG10a	.db $a0,$20,$20,$a0,$a0,$20,$20,$20,$a0,$a0,$20,$20,$20,$20,$20,$8d,$00
MSG10b	.db $20,$a0,$a0,$20,$a0,$20,$a0,$a0,$20,$a0,$a0,$a0,$20,$8d,$00
MSG10c	.db $20,$20,$20,$20,$a0,$20,$a0,$a0,$20,$a0,$a0,$a0,$20,$8d,$00
MSG10d	.db $20,$a0,$a0,$20,$a0,$20,$a0,$a0,$20,$a0,$a0,$a0,$20,$8d,$00
MSG10e	.db $20,$a0,$a0,$20,$a0,$20,$20,$20,$a0,$a0,$a0,$a0,$20,$a0
	.as -'PRO'
	.db $8d,$00

*---------------------------------------------------------
* Message equates
*---------------------------------------------------------

PMSG01	.eq $00
PMSG02	.eq $02
PMSG03	.eq $04
PMSG04	.eq $06
PMSG05	.eq $08
PMSG06	.eq $0a
PMSG07	.eq $0c
PMSG08	.eq $0e
PMSG09	.eq $10
PMSG10	.eq $12
PMSG11	.eq $14
PMSG12	.eq $16
PMSG13	.eq $18
PMSG14	.eq $1a
PMSG15	.eq $1c
PMSG16	.eq $1e
PMSG17	.eq $20
PMSG18	.eq $22
PMSG19	.eq $24
PMSG20	.eq $26
PMSG21	.eq $28
PMSG22	.eq $2a
PMSG23	.eq $2c
PMSG24	.eq $2e
PMSG25	.eq $30
PMSG26	.eq $32
PMSG27	.eq $34
PMSG28	.eq $36
PMSG29	.eq $38
PMSG30	.eq $3a
PMSG31	.eq $3c
PMSG32	.eq $3e
PMSG33	.eq $40
PMSG34	.eq $42
PMSG35	.eq $44
PMSG36	.eq $46
PMSG37	.eq $48
PMSG38	.eq $4a
PMSG10a	.eq $4c
PMSG10b	.eq $4e
PMSG10c	.eq $50
PMSG10d	.eq $52
PMSG10e	.eq $54

