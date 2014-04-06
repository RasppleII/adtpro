;
; ADTPro - Apple Disk Transfer ProDOS
; Copyright (C) 2006 - 2014 by David Schmidt
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

	.import udp_send_nocopy
	.import udp_send
	.import udp_send_len
	.import udp_send_len
	.import ip_inp
	.import udp_inp
	.import udp_outp

	.importzp ip_src
	.importzp udp_src_port
	.importzp udp_data

;---------------------------------------------------------
; UDPDISPATCH - Dispatch the UDP packet to the receiver
;---------------------------------------------------------
UDPDISPATCH:
	lda state
	cmp #STATE_IDLE		; Do we care at all?
	beq UDPSKIP

	lda TMOT
	bne TIMEOUTENTRY	; Skip packet processing if timeout occurred

	lda udp_inp + udp_data	; Grab the packet number
	cmp PREVPACKET
	beq UDPSKIP		; We received a duplicate packet.  Bail.
	sta PREVPACKET

	lda udp_inp + udp_src_port + 1
	sta replyport
	lda udp_inp + udp_src_port
	sta replyport + 1

	ldx #3
:	lda ip_inp + ip_src,x
	sta replyaddr,x
	dex
	bpl :-

TIMEOUTENTRY:
	lda state
	php
	ldx #STATE_IDLE	; Set state back to idle
	stx state
	plp

			; Receiving a DIR reply?
	cmp #STATE_DIR
	bne :+
	jmp DIRREPLY1
			; Receiving a CD reply?
:	cmp #STATE_CD
	bne :+
	jmp CDREPLY1
			; Receiving a PUT reply?
:	cmp #STATE_PUT
	bne :+
	jmp PUTREPLY1
			; Receiving a GET return code reply?
:	cmp #STATE_GET
	bne :+
	jmp GETREPLY1
			; Receiving a QUERY FN reply?
:	cmp #STATE_QUERY
	bne :+
	jmp QUERYFNREPLY1
			; Receiving HBLK data?
:	cmp #STATE_RECVHBLK
	bne :+
	jmp RECVHBLK
			; Receiving BATCH data?
:	cmp #STATE_BATCH
	bne :+
	jmp BATCHREPLY1
:			; fallthrough	
UDPSKIP:
	rts

;---------------------------------------------------------
; RECEIVE_LOOP - Wait for an incoming packet to come along
; 
;---------------------------------------------------------
RECEIVE_LOOP_FAST:
	lda #$1f
	sta PauseValue+1	; Short pause
	lda #$00
	jmp RECEIVE_LOOP_ENTRY2

RECEIVE_LOOP:
				; Note: the first byte of
				; this routine needs to be
				; kept in sync with the
				; byte kept in uther.asm,
	lda #$00		; PATCHUTHER.
	sta PauseValue+1	; Long pause
RECEIVE_LOOP_ENTRY2:
	sta TIMEOUT
	sta TMOT

RECEIVE_LOOP_WARM:
	GO_SLOW		; Slow down for SOS
	jsr ip65_process
	GO_FAST		; Speed back up for SOS
	lda $C000
	cmp #CHR_ESC	; Escape = abort
	bne :+
	jmp BABORT
:	bit $c010	; Strobe the keyboard
	inc TIMEOUT	; Increment our counter
	bne :+
	inc TMOT
	jsr UDPDISPATCH
	rts

:	lda state
	cmp #STATE_IDLE		; Are we done/idle now?
	bne RECEIVE_LOOP_PAUSE	; No, so pause a bit then retry
	rts

RECEIVE_LOOP_PAUSE:
	lda #$5a
	sta $c05a
	sta $c05a
	sta $c05a
	sta $c05a	; Unlock ZipChip

	lda #$00
	sta $c05a	; Disable ZipChip	

	lda #$01
	sta $C074	; Disable TransWarp

PauseValue:
	lda #$7f
	jsr DELAY	; Wait!

	lda #$00
	sta $c05b	; Enable ZipChip

	lda #$a5
	sta $c05a	; Lock ZipChip

	lda #$00	; Enable TransWarp
	sta $C074

	jmp RECEIVE_LOOP_WARM

TIMEOUT:	.res 1

;---------------------------------------------------------
; PINGREQUEST - Send out a ping
;---------------------------------------------------------
PINGREQUEST:
	lda #STATE_IDLE	; Don't want any reply
	sta state
	lda #CHR_Y
	jsr PUTC
	jsr RECEIVE_LOOP_FAST
	rts

