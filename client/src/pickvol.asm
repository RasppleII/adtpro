;
; ADTPro - Apple Disk Transfer ProDOS
; Copyright (C) 2006 by David Schmidt
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
; PICKVOL
;   On entry: Y holds the pointer to the top line message
;
; Returns:
;   Index into the device table in A
;   $FF in A if escape was hit
;---------------------------------------------------------
PICKVOL:
	jsr PRINTVOL
	lda #$00
	sta VCURROW
	jsr INVROW
	jsr VOLLOOP
	rts

;---------------------------------------------------------
; VOLLOOP
; 
; Manages the volume screen, returns selection in A
; which is an index into the device table
;---------------------------------------------------------
VOLLOOP:
	lda #$23	; Column
	sta CH
	lda #$15	; Row
	jsr TABV

	jsr RDKEY
	and #$DF	; Convert to upper case

VKEYDN:
	cmp #$8a
	bne VKSPACE
	jmp VKEYD

VKSPACE:
	cmp #$80
	bne VKEYR
	jmp VKEYD

VKEYR:	cmp #$95
	bne VKEYUP

VKEYD:	lda VCURROW
	cmp LASTVOL
	beq LOOPUP	; Loop around to the top again
	jsr INVROW
	inc VCURROW
	jsr INVROW
	jmp VOLLOOP

LOOPUP:
	jsr INVROW
	lda #$00
	sta VCURROW
	jsr INVROW
	jmp VOLLOOP

VKEYUP:	cmp #$8b
	bne VKEYL
	jmp VKEYU

VKEYL:	cmp #$88
	bne VENTER

VKEYU:	lda VCURROW
	beq LOOPDN	; Loop around to bottom again
	jsr INVROW
	dec VCURROW
	jsr INVROW
	jmp VOLLOOP

LOOPDN:
	jsr INVROW
	lda LASTVOL
	sta VCURROW
	jsr INVROW
	jmp VOLLOOP

VENTER:	cmp #$8d	; Process enter
	bne VESC

	lda VCURROW	; Extract unit number
	jsr WHATUNIT
	sta UNITNBR
	and #$70	; Mask off just slot
	lsr
	lsr
	lsr
	lsr
	sta pdslot	; Save default slot
	dec pdslot
	jsr slot2x
	sta pdsoftx	; Save slot * 16 for soft switches
	inc pdslot
	lda #$00
	sta pdrive	; Save default drive number
	lda UNITNBR
	and #$80	; Wait, was that drive 2?
	beq :+
	inc pdrive
:	lda VCURROW	; Extract unit capacity
	clc
	rol		; Multiply by 2
	tax		; X is now the index into blocks table
	lda #$00
	sta NonDiskII	; Assume _no_ Disk II selected
	lda CAPBLKS,X
	sta NUMBLKS
	lda CAPBLKS+1,X
	sta NUMBLKS+1
	cmp #$01	; Do we have a Disk II selected?
	bne :+
	lda NUMBLKS
	cmp #$18	; $180 blocks; assume so
	bne :+
	lda #$01
	sta NonDiskII	; $01 = We _have_ a Disk II
:
	lda VCURROW	; Send the row selection back out
	rts

VESC:	cmp #$9B
	beq ESCAPE
	jmp VOLLOOP	; No, it was an unknown key - loop back around
ESCAPE:
	lda #$FF	; Set accumulator negative - no choice made
	rts		; Back out to caller

;---------------------------------------------------------
; PICKVOL2 - Re-entry to the volume screen; clears the 
;            operator area and lets you pick again
;---------------------------------------------------------
PICKVOL2:
	sty SLOWY
	lda #$00
	sta <CH
	lda #$16
	jsr TABV
	jsr CLREOP
	ldy SLOWY
	jsr DRAWBDR
	jmp VOLLOOP

;---------------------------------------------------------
; INVROW - Inverts the current row
;---------------------------------------------------------
INVROW:
	lda VCURROW
	clc
	adc #VROFFS
	tay
	lda #$24	; The length of line to highlight
	ldx #H_SL	; Start at the "Slot" column
	jsr INVERSE
	rts

VCURROW:	.byte $00
VROFFS	= $05

