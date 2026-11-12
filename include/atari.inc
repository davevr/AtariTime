; =====================================================================
;  ATARI.INC -- hardware registers and OS equates for the Atari 400/800
;
;  The names are the ones from the Atari OS listing and "De Re Atari".
;  Include it at the top of a program with:
;
;        icl 'atari.inc'
;
;  Nothing here generates code or reserves memory; it is equates only.
;
;  Remember the rule about shadows: during every vertical blank the OS
;  copies its RAM "shadow" of a register into the hardware.  So in
;  ordinary code you store into the SHADOW (COLOR2, SDLSTL, SDMCTL...)
;  and the change sticks.  Store into the HARDWARE register (COLPF2,
;  DLISTL, DMACTL...) only when you want the change now and only for
;  this frame -- which is exactly what a display list interrupt does.
; =====================================================================

; ---------------------------------------------------------------------
;  PAGE ZERO
; ---------------------------------------------------------------------
RTCLOK  = $12           ; 3-byte frame counter, $14 ticks every VBLANK
ATRACT  = $4D           ; attract mode timer; store 0 to stop colour cycling
LMARGN  = $52           ; text left margin (normally 2)
RMARGN  = $53           ; text right margin (normally 39)
ROWCRS  = $54           ; cursor row
COLCRS  = $55           ; cursor column (2 bytes)
SAVMSC  = $58           ; address of the first byte of screen memory (2 bytes)
RAMTOP  = $6A           ; top of RAM, in pages

; ---------------------------------------------------------------------
;  PAGE TWO -- interrupt vectors and timers
; ---------------------------------------------------------------------
VDSLST  = $0200         ; display list interrupt vector (2 bytes)
CDTMV1  = $0218         ; countdown timer 1 value (2 bytes)
CDTMV2  = $021A         ; countdown timer 2
CDTMV3  = $021C         ; countdown timer 3
CDTMV4  = $021E         ; countdown timer 4
CDTMV5  = $0220         ; countdown timer 5
VVBLKI  = $0222         ; immediate vertical blank vector (2 bytes)
VVBLKD  = $0224         ; deferred vertical blank vector (2 bytes)
CDTMA1  = $0226         ; timer 1 jump address
CDTMA2  = $0228         ; timer 2 jump address
CDTMF3  = $022A         ; timer 3 flag
CDTMF4  = $022C         ; timer 4 flag
CDTMF5  = $022E         ; timer 5 flag

; ---------------------------------------------------------------------
;  PAGE TWO -- OS shadows of hardware registers
; ---------------------------------------------------------------------
SDMCTL  = $022F         ; shadow of DMACTL
SDLSTL  = $0230         ; shadow of DLISTL
SDLSTH  = $0231         ; shadow of DLISTH
SSKCTL  = $0232         ; shadow of SKCTL
COLDST  = $0244         ; coldstart flag
GPRIOR  = $026F         ; shadow of PRIOR

PADDL0  = $0270         ; paddles 0-7 (shadows of POT0-7)
PADDL1  = $0271
PADDL2  = $0272
PADDL3  = $0273
PADDL4  = $0274
PADDL5  = $0275
PADDL6  = $0276
PADDL7  = $0277

STICK0  = $0278         ; joystick 1: bit 0 up, 1 down, 2 left, 3 right
STICK1  = $0279         ;   a bit is 0 when the stick is pushed that way,
STICK2  = $027A         ;   so 15 = centred, 14 = up, 13 = down,
STICK3  = $027B         ;   11 = left, 7 = right

PTRIG0  = $027C         ; paddle triggers 0-7 (0 = pressed)
PTRIG1  = $027D
PTRIG2  = $027E
PTRIG3  = $027F
PTRIG4  = $0280
PTRIG5  = $0281
PTRIG6  = $0282
PTRIG7  = $0283

STRIG0  = $0284         ; joystick 1 trigger (0 = pressed)
STRIG1  = $0285
STRIG2  = $0286
STRIG3  = $0287

TXTROW  = $0290         ; text window cursor row
TXTCOL  = $0291         ; text window cursor column (2 bytes)

PCOLR0  = $02C0         ; shadow of COLPM0  player/missile 0 colour
PCOLR1  = $02C1         ; shadow of COLPM1
PCOLR2  = $02C2         ; shadow of COLPM2
PCOLR3  = $02C3         ; shadow of COLPM3
COLOR0  = $02C4         ; shadow of COLPF0
COLOR1  = $02C5         ; shadow of COLPF1  (GR.0: text luminance)
COLOR2  = $02C6         ; shadow of COLPF2  (GR.0: text background)
COLOR3  = $02C7         ; shadow of COLPF3
COLOR4  = $02C8         ; shadow of COLBK   (background / border)