;---------------------------------------------------------
; DIRREQUEST - Request current directory contents
;---------------------------------------------------------
DIRREQUEST:
	lda #STATE_DIR	; Set up for DIRREPLY1 callback
	sta state
	lda #CHR_D
	jsr PUTC
	jsr RECEIVE_LOOP_FAST
	rts

;---------------------------------------------------------
; DIRREPLY - serial compatibility and UDP callback entry points
;---------------------------------------------------------
DIRREPLY1:
	ldax #udp_inp + udp_data + 1	; Point Buffer at the UDP data buffer
	stax Buffer
DIRREPLY:
	rts

;---------------------------------------------------------
; DIRABORT - Abort current directory contents
;---------------------------------------------------------
DIRABORT:
	lda #$00
	jsr PUTC
	rts

;---------------------------------------------------------
; CDREQUEST - Request current directory change
;---------------------------------------------------------
CDREQUEST:
	ldax #udp_inp + udp_data + 1	; Point Buffer at the UDP data buffer
	stax Buffer
	ldy #$00
	lda #CHR_C
	sta (Buffer),Y
	iny
	jsr COPYINPUT
	tya			; Max CD request will be 255 bytes
	ldx #$00		; It's unlikely the $200 buffer is
	stax udp_send_len	; much bigger than that anyway...
	lda #STATE_CD
	sta state
	GO_SLOW				; Slow down for SOS
	ldax Buffer
	jsr udp_send
	GO_FAST				; Speed back up for SOS
	jsr RECEIVE_LOOP_FAST
	rts

;---------------------------------------------------------
; CDREPLY - Reply to current directory change
; PUTREPLY - Reply from send an image to the host
; BATCHREPLY - Reply from send multiple images to the host
; GETREPLY - Reply from requesting an image be sent from the host
; One-byte replies
;---------------------------------------------------------
CDREPLY1:
PUTREPLY1:
BATCHREPLY1:
GETREPLY1:
	lda TMOT
	bne @Repl1
	lda udp_inp + udp_data + 1	; Pick up the data byte
	jmp @Repl2
@Repl1:	lda #PHMTIMEOUT			; Load up timeout indicator
@Repl2:	sta QUERYRC
CDREPLY:
PUTREPLY:
BATCHREPLY:
GETREPLY:
	clc
	lda TMOT
	beq @Ok
	sec
@Ok:	lda QUERYRC
	rts

GETREPLY2:
	lda #STATE_GET	; Set up for GETREPLY1 callback
	sta state
	jsr RECEIVE_LOOP_FAST
	clc
	lda TMOT
	beq @Ok
	sec
@Ok:	lda QUERYRC
	rts	

;---------------------------------------------------------
; PUTREQUEST - Request to send an image to the host
; SendType holds request type:
; CHR_P - typical put
; CHR_N - nibble send
; CHR_H - half track send
;---------------------------------------------------------
PUTREQUEST:
	ldax #udp_inp + udp_data + 1	; Point Buffer at the UDP data buffer
	stax Buffer
	ldy #$00
	lda SendType
	sta (Buffer),Y		; Accumulator still holds request type
	iny
	cmp #CHR_N		; Nibble send?
	beq PUTNIBBLE		; Branch away if so
	jsr COPYINPUT
	lda NUMBLKS		; Send the total block size
	sta (Buffer),Y
	iny
	lda NUMBLKS+1
	sta (Buffer),Y
	iny
	tya
	ldx #$00
	stax udp_send_len
	lda #STATE_PUT
	sta state
	GO_SLOW			; Slow down for SOS
	ldax Buffer
	jsr udp_send
	GO_FAST			; Speed back up for SOS
	jsr RECEIVE_LOOP_FAST
	rts

PUTNIBBLE:
	lda #$01		; Copy in the protocol initialization: $01, $01, $00
	sta (Buffer),Y
	iny
	sta (Buffer),Y
	iny
	lda #$00
	sta (Buffer),Y
	iny
	tya
	ldx #$00
	stax udp_send_len
	lda #STATE_PUT		; Set up for one-byte response
	sta state
	GO_SLOW			; Slow down for SOS
	ldax Buffer
	jsr udp_send
	GO_FAST			; Speed back up for SOS
	jsr RECEIVE_LOOP_FAST
	lda QUERYRC
	cmp #CHR_ACK
	beq :+
	lda #PHMGBG		; Failed protocol negotiation
	jmp PCERROR
