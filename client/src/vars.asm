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

*------------------------------------
* Variables - memory written to
*------------------------------------

CAPBLKS .eq $4000	($20 bytes)
DEVICES .eq CAPBLKS+$20	($100 bytes)
PARMBUF	.eq DEVICES+$0100
BLKLO	.eq PARMBUF+$04
BLKHI	.eq PARMBUF+$05
BIGBUF	.eq $4400
CRCTBLL	.eq $9400	CRC LOW TABLE  ($100 Bytes)
CRCTBLH	.eq $9500	CRC HIGH TABLE ($100 Bytes)
NUMBLKS	.db $00,$00	Number of blocks of a chosen volume
HOSTBLX	.db $00,$00	Number of blocks in a host image
UNITNBR	.db $00		Unit number of chosen volume

*------------------------------------
* Zero page locations (all unused by ProDOS,
* Applesoft, Disk Drivers and the Monitor)
*------------------------------------

* $6-$9, $19-$1e are free
ZP	.eq $06		($01 byte)
UTILPTR	.eq $07		($02 bytes) Used for printing messages
COL_SAV	.eq $09		($01 byte)
RLEPREV	.eq $19		($01 byte)
UNUSED1	.eq $1a		($01 byte)
BLKPTR	.eq $1b		($02 bytes) Used by SEND and RECEIVE
CRC	.eq $1d		($02 bytes) Used by ONLINE, SEND and RECEIVE


*---------------------------------------------------------
* Configuration
*---------------------------------------------------------
PARMNUM	.eq $04		Number of configurable parms
*			Note - add bytes to OLDPARM if this is expanded.
PARMSIZ	.db 7,7,2,2	Number of options for each parm

PARMTXT
	.as -"1"
	.db 0
	.as -"2"
	.db 0
	.as -"3"
	.db 0
	.as -"4"
	.db 0
	.as -"5"
	.db 0
	.as -"6"
	.db 0
	.as -"7"
	.db 0
	.as -"300"
	.db 0
	.as -"1200"
	.db 0
	.as -"2400"
	.db 0
	.as -"4800"
	.db 0
	.as -"9600"
	.db 0
	.as -"19200"
	.db 0
	.as -"115200"
	.db 0
	.as -"YES"
	.db 0
	.as -"NO"
	.db 0
	.as -"YES"
	.db 0
	.as -"NO"
	.db 0


PARMS
PSSC	.db 1		SSC SLOT (2)
PSPEED	.db 6		SSC SPEED (115200)
PSOUND	.db 0		SOUND AT END OF TRANSFER? (YES)
PSAVE	.db 1		Save parms? (NO)
SR_WR_C	.db $00		A place to save the send/receive/read/write character
SLOWA	.db $00		A place to save the Accumulator, speed is not important
SLOWX	.db $00		A place to save the X register, speed is not important
SLOWY	.db $00		A place to save the Y register, speed is not important
PCCRC	.db $00,$00	CRC received from PC