RUNAD   = $02E0         ; run address of a binary load file (2 bytes)
INITAD  = $02E2         ; init address of a binary load file (2 bytes)
MEMTOP  = $02E5         ; top of free memory (2 bytes)
MEMLO   = $02E7         ; bottom of free memory (2 bytes)
CRSINH  = $02F0         ; cursor inhibit: non-zero hides the cursor
CHACT   = $02F3         ; shadow of CHACTL
CHBAS   = $02F4         ; shadow of CHBASE (normally $E0)
CH      = $02FC         ; last key pressed, internal code; $FF = none

; ---------------------------------------------------------------------
;  PAGE THREE -- IOCB 0.  Add 16 * channel in X for the other IOCBs.
; ---------------------------------------------------------------------
ICHID   = $0340         ; handler ID
ICDNO   = $0341         ; device number
ICCOM   = $0342         ; command
ICSTA   = $0343         ; status
ICBAL   = $0344         ; buffer address low
ICBAH   = $0345         ; buffer address high
ICPTL   = $0346         ; put-byte routine address - 1
ICPTH   = $0347
ICBLL   = $0348         ; buffer length low
ICBLH   = $0349         ; buffer length high
ICAX1   = $034A         ; auxiliary byte 1
ICAX2   = $034B         ; auxiliary byte 2

; CIO commands for ICCOM
OPEN    = $03
GETREC  = $05           ; get record (up to an EOL)
GETCHR  = $07           ; get characters
PUTREC  = $09           ; put record (up to an EOL)
PUTCHR  = $0B           ; put characters
CLOSE   = $0C

EOL     = $9B           ; ATASCII end of line

; ---------------------------------------------------------------------
;  GTIA  $D000 -- colour, player/missile graphics, collisions, triggers
;  The same address means one thing written and another thing read.
; ---------------------------------------------------------------------
; -- write --
HPOSP0  = $D000         ; horizontal position of player 0
HPOSP1  = $D001
HPOSP2  = $D002
HPOSP3  = $D003
HPOSM0  = $D004         ; horizontal position of missile 0
HPOSM1  = $D005
HPOSM2  = $D006
HPOSM3  = $D007
SIZEP0  = $D008         ; player 0 width: 0 normal, 1 double, 3 quadruple
SIZEP1  = $D009
SIZEP2  = $D00A
SIZEP3  = $D00B
SIZEM   = $D00C         ; widths of all four missiles, 2 bits each
GRAFP0  = $D00D         ; player 0 graphics, when not using ANTIC DMA
GRAFP1  = $D00E
GRAFP2  = $D00F
GRAFP3  = $D010
GRAFM   = $D011         ; missile graphics, when not using ANTIC DMA
COLPM0  = $D012         ; colour of player/missile 0
COLPM1  = $D013
COLPM2  = $D014
COLPM3  = $D015
COLPF0  = $D016         ; playfield colour 0
COLPF1  = $D017         ; playfield colour 1
COLPF2  = $D018         ; playfield colour 2
COLPF3  = $D019         ; playfield colour 3
COLBK   = $D01A         ; background colour
PRIOR   = $D01B         ; priority select, fifth player, GTIA modes
VDELAY  = $D01C         ; vertical delay
GRACTL  = $D01D         ; bit 0 missiles on, bit 1 players on, bit 2 latch triggers
HITCLR  = $D01E         ; any write clears all the collision registers
CONSOL  = $D01F         ; write: speaker.  read: START/SELECT/OPTION

; -- read --
M0PF    = $D000         ; missile 0 to playfield collisions
M1PF    = $D001
M2PF    = $D002
M3PF    = $D003
P0PF    = $D004         ; player 0 to playfield collisions
P1PF    = $D005
P2PF    = $D006
P3PF    = $D007
M0PL    = $D008         ; missile 0 to player collisions
M1PL    = $D009
M2PL    = $D00A
M3PL    = $D00B
P0PL    = $D00C         ; player 0 to player collisions
P1PL    = $D00D
P2PL    = $D00E
P3PL    = $D00F
TRIG0   = $D010         ; joystick 1 trigger (0 = pressed)
TRIG1   = $D011
TRIG2   = $D012
TRIG3   = $D013
PAL     = $D014         ; bits 1-3 clear on a PAL machine