:	ldy #$00
	jsr COPYINPUT
	tya
	ldx #$00
	stax udp_send_len
	lda #STATE_PUT
	sta state
	GO_SLOW			; Slow down for SOS
	ldax Buffer
	jsr udp_send
	GO_FAST			; Speed back up for SOS
	jsr RECEIVE_LOOP_FAST
	rts


;---------------------------------------------------------
; PUTINITIALACK - Send initial ACK for a PUTREQUEST/PUTREPLY
;---------------------------------------------------------
PUTINITIALACK:
	lda #CHR_ACK
	jsr PUTC
	rts

;---------------------------------------------------------
; PUTFINALACK - Send error count for PUT request
;---------------------------------------------------------
PUTFINALACK:
	lda ECOUNT	; Errors during send?
	jsr PUTC	; Send error flag to host
	rts

;---------------------------------------------------------
; GETFINALACK -
;---------------------------------------------------------
GETFINALACK:
	ldy #$00
        sty udp_send_len
        sty udp_send_len+1
	ldax #udp_outp + udp_data
	stax UTILPTR
	lda #CHR_ACK
	jsr BUFBYTE	; Send last ACK
	lda BLKLO	
	jsr BUFBYTE	; Send the block number (LSB)
	lda BLKHI
	jsr BUFBYTE	; Send the block number (MSB)
	lda <ZP
	jsr BUFBYTE	; Send the half-block number
	lda ECOUNT
	jsr BUFBYTE	; Send number of errors encountered
	GO_SLOW				; Slow down for SOS
	jsr udp_send_nocopy
	GO_FAST				; Speed back up for SOS
	rts

;---------------------------------------------------------
; GETREQUEST -
;---------------------------------------------------------
GETREQUEST:
	ldax #udp_inp + udp_data + 1	; Point Buffer at the UDP data buffer
	stax Buffer
	ldy #$00
	lda #CHR_G	; Ask host to send the file
	sta (Buffer),Y
	iny
	jsr COPYINPUT
	tya
	ldx #$00
	stax udp_send_len
	lda #STATE_GET	; Set up for GETREPLY1 callback
	sta state
	GO_SLOW				; Slow down for SOS
	ldax Buffer
	jsr udp_send
	GO_FAST				; Speed back up for SOS
	jsr RECEIVE_LOOP_FAST
	rts

;---------------------------------------------------------
; BATCHREQUEST - Request to send multiple images to the host
;---------------------------------------------------------
BATCHREQUEST:
	ldax #udp_inp + udp_data + 1	; Point Buffer at the UDP data buffer
	stax Buffer
	ldy #$00
	lda SendType	; Check if we're sending nibbles in batch
	cmp #CHR_N
	bne BPLAIN
	lda #CHR_M	; Tell host we are sending nibbles in batch
	bne :+
BPLAIN:	lda #CHR_B		; Tell host we are Putting/Sending
:	sta (Buffer),Y
	iny
	jsr COPYINPUT
	lda NUMBLKS		; Send the total block size
	sta (Buffer),Y
	iny
	lda NUMBLKS+1
	sta (Buffer),Y
	iny
	tya
	ldx #$00
	stax udp_send_len
	lda #STATE_PUT
	sta state
	GO_SLOW				; Slow down for SOS
	ldax Buffer
	jsr udp_send
	GO_FAST				; Speed back up for SOS
	jsr RECEIVE_LOOP_FAST
	rts

;---------------------------------------------------------
; QUERYFNREQUEST
;---------------------------------------------------------
QUERYFNREQUEST:
	ldax #udp_inp + udp_data + 1	; Point Buffer at the UDP data buffer
	stax Buffer
	ldy #$00
	lda #CHR_Z	; Ask host for file size
	sta (Buffer),Y
	iny
	jsr COPYINPUT
	tya
	ldx #$00
	stax udp_send_len
	lda #STATE_QUERY	; Set up for the QUERYFNREPLY callback
	sta state
	GO_SLOW				; Slow down for SOS
	ldax Buffer
	jsr udp_send
	GO_FAST				; Speed back up for SOS
	jsr RECEIVE_LOOP_FAST
	rts

