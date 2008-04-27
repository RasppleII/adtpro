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

	.include "sos/interp.asm"	; Interpreter header
	.include "sos/sosmacros.i"	; OS macros
	.include "sos/sosconst.i"	; OS equates, characters, etc.
	.include "sos/sosvars.asm"
	.include "sos/ethernet/ethmessages.asm"	; Messages
	.include "ip65/common.i"	; More macros - ldax, for example

	.include "sos/interimmain.asm"

;---------------------------------------------------------
; Pull in all the rest of the code
;---------------------------------------------------------
	.include "sos/conio.asm"	; Console I/O
	.include "print.asm"
	.include "sos/online.asm"
	.include "sos/rw.asm"
	.include "sr.asm"
	.include "crc.asm"
	.include "pickvol.asm"
	.include "input.asm"
	.include "hostfns.asm"
	.include "diskii.asm"
	.include "nibble.asm"
	.include "prodos/ethernet/ethproto.asm"
	.include "prodos/ethernet/uther.asm"
	.include "sos/ethernet/ethconfigsos.asm"
	.include "prodos/ethernet/ipconfig.asm"
	.include "sos/format.asm"		; Note: format.asm is its own segment
;	.include "sos/bsave.asm"
; Stubs:
ROM:
DELAY:
CH:
CV:
BLOAD:
BSAVE:
GET_PREFIX:
BLKHI:
BLKLO:
INVFLG:
DevAdr:
DevList:
DevCnt:
BASL = $ff
PEND:
	.segment "DATA"	