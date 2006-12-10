; Ethernet driver for CS8900A
;
; Based on Doc Bacardi's tftp source


	.include "common.i"
	.include "cs8900a.i"


	;.import dbg_dump_eth_header


	.export eth_init
	.export eth_rx
	.export eth_tx

	.export eth_inp
	.export eth_inp_len
	.export eth_outp
	.export eth_outp_len

	.exportzp eth_dest
	.exportzp eth_src
	.exportzp eth_type
	.exportzp eth_data

	.import cs_init
	.import cs_packet_page
	.import cs_packet_data
	.import cs_rxtx_data
	.import cs_tx_cmd
	.import cs_tx_len

	.import cfg_mac
	.import PSSC	; From mainline code

	.macro write_page page, value
	lda #page/2
	ldx #<value
	ldy #>value
	jsr cs_write_page
	.endmacro


	.segment "IP65ZP" : zeropage

eth_packet:	.res 2


	.bss

; input and output buffers
eth_inp_len:	.res 2		; input packet length
eth_inp:	.res 1518	; space for input packet
eth_outp_len:	.res 2		; output packet length
eth_outp:	.res 1518	; space for output packet

; ethernet packet offsets
eth_dest	= 0		; destination address
eth_src		= 6		; source address
eth_type	= 12		; packet type
eth_data	= 14		; packet data


	.code

; initialize, return clc on success
eth_init:
	jsr cs_self_modify
	jsr cs_init
	lda #0			; check magic signature
	jsr cs_read_page
	cpx #$0e
	bne @notfound
	cpy #$63
	bne @notfound

	lda #1
	jsr cs_read_page
	cpx #0
	bne @notfound
	; y contains chip rev

	write_page pp_self_ctl, $0055	; $0114, reset chip

	write_page pp_rx_ctl, $0d05	; $0104, accept individual and broadcast packets
	;write_page pp_rx_ctl, $0d85	; $0104, promiscuous mode

	lda #pp_ia/2			; $0158, write mac address
	ldx cfg_mac
	ldy cfg_mac + 1
	jsr cs_write_page

	lda #pp_ia/2 + 1
	ldx cfg_mac + 2
	ldy cfg_mac + 3
	jsr cs_write_page

	lda #pp_ia/2 + 2
	ldx cfg_mac + 4
	ldy cfg_mac + 5
	jsr cs_write_page

	write_page pp_line_ctl, $00d3	; $0112, enable rx and tx

	clc
	rts

@notfound:
	sec
	rts


; receive a packet
eth_rx:
	lda #$24			; check rx status
EMOD30:	sta cs_packet_page
	lda #$01
EMOD34:	sta cs_packet_page + 1

EMOD43:	lda cs_packet_data + 1
	and #$0d
	bne EMOD6

	sec				; no packet ready
	rts

EMOD6:	lda cs_rxtx_data + 1		; ignore status
EMOD0:	lda cs_rxtx_data

EMOD7:	lda cs_rxtx_data + 1		; read packet length
	sta eth_inp_len + 1
	tax				; save
EMOD1:	lda cs_rxtx_data
	sta eth_inp_len

	lda #<eth_inp			; set packet pointer
	sta eth_packet
	lda #>eth_inp
	sta eth_packet + 1

	ldy #0
	cpx #0				; < 256 bytes left?
	beq cs_tail1

cs_get256:
EMOD2:	lda cs_rxtx_data
	sta (eth_packet),y
	iny
EMOD8:	lda cs_rxtx_data + 1
	sta (eth_packet),y
	iny
	bne cs_get256
	inc eth_packet + 1
	dex
	bne cs_get256

cs_tail1:
	lda eth_inp_len			; bytes left / 2, round up
	lsr
	adc #0
	beq cs_done1
	tax

cs_get:
EMOD3:	lda cs_rxtx_data
	sta (eth_packet),y
	iny
EMOD9:	lda cs_rxtx_data + 1
	sta (eth_packet),y
	iny
	dex
	bne cs_get

cs_done1:
	clc
	rts