;---------------------------------------------------------
; QUERYFNREPLY -
;---------------------------------------------------------
QUERYFNREPLY1:
	lda TMOT
	bne :+
	lda udp_inp + udp_data + 1	; File size lsb
	sta HOSTBLX
	lda udp_inp + udp_data + 2	; File size msb
	sta HOSTBLX+1
	lda udp_inp + udp_data + 3	; Return code/message
	sta QUERYRC			; Just some temp storage
	jmp QUERYFNREPLY
:
	lda #PHMTIMEOUT
	sta QUERYRC
QUERYFNREPLY:
	lda TMOT
	beq @Ok
	sec
	jmp @Done
@Ok:	clc
@Done:	lda QUERYRC
QUERYFNREPLYDONE:
	rts

;---------------------------------------------------------
; SENDNIBPAGE - Send a nibble page with RLE
; CRC is computed and stored
; BLKPTR points to page to send
;---------------------------------------------------------
SENDNIBPAGE:
	ldax #udp_outp + udp_data
	stax UTILPTR
	lda #$02
	sta ZP
	GO_SLOW				; Slow down for SOS
	jsr SENDHBLK
	GO_FAST				; Speed back up for SOS
	lda #STATE_PUT	; Set up callback to PUTREPLY1
	sta state
	jsr RECEIVE_LOOP_FAST
	rts

;---------------------------------------------------------
; SENDBLK - Send a block with RLE
; CRC is sent to host
; BLKPTR points to full block to send - updated here
;---------------------------------------------------------
SENDBLK:
	lda #$02
	sta <ZP
SENDMORE:
	GO_SLOW				; Slow down for SOS
	jsr SENDHBLK
	GO_FAST				; Speed back up for SOS
	lda #STATE_PUT	; Set up callback to PUTREPLY1
	sta state
	jsr RECEIVE_LOOP_FAST
SENDMORE2:
	lda QUERYRC
	cmp #CHR_ACK	; Is it ACK?  Loop back if NAK ($17) or timeout ($08).
	bne SENDMORE
	inc <BLKPTR+1	; Get next 256 bytes
	dec <ZP
	bne SENDMORE
	rts

;---------------------------------------------------------
; SENDHBLK - Send half a block with RLE
; CRC is computed and stored
; BLKPTR points to half block to send
;---------------------------------------------------------
SENDHBLK:
	ldy #$00	; Start at first byte
	sty <CRC	; Clean out CRC
	sty <CRC+1
	sty <RLEPREV
        sty udp_send_len
        sty udp_send_len+1
	ldax #udp_outp + udp_data
	stax UTILPTR

	lda BLKLO
	jsr BUFBYTE	; Send the block number (LSB)
	lda BLKHI
	jsr BUFBYTE	; Send the block number (MSB)
	lda <ZP
	jsr BUFBYTE	; Send the half-block number

SS1:	lda (BLKPTR),Y	; GET BYTE TO SEND
	jsr UPDCRC	; UPDATE CRC
	tax		; KEEP A COPY IN X
	sec		; SUBTRACT FROM PREVIOUS
	sbc <RLEPREV
	stx <RLEPREV	; SAVE PREVIOUS BYTE
	jsr BUFBYTE	; SEND DIFFERENCE
	beq SS3		; WAS IT A ZERO?
	iny		; NO, DO NEXT BYTE
	bne SS1		; LOOP IF MORE TO DO
	jmp SENDHEND	; ELSE finish packet

SS2:	jsr UPDCRC
SS3:	iny		; ANY MORE BYTES?
	beq SS4		; NO, IT WAS 00 UP TO END
	lda (BLKPTR),Y	; LOOK AT NEXT BYTE
	cmp <RLEPREV
	beq SS2		; SAME AS BEFORE, CONTINUE
SS4:	tya		; DIFFERENCE NOT A ZERO
	jsr BUFBYTE	; SEND NEW ADDRESS
	bne SS1		; AND GO BACK TO MAIN LOOP

SENDHEND:
	lda <CRC	; Send the CRC of that block
	jsr BUFBYTE
	lda <CRC+1
	jsr BUFBYTE

	jsr udp_send_nocopy
	rts

;---------------------------------------------------------
; BUFBYTE
; Add accumulator to the outgoing packet
; UTILPTR points to the data we're going to save
;---------------------------------------------------------
BUFBYTE:
	php
	sty UDPI	; Store Y for safe keeping
	ldy #$00
	sta (UTILPTR),Y
	inc UTILPTR
	bne :+
	inc UTILPTR+1