; CONSOL bits when read (a bit is 0 while the key is down)
CONSTART = $01
CONSELECT = $02
CONOPTION = $04

; ---------------------------------------------------------------------
;  POKEY  $D200 -- sound, paddles, keyboard, serial, random numbers
; ---------------------------------------------------------------------
; -- write --
AUDF1   = $D200         ; voice 1 frequency (divider)
AUDC1   = $D201         ; voice 1 control: distortion in bits 5-7, volume 0-3
AUDF2   = $D202
AUDC2   = $D203
AUDF3   = $D204
AUDC3   = $D205
AUDF4   = $D206
AUDC4   = $D207
AUDCTL  = $D208         ; audio control: clocks, filters, 16-bit joins
STIMER  = $D209         ; start the timers
SKREST  = $D20A         ; reset serial status
POTGO   = $D20B         ; start the paddle scan
SEROUT  = $D20D         ; serial output byte
IRQEN   = $D20E         ; IRQ enable
SKCTL   = $D20F         ; serial port control

; -- read --
POT0    = $D200         ; paddle 0-7 raw values
POT1    = $D201
POT2    = $D202
POT3    = $D203
POT4    = $D204
POT5    = $D205
POT6    = $D206
POT7    = $D207
ALLPOT  = $D208         ; paddle scan status
KBCODE  = $D209         ; keyboard code
RANDOM  = $D20A         ; a new random byte every time you look
SERIN   = $D20D         ; serial input byte
IRQST   = $D20E         ; IRQ status
SKSTAT  = $D20F         ; serial/keyboard status

; ---------------------------------------------------------------------
;  PIA  $D300 -- joystick ports
; ---------------------------------------------------------------------
PORTA   = $D300         ; sticks 1 and 2: low nybble stick 1, high stick 2
PORTB   = $D301         ; sticks 3 and 4 on the 400/800
PACTL   = $D302         ; port A control
PBCTL   = $D303         ; port B control

; ---------------------------------------------------------------------
;  ANTIC  $D400 -- display list, DMA, scrolling, NMIs
; ---------------------------------------------------------------------
DMACTL  = $D400         ; DMA control: playfield width, P/M DMA, P/M resolution
CHACTL  = $D401         ; character control: inverse, blank, upside down
DLISTL  = $D402         ; display list pointer low
DLISTH  = $D403         ; display list pointer high
HSCROL  = $D404         ; horizontal fine scroll
VSCROL  = $D405         ; vertical fine scroll
PMBASE  = $D407         ; high byte of the player/missile memory address
CHBASE  = $D409         ; high byte of the character set address
WSYNC   = $D40A         ; any write halts the 6502 until the end of the scan line
VCOUNT  = $D40B         ; current scan line divided by 2
PENH    = $D40C         ; light pen horizontal
PENV    = $D40D         ; light pen vertical
NMIEN   = $D40E         ; NMI enable: $40 = VBI only, $C0 = VBI and DLI
NMIRES  = $D40F         ; write: reset NMI status
NMIST   = $D40F         ; read:  NMI status

; Display list instructions.  OR the mode number with the option bits.
DLBLANK1 = $00          ; 1 blank scan line   ($10 = 2 ... $70 = 8)
DLBLANK8 = $70          ; 8 blank scan lines
DLJMP   = $01           ; jump to address
DLJVB   = $41           ; jump to address and wait for vertical blank
DLHSCRL = $10           ; option: horizontal fine scroll on this line
DLVSCRL = $20           ; option: vertical fine scroll on this line
DLLMS   = $40           ; option: load memory scan, 2 address bytes follow
DLDLI   = $80           ; option: display list interrupt at end of this line

; ---------------------------------------------------------------------
;  OS ROM VECTORS
; ---------------------------------------------------------------------
CIOV    = $E456         ; central I/O
SIOV    = $E459         ; serial I/O
SETVBV  = $E45C         ; set VBLANK vector or timer: A = which,
                        ;   X = address high, Y = address low
                        ;   A = 6 immediate VBI, A = 7 deferred VBI
SYSVBV  = $E45F         ; exit from an immediate VBI: JMP SYSVBV
XITVBV  = $E462         ; exit from a deferred VBI:   JMP XITVBV
WARMSV  = $E474         ; warm start (same as SYSTEM RESET)
COLDSV  = $E477         ; cold start (same as power on)