; send a packet
eth_tx:
	;jsr dbg_dump_eth_header

	lda #$c9			; ask for buffer space
EMOD10:	sta cs_tx_cmd
	lda #0
EMOD11:	sta cs_tx_cmd + 1

	lda eth_outp_len		; set length
EMOD20:	sta cs_tx_len
	lda eth_outp_len + 1
EMOD21:	sta cs_tx_len + 1
	and #$f8
	beq :+

	;inc $d020
	sec				; oversized packet
	rts

:	lda #<pp_bus_status		; select bus status register
EMOD31:	sta cs_packet_page
	lda #>pp_bus_status
EMOD35:	sta cs_packet_page + 1

EMOD44:	lda cs_packet_data + 1		; wait for space
EMOD40:	ldx cs_packet_data		; add timeout?
	lsr
	bcc EMOD40

	ldax #eth_outp			; send packet
	stax eth_packet

	ldy #0
	ldx eth_outp_len + 1
	beq cs_tail2

cs_send256:
	lda (eth_packet),y
EMOD4:	sta cs_rxtx_data
	iny
	lda (eth_packet),y
EMODA:	sta cs_rxtx_data + 1
	iny
	bne cs_send256
	inc eth_packet + 1	; DLS
	dex
	bne cs_send256

cs_tail2:
	ldx eth_outp_len
	beq cs_done2

cs_send:
	lda (eth_packet),y
EMOD5:	sta cs_rxtx_data
	dex
	beq cs_done2
	iny
	lda (eth_packet),y
EMODB:	sta cs_rxtx_data + 1
	iny
	dex
	bne cs_send

cs_done2:
	clc
	rts


; read X/Y from page A * 2
cs_read_page:
	asl
EMOD32:	sta cs_packet_page
	lda #0
	rol
EMOD36:	sta cs_packet_page + 1
EMOD41:	ldx cs_packet_data
EMOD45:	ldy cs_packet_data + 1
	rts

; write X/Y to page A * 2
cs_write_page:
	asl
EMOD33:	sta cs_packet_page
	lda #0
	rol
EMOD37:	sta cs_packet_page + 1
EMOD42:	stx cs_packet_data
EMOD46:	sty cs_packet_data + 1
	rts

;
; cs_self_modify - make all entry points variable so we can move the
;   uther card around in the Apple
;
cs_self_modify:
	ldy PSSC	; GET SLOT# (0..6)
	iny		; NOW 1..7
	tya
	asl
	asl
	asl
	asl
	clc
	adc #$80	; Now $80+S0 ($c0b0)
; Save off all cs_rxtx_data mods
	sta EMOD0+1
	sta EMOD1+1
	sta EMOD2+1
	sta EMOD3+1
	sta EMOD4+1
	sta EMOD5+1
	clc
	adc #$01	; $c0b1
	sta EMOD6+1
	sta EMOD7+1
	sta EMOD8+1
	sta EMOD9+1
	sta EMODA+1
	sta EMODB+1
; save off all cs_tx_cmd mods
	clc
	adc #$03	; $c0b4
	sta EMOD10+1
	clc
	adc #$01	; $c0b5
	sta EMOD11+1
; save off all cs_tx_len mods
	clc
	adc #$01	; $c0b6
	sta EMOD20+1
	clc
	adc #$01	; $c0b7
	sta EMOD21+1
; save off all cs_packet_page mods
	clc
	adc #$03	; $c0ba
	sta EMOD30+1
	sta EMOD31+1
	sta EMOD32+1
	sta EMOD33+1
	clc
	adc #$01	; $c0bb
	sta EMOD34+1
	sta EMOD35+1
	sta EMOD36+1
	sta EMOD37+1
; save off all cs_packet_data mods
	clc
	adc #$01	; $c0bc
	sta EMOD40+1
	sta EMOD41+1
	sta EMOD42+1
	clc
	adc #$01	; $c0bd
	sta EMOD43+1
	sta EMOD44+1
	sta EMOD45+1
	sta EMOD46+1
	rts