:	inc udp_send_len
	bne :+
	inc udp_send_len+1
:	ldy UDPI	; Restore Y
	plp
	rts

;---------------------------------------------------------
; RECVBLK - Receive a block with RLE
;
; BLKPTR points to full block to receive - updated here
;---------------------------------------------------------
RECVBLK:
	lda #$02
	sta <ZP
	lda #CHR_ACK
	sta ACK_CHAR

RECVMORE:
	lda #$00	; Clear out the new half-block
	tay
CLRLOOP:
	clc
	sta (BLKPTR),Y
	iny
	bne CLRLOOP
        sty udp_send_len
        sty udp_send_len+1
	ldax #udp_outp + udp_data
	stax UTILPTR	; Set up UTILPTR to be our BUFBYTE area
	lda ACK_CHAR
	jsr BUFBYTE	; Send ack/nak
	lda BLKLO
	jsr BUFBYTE	; Send the block number (LSB)
	lda BLKHI
	jsr BUFBYTE	; Send the block number (MSB)
	lda <ZP
	jsr BUFBYTE	; Send the half-block number
	GO_SLOW			; Slow down for SOS
	jsr udp_send_nocopy	; Send our ack package
	GO_FAST			; Speed back up for SOS
	lda #STATE_RECVHBLK	; Set up callback to RECVHBLK
	sta state
	jsr RECEIVE_LOOP_FAST

RECVBLK2:
	lda <CRCY
	bne RECVERR
	jsr UNDIFF
	lda <CRC
	cmp PCCRC
	bne RECVERR
	lda <CRC+1
	cmp PCCRC+1
	bne RECVERR

RECBRANCH:
	lda #CHR_ACK
	sta ACK_CHAR
	inc <BLKPTR+1	; Get next 256 bytes
	dec <ZP
RECOK:	bne RECVMORE
	lda #$00
	rts

RECVERR:
	lda #CHR_NAK	; CRC error, ask for a resend
	sta ACK_CHAR
	jmp RECVMORE

ACK_CHAR: .byte CHR_ACK

RECVNIBCHUNK:
	brk

GETNIBREQUEST:
	brk

;---------------------------------------------------------
; RECVHBLK - Receive half a block with RLE
; CRCY is set to $01 on error, $00 on success
; CRC is computed and stored
;---------------------------------------------------------
HBLKERR:
	lda #$01
	sta <CRCY
	rts

RECVHBLK:
	ldax #udp_inp + udp_data + 1
	stax UTILPTR	; Connect UTILPTR to UDP packet buffer
	lda #$00
	sta RLEPREV	; Used as Y-index to BLKPTR buffer (output)
	sta UDPI	; Used as Y-index to UTILPTR buffer (input)

	ldy #$00
	lda (UTILPTR),Y	; Get block number (lsb)
	sec
	sbc BLKLO
	bne HBLKERR
	iny
	lda (UTILPTR),Y	; Get block number (msb)
	sec
	sbc BLKHI
	bne HBLKERR
	iny
	lda (UTILPTR),Y	; Get half-block
	sec
	sbc ZP
	bne HBLKERR
	clc
	lda <UTILPTR
	adc #$03
	sta <UTILPTR
	bcc RC1
	inc <UTILPTR+1
RC1:
	ldy UDPI
	lda (UTILPTR),Y	; Get next byte out of UDP packet buffer
	beq RC2		; If it's zero, get new index
	iny
	cpy #$00
	bne :+
	inc UTILPTR+1
:	sty UDPI
	ldy RLEPREV
	sta (BLKPTR),Y	; else put char in buffer
	iny		; ...and increment BLKPTR's index
	sty RLEPREV
	bne RC1		; Loop if not at end of buffer
	jmp RCVEND	; ...else done
RC2:
	iny		; Increment the UTILPTR index
	sty UDPI
	cpy #$00
	bne :+
	inc UTILPTR+1
:	lda (UTILPTR),Y	; Get next byte out of UDP packet buffer - the next index
	sta RLEPREV	; Save the new BLKPTR index
	php
	iny		; Increment the UTILPTR index
	sty UDPI
	cpy #$00
	bne :+
	inc UTILPTR+1
:	plp
	bne RC1		; Loop if index <> 0
			; ...else done
RCVEND:
	ldy UDPI
	lda (UTILPTR),Y	; Get next byte out of UDP packet buffer
	sta PCCRC	; Receive the CRC of that block
	iny
	cpy #$00
	bne :+
	inc UTILPTR+1	; Point at next 256 bytes
:	lda (UTILPTR),Y	; Get next byte out of UDP packet buffer
	sta PCCRC+1
	lda #$00
	sta <CRCY
	rts

;---------------------------------------------------------
; PUTC - Send a single byte as a packet
;---------------------------------------------------------
PUTC:
				; Note: the first byte of
				; this routine needs to be
				; kept in sync with the
				; byte kept in uther.asm,
	sta PUTCMSG		; PATCHUTHER.
	ldax #PUTCMSGEND-PUTCMSG
	stax udp_send_len
	GO_SLOW			; Slow down for SOS
	ldax #PUTCMSG
	jsr udp_send
	GO_FAST			; Speed back up for SOS
	rts

;---------------------------------------------------------
; COPYINPUT - Copy data from input area to (Buffer);
; Y is assumed to point to the next available byte
; after (Buffer); Y will point to the next byte on exit
;---------------------------------------------------------
COPYINPUT:
	ldx #$00
@LOOP:	lda IN_BUF,X
	sta (Buffer),Y
	php
	inx
	iny
	plp
	beq @Done
	bne @LOOP
@Done:	rts

;---------------------------------------------------------
; DEBUGMSG - Handy debug routine to print and scroll "you are here"
; messages
;---------------------------------------------------------
;DEBUGMSG:
;	sty SLOWY
;	stx SLOWX
;	pha		; Save the byte to print
;	lda CH
;	sta CH_SAV
;	lda CV
;	sta CV_SAV
;
;	ldy #$00
; :
;	; Scroll messages
;	lda $0480,y	; Line 2
;	sta $0400,y	; Line 1
;	lda $0500,y	; Line 3
;	sta $0480,y	; Line 2
;	lda $0580,y	; Line 4
;	sta $0500,y	; Line 3
;	lda $0600,y	; Line 5
;	sta $0580,y	; Line 4
;	lda $0680,y	; Line 6
;	sta $0600,y	; Line 5
;	lda $0700,y	; Line 7
;	sta $0680,y	; Line 6
;	lda $0780,y	; Line 8
;	sta $0700,y	; Line 7
;	lda $0428,y	; Line 9
;	sta $0780,y	; Line 8
;	lda $04a8,y	; Line 10
;	sta $0428,y	; Line 9
;	lda $0528,y	; Line 11
;	sta $04a8,y	; Line 10
;	lda $05a8,y	; Line 12
;	sta $0528,y	; Line 11
;	lda $0628,y	; Line 13
;	sta $05a8,y	; Line 12
;	; break for progress bar here - five lines
;	lda $0550,y	; Line 19
;	sta $0628,y	; Line 13
;	lda $05d0,y	; Line 20
;	sta $0550,y	; Line 19
;	lda $0650,y	; Line 21
;	sta $05d0,y	; Line 20
;	lda $06d0,y	; Line 22
;	sta $0650,y	; Line 21
;	lda $0750,y	; Line 23
;	sta $06d0,y	; Line 22
;	lda $07d0,y	; Line 24
;	sta $0750,y	; Line 23
;
;	iny
;	cpy #$06
;	bne :-
;
;	lda #$00
;	sta CH
;	lda #$17
;	jsr TABV
;
;	pla		; Retrieve the "you are here" byte to print
;	jsr PRBYTE
;	lda #CHR_SP
;	jsr COUT1
;	lda state	; Retrieve the state
;	jsr PRBYTE
;
;	lda CH_SAV
;	sta CH
;	lda CV_SAV
;	sta CV
;	jsr TABV
;	ldy SLOWY
;	ldx SLOWX
;	rts
;
;CH_SAV:	.byte $00
;CV_SAV:	.byte $00

;---------------------------------------------------------
; Constants
;---------------------------------------------------------
STATE_IDLE	= 0
STATE_DIR	= 1
STATE_CD	= 2
STATE_PUT	= 3
STATE_GET	= 4
STATE_QUERY	= 5
STATE_RECVHBLK	= 6
STATE_SENDHBLK	= 7
STATE_BATCH	= 8

;---------------------------------------------------------
; Variables
;---------------------------------------------------------
PPROTO:	.byte $03	; Ethernet protocol = $03
QUERYRC:
	.byte $00
PUTCMSG:
	.byte $00
PUTCMSGEND:
PREVPACKET:
	.byte $00
