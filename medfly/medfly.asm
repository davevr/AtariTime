; =====================================================================
;  MEDFLY INVASION
;
;  You drive a sprayer left and right along the bottom of the screen.
;  The trigger sends a puff of Malathion straight up.  Medflies drift
;  down from the top, changing direction at random; one that reaches
;  the bottom turns round and goes back up, and so on.
;
;  A puff that touches a medfly kills it.  A puff that reaches the
;  middle of the screen without hitting anything falls back down onto
;  the car parked below where you fired from.  Each car can take five
;  doses; it dissolves a bit more with each one, and when a car is
;  completely gone the game is over.
;
;  Wave 1 has one medfly, and each wave has one more than the last.
;  They come out one after another, never more than four on screen.
;  Each medfly picks its own speed when it appears and keeps it; the
;  speeds are higher on later waves.
;
;  HOW IT IS DRAWN
;    medflies   the four PLAYERS of player-missile graphics
;    the puff   MISSILE 0
;    sprayer    two redefined characters in ANTIC mode 4
;    cars       redefined characters in ANTIC mode 4, twelve per car,
;               and every car has its own twelve so that each one can
;               dissolve separately
;    text       ANTIC mode 6 and 7 lines mixed into the display list
;
;  MEMORY
;    $2000  program
;    $3000  screen memory
;    $3800  player-missile graphics (1K, double line resolution)
;    $3C00  character set (1K)
; =====================================================================

        icl 'atari.inc'

SCREEN  = $3000
PMG     = $3800
CHARSET = $3C00

; Player-missile memory, double line resolution: 128 bytes each, one
; byte for every two scan lines.  The first 384 bytes are unused.
MISSILES = PMG+$180
PLAYER0 = PMG+$200
PLAYER1 = PMG+$280
PLAYER2 = PMG+$300
PLAYER3 = PMG+$380

; Where things are in screen memory.  See the display list for why.
STATUS  = SCREEN                ; SCORE 00000  WAVE 00
MSGA    = SCREEN+20+7*40        ; big message line
MSGB    = MSGA+20+40            ; small message line
SPRAYROW = MSGB+20+9*40         ; the row the sprayer drives along
CARROW  = SPRAYROW+40           ; two rows of cars

SCOREDIG = STATUS+6             ; five score digits
WAVEDIG = STATUS+18             ; two wave digits

; In mode 6 and 7 the top two bits of a screen byte choose the colour
; and the other six choose the character.  $40 = colour register 1.
TEXTCOL = $40
ZERO    = $10+TEXTCOL           ; the digit 0 as it sits on the screen
NINE1   = $1A+TEXTCOL           ; one past the digit 9

; Character numbers of the redefined characters.
SPRAYCH = 64                    ; sprayer, 2 characters
CARCH   = 66                    ; cars, 5 cars * 12 characters
CARGLYPH = CHARSET+CARCH*8      ; where car 0's twelve characters live

; Vertical positions, as an index into player-missile memory.  The top
; line of the display is index 16, and each text row is 4 more.
YTOP    = 20                    ; medflies start just under the status line
YBOT    = 91                    ; ... and turn round just above the sprayer
PUFFY0  = 96                    ; the puff leaves the nozzle here
MIDY    = 64                    ; half way up the screen
CARY    = 104                   ; top of the cars

; Horizontal positions, in colour clocks.  The playfield runs from 48
; to 207; a player is 8 wide.
XMIN    = 48
XMAX    = 200

MAXFLY  = 4                     ; one medfly per player
STAGGER = 40                    ; frames between medflies coming out
MOVERATE = 2                    ; frames to wait between sprayer steps

; ---------------------------------------------------------------------
;  Page zero variables
; ---------------------------------------------------------------------
PTR     = $80                   ; general pointers
PTR2    = $82
TEMP    = $84
COUNT   = $85
FLY     = $86                   ; which medfly we are working on
PLRCOL  = $87                   ; sprayer column, 0-38
MOVTMR  = $88                   ; frames until the sprayer may step again
PUFFST  = $89                   ; puff: 0 none, 1 rising, 2 falling
PUFFY   = $8A                   ; puff vertical position
PUFFCAR = $8B                   ; which car the puff falls on if it misses
WAVE    = $8C
TOSPAWN = $8D                   ; medflies of this wave still to come out
ALIVE   = $8E                   ; medflies on screen
SPWNTMR = $8F                   ; frames until the next one comes out
OVER    = $90                   ; non-zero when a car has dissolved
SND1    = $91                   ; sound timers, counted down in the VBI
SND2    = $92
SND3    = $93

FLYON   = $A0                   ; 4 bytes each: is this medfly alive?
FLYX    = $A4                   ; horizontal position
FLYY    = $A8                   ; vertical position
FLYDX   = $AC                   ; +1 or -1 ($FF)
FLYDY   = $B0                   ; +1 or -1 ($FF)
FLYSPD  = $B4                   ; speed, in 256ths of a step per frame
FLYFRC  = $B8                   ; fraction of a step saved up so far

CARHITS = $C0                   ; 5 bytes: doses each car has had

        org $2000

; =====================================================================
;  ONE-TIME SETUP
; =====================================================================
START
        lda #0
        sta SDMCTL              ; screen off while we rearrange things
        sta SND1
        sta SND2
        sta SND3
        lda #19
        sta PLRCOL              ; sprayer starts in the middle

; --- clear screen memory and player-missile memory ---------------------
        lda #<SCREEN
        sta PTR
        lda #>SCREEN
        sta PTR+1
        ldx #4
        jsr CLRPGS
        lda #<PMG
        sta PTR
        lda #>PMG
        sta PTR+1
        ldx #4
        jsr CLRPGS

; --- character set -------------------------------------------------------
; Copy the whole ROM set down into RAM, then draw our own shapes over
; characters 64 and up.  The first 64 are left alone because the text
; lines (modes 6 and 7) can only show the first 64 characters of a set,
; and they must still find the letters and digits there.
        lda #0
        sta PTR
        sta PTR2
        lda #$E0                ; ROM character set is at $E000
        sta PTR+1
        lda #>CHARSET
        sta PTR2+1
        ldx #4                  ; 4 pages = 1024 bytes = 128 characters
        ldy #0
CPYSET  lda (PTR),y
        sta (PTR2),y
        iny
        bne CPYSET
        inc PTR+1
        inc PTR2+1
        dex
        bne CPYSET

        ldx #15                 ; the sprayer: 2 characters, 16 bytes
CPYSPR  lda SPRAYSHP,x
        sta CHARSET+SPRAYCH*8,x
        dex
        bpl CPYSPR

; --- display list and character set ------------------------------------
        lda #<DLIST
        sta SDLSTL
        lda #>DLIST
        sta SDLSTH
        lda #>CHARSET
        sta CHBAS

; --- colours -------------------------------------------------------------
        lda #$46                ; red
        sta COLOR0              ; car bodies
        lda #$0C                ; white
        sta COLOR1              ; car windows, sprayer cab, all the text
        lda #$06                ; grey
        sta COLOR2              ; tyres
        lda #$DA                ; yellow-green
        sta COLOR3              ; sprayer, and the puff (see GPRIOR)
        lda #$00                ; black
        sta COLOR4              ; background
        lda #$28                ; orange
        sta PCOLR0              ; medflies
        sta PCOLR1
        sta PCOLR2
        sta PCOLR3

; --- player-missile graphics ---------------------------------------------
; A missile normally takes the colour of its own player, which would
; make the puff the colour of medfly 0.  Bit 4 of the priority register
; turns on the "fifth player": all four missiles take playfield colour
; 3 instead.  Bit 0 puts players in front of the playfield.
        lda #>PMG
        sta PMBASE              ; ANTIC fetches P/M data from here
        lda #$11
        sta GPRIOR
        lda #$01
        sta SIZEM               ; missile 0 double width: 4 colour clocks
        lda #0
        sta SIZEP0              ; players normal width
        sta SIZEP1
        sta SIZEP2
        sta SIZEP3
        lda #$03
        sta GRACTL              ; let GTIA show players and missiles

; --- sound ---------------------------------------------------------------
        lda #0
        sta AUDCTL
        lda #3
        sta SKCTL
        lda #$10
        sta AUDF1               ; the hiss never changes pitch
        lda #200
        sta AUDF3               ; nor does the buzz

; --- vertical blank routine ----------------------------------------------
; SETVBV changes the vector safely even if a VBLANK arrives half way
; through.  A = 7 means the deferred vector, VVBLKD.
        ldy #<VBI
        ldx #>VBI
        lda #7
        jsr SETVBV

; --- screen on -----------------------------------------------------------
; $2E = normal width playfield ($22) + missile DMA ($04) + player DMA
; ($08), with bit 4 clear for double line resolution.
        lda #$2E
        sta SDMCTL

        jsr SHOWSTAT

; =====================================================================
;  TITLE
; =====================================================================
        lda #<TITLETXT
        ldx #>TITLETXT
        jsr SHOWA
WAITKEY lda #<STARTTXT
        ldx #>STARTTXT
        jsr SHOWB

; START is bit 0 of CONSOL, and reads 0 while the key is down.
WAITST  lda CONSOL
        and #CONSTART
        bne WAITST

; =====================================================================
;  NEW GAME
; =====================================================================
NEWGAME
        lda #0                  ; rub out the messages
        ldy #19
CLRMSG  sta MSGA,y
        sta MSGB,y
        dey
        bpl CLRMSG

        lda #<PMG               ; rub out any medflies and puff left over
        sta PTR
        lda #>PMG
        sta PTR+1
        ldx #4
        jsr CLRPGS

        jsr SHOWSTAT            ; score and wave back to zero

        lda #0
        sta WAVE
        sta ALIVE
        sta OVER
        sta PUFFST
        sta MOVTMR
        ldx #MAXFLY-1
CLRFLY  sta FLYON,x
        dex
        bpl CLRFLY

; --- park five new cars --------------------------------------------------
        ldx #4
NEWCAR  lda #0
        sta CARHITS,x
        lda CARGLO,x            ; this car's own twelve characters
        sta PTR
        lda CARGHI,x
        sta PTR+1
        ldy #95                 ; fresh paint: copy the car shape in
CPYCAR  lda CARSHAPE,y
        sta (PTR),y
        dey
        bpl CPYCAR

        lda CARCODE,x           ; put its characters on the screen,
        sta TEMP                ; six on the top row and the next six
        ldy CARCOL,x            ; directly underneath
        lda #6
        sta COUNT
PUTCAR  lda TEMP
        sta CARROW,y
        clc
        adc #6
        sta CARROW+40,y
        inc TEMP
        iny
        dec COUNT
        bne PUTCAR
        dex
        bpl NEWCAR

; --- sprayer in the middle -----------------------------------------------
        ldy PLRCOL              ; rub out the old one, wherever it was
        lda #0
        sta SPRAYROW,y
        sta SPRAYROW+1,y
        lda #19
        sta PLRCOL
        jsr DRAWSPR

        jsr NEXTWAVE

; =====================================================================
;  MAIN LOOP -- once round per television frame
; =====================================================================
PLAY
        jsr WAITVB
        lda #0
        sta ATRACT              ; the joystick does not reset attract mode
        jsr CHECKHIT
        jsr MOVESPR
        jsr MOVEPUFF
        lda OVER
        bne GAMEOVER
        jsr SPAWN
        jsr MOVEFLY
        jsr CHKWAVE
        jmp PLAY

GAMEOVER
        lda #<OVERTXT
        ldx #>OVERTXT
        jsr SHOWA
        jmp WAITKEY

; =====================================================================
;  WAITVB -- wait for the next vertical blank
;  The OS adds one to RTCLOK+2 in every VBLANK, so wait for it to move.
;  Everything in the main loop then happens while the beam is off the
;  picture, which is why nothing flickers or tears.
; =====================================================================
WAITVB  lda RTCLOK+2
WAITVB1 cmp RTCLOK+2
        beq WAITVB1
        rts

; =====================================================================
;  CHECKHIT -- has the puff touched a medfly?
;
;  GTIA does the work.  While it draws the picture it notices when a
;  missile and a player are lit on the same spot, and sets a bit in a
;  collision register.  M0PL is missile 0 against the players: bit 0
;  for player 0, bit 1 for player 1, and so on.  The bits stay set
;  until something is stored in HITCLR, so we read what happened in the
;  frame just shown and then clear them for the next one.
;
;  Only a rising puff kills.  Once it has turned round it is a miss.
; =====================================================================
CHECKHIT
        lda PUFFST
        cmp #1
        bne HITDONE
        lda M0PL
        and #$0F
        beq HITDONE
        sta TEMP
        ldx #0
HITLOOP lsr TEMP                ; next player's bit into the carry
        bcc HITNEXT
        lda FLYON,x
        beq HITNEXT
        jsr KILLFLY
        jsr ERASEPUF            ; the puff is used up
        lda #0
        sta PUFFST
HITNEXT inx
        cpx #MAXFLY
        bne HITLOOP
HITDONE sta HITCLR
        rts

; ---------------------------------------------------------------------
;  KILLFLY -- medfly X is dead.  Keeps X.
; ---------------------------------------------------------------------
KILLFLY
        stx FLY
        lda #0
        sta FLYON,x
        lda PLRLO,x             ; wipe that player's whole stripe
        sta PTR
        lda PLRHI,x
        sta PTR+1
        ldy #127
        lda #0
KILLCLR sta (PTR),y
        dey
        bpl KILLCLR
        dec ALIVE
        lda #15
        sta SND2                ; squeal
        jsr ADDSCORE
        ldx FLY
        rts

; ---------------------------------------------------------------------
;  ADDSCORE -- ten points
;  The score is not kept anywhere except on the screen.  Add one to the
;  tens digit; if that takes it past 9, put it back to 0 and carry into
;  the digit on its left.
; ---------------------------------------------------------------------
ADDSCORE
        ldx #3                  ; the tens digit
ADDLOOP inc SCOREDIG,x
        lda SCOREDIG,x
        cmp #NINE1
        bne ADDDONE
        lda #ZERO
        sta SCOREDIG,x
        dex
        bpl ADDLOOP
ADDDONE rts

; =====================================================================
;  MOVESPR -- joystick and trigger
;  STICK0 has a bit for each direction, and the bit is 0 when the stick
;  is pushed that way: bit 2 left, bit 3 right.
; =====================================================================
MOVESPR
        lda MOVTMR              ; the sprayer moves a whole character at
        beq CANMOVE             ; a time, so it is only allowed to step
        dec MOVTMR              ; every few frames
        jmp TRIGGER

CANMOVE lda STICK0
        and #$04
        bne NOTLEFT
        lda PLRCOL
        beq NOTLEFT             ; already at the left edge
        jsr ERASESPR
        dec PLRCOL
        jsr DRAWSPR
        lda #MOVERATE
        sta MOVTMR
        jmp TRIGGER

NOTLEFT lda STICK0
        and #$08
        bne TRIGGER
        lda PLRCOL
        cmp #38
        beq TRIGGER             ; already at the right edge
        jsr ERASESPR
        inc PLRCOL
        jsr DRAWSPR
        lda #MOVERATE
        sta MOVTMR

TRIGGER lda STRIG0              ; 0 = pressed
        bne MOVEDONE
        lda PUFFST
        bne MOVEDONE            ; only one puff in the air at a time

        lda #1
        sta PUFFST
        lda #PUFFY0
        sta PUFFY
        lda PLRCOL              ; the nozzle is in the middle of the two
        clc                     ; characters.  Each car has 8 columns of
        adc #1                  ; the screen to itself, so the car below
        lsr                     ; is the nozzle column divided by 8.
        lsr
        lsr
        sta PUFFCAR
        lda PLRCOL              ; a character is 4 colour clocks wide and
        asl                     ; the playfield starts at 48, so the
        asl                     ; nozzle is at 48 + 4 * column + 2
        clc
        adc #XMIN+2
        sta HPOSM0
        jsr DRAWPUF
        lda #15
        sta SND1                ; hiss
MOVEDONE
        rts

; The sprayer characters have bit 7 set.  In mode 4 that swaps colour
; register 2 for register 3 inside the character, which is how the
; sprayer gets a colour the cars don't use.
DRAWSPR ldy PLRCOL
        lda #SPRAYCH+128
        sta SPRAYROW,y
        lda #SPRAYCH+1+128
        sta SPRAYROW+1,y
        rts

ERASESPR
        ldy PLRCOL
        lda #0
        sta SPRAYROW,y
        sta SPRAYROW+1,y
        rts

; =====================================================================
;  MOVEPUFF -- up to the middle of the screen, then down onto a car
;
;  Moving a player or missile sideways is one store into a position
;  register.  Moving it up or down is not: its picture has to be moved
;  along its stripe of memory.  The puff is three bytes tall, so we
;  just rub it out and draw it again.
; =====================================================================
MOVEPUFF
        lda PUFFST
        beq PUFFDONE
        jsr ERASEPUF
        lda PUFFST
        cmp #1
        bne FALLING

        lda PUFFY               ; rising: 2 steps a frame
        sec
        sbc #2
        sta PUFFY
        cmp #MIDY+1
        bcs PUFFSHOW
        lda #2                  ; got to the middle and hit nothing
        sta PUFFST
PUFFSHOW
        jmp DRAWPUF

FALLING lda PUFFY               ; falling: 4 steps a frame
        clc
        adc #4
        sta PUFFY
        cmp #CARY
        bcc PUFFSHOW
        lda #0                  ; landed
        sta PUFFST
        jmp HITCAR
PUFFDONE
        rts

; Missile 0 is the bottom two bits of each missile byte.
DRAWPUF ldy PUFFY
        lda #$03
        sta MISSILES,y
        sta MISSILES+1,y
        sta MISSILES+2,y
        rts

ERASEPUF
        ldy PUFFY
        lda #0
        sta MISSILES,y
        sta MISSILES+1,y
        sta MISSILES+2,y
        rts

; =====================================================================
;  HITCAR -- the puff has come down on car PUFFCAR
;
;  Every car is drawn with its own twelve characters, so we can damage
;  one car by damaging its characters, and the screen itself never has
;  to change.  For each of the 96 bytes we pick one of its four pixels
;  at random and knock it out.  Four doses leave about a third of the
;  car.  The fifth takes the rest, and that ends the game.
; =====================================================================
HITCAR
        lda #15
        sta SND3                ; buzz
        ldx PUFFCAR
        inc CARHITS,x
        lda CARGLO,x
        sta PTR
        lda CARGHI,x
        sta PTR+1
        lda CARHITS,x
        cmp #5
        beq CARGONE

        ldy #95
DISSOLVE
        lda RANDOM              ; POKEY gives a new random byte each read
        and #$03
        tax
        lda (PTR),y
        and PIXMASK,x
        sta (PTR),y
        dey
        bpl DISSOLVE
        rts

CARGONE ldy #95
        lda #0
WIPECAR sta (PTR),y
        dey
        bpl WIPECAR
        lda #1
        sta OVER
        rts

; A mode 4 character is 4 pixels across, 2 bits each.  These masks
; each clear one pixel.
PIXMASK dta %00111111,%11001111,%11110011,%11111100

; =====================================================================
;  SPAWN -- bring out the next medfly of the wave, if it is time
; =====================================================================
SPAWN
        lda TOSPAWN
        beq SPAWNX              ; they are all out
        lda SPWNTMR
        beq SPAWNGO
        dec SPWNTMR
SPAWNX  rts

SPAWNGO ldx #MAXFLY-1           ; look for a player nobody is using
SPAWNFND
        lda FLYON,x
        beq SPAWNIT
        dex
        bpl SPAWNFND
        rts                     ; four on screen already; try next frame

SPAWNIT stx FLY
        lda #1
        sta FLYON,x
        sta FLYDY,x             ; heading down

SPAWNRX lda RANDOM              ; somewhere along the top: throw away
        cmp #XMAX-XMIN+1        ; random numbers until one fits
        bcs SPAWNRX
        adc #XMIN               ; (carry is clear here)
        sta FLYX,x

        lda #YTOP
        sta FLYY,x
        lda #0
        sta FLYFRC,x

        lda RANDOM              ; left or right to begin with:
        and #$02                ; 0 or 2 ...
        sec
        sbc #1                  ; ... makes -1 or +1
        sta FLYDX,x

; Speed = 32 + 8 * wave + a random 0 to 31, in 256ths of a step per
; frame.  The wave is held at 24 so the sum cannot go past 255, which
; is one step every frame.
        lda WAVE
        cmp #24
        bcc SPAWNSPD
        lda #24
SPAWNSPD
        asl
        asl
        asl
        sta TEMP
        lda RANDOM
        and #$1F
        clc
        adc TEMP
        adc #32
        sta FLYSPD,x

        dec TOSPAWN
        inc ALIVE
        lda #STAGGER
        sta SPWNTMR
        jmp DRAWFLY

; =====================================================================
;  MOVEFLY -- move every medfly that is due to move
;
;  Speeds are less than one step a frame, so each medfly saves up
;  fractions.  Add its speed to its fraction byte every frame; when the
;  byte overflows, the carry says it has saved up a whole step.
; =====================================================================
MOVEFLY
        ldx #MAXFLY-1
FLYLOOP stx FLY
        lda FLYON,x
        beq FLYNEXT
        clc
        lda FLYFRC,x
        adc FLYSPD,x
        sta FLYFRC,x
        bcc FLYNEXT
        jsr STEPFLY
FLYNEXT ldx FLY
        dex
        bpl FLYLOOP
        rts

; ---------------------------------------------------------------------
;  STEPFLY -- one step down (or up) and one step sideways for medfly X
; ---------------------------------------------------------------------
STEPFLY
        lda FLYY,x
        clc
        adc FLYDY,x
        sta FLYY,x
        cmp #YBOT
        bcc STEPTOP
        lda #$FF                ; reached the bottom: back up
        sta FLYDY,x
        bne STEPSIDE
STEPTOP cmp #YTOP+1
        bcs STEPSIDE
        lda #1                  ; reached the top: down again
        sta FLYDY,x

STEPSIDE
        lda RANDOM              ; about one step in forty, change its mind
        cmp #6
        bcs STEPX
        lda FLYDX,x             ; +1 becomes -1 and -1 becomes +1
        eor #$FF
        clc
        adc #1
        sta FLYDX,x

STEPX   lda FLYX,x
        clc
        adc FLYDX,x
        sta FLYX,x
        cmp #XMIN+1
        bcs STEPRGT
        lda #1                  ; bounced off the left edge
        sta FLYDX,x
        bne DRAWFLY
STEPRGT cmp #XMAX
        bcc DRAWFLY
        lda #$FF                ; bounced off the right edge
        sta FLYDX,x
                                ; fall through into DRAWFLY

; ---------------------------------------------------------------------
;  DRAWFLY -- put medfly X (also in FLY) on the screen
;
;  The shape table has an empty byte above and below the medfly.  A
;  medfly only ever moves one step at a time, so drawing the shape one
;  byte higher or lower than before automatically rubs out the line it
;  left behind.  No separate erase is needed.
; ---------------------------------------------------------------------
DRAWFLY
        lda FLYX,x
        sta HPOSP0,x            ; HPOSP0-3 are in a row, so ,X picks one
        lda PLRLO,x
        sta PTR
        lda PLRHI,x
        sta PTR+1
        ldy FLYY,x
        dey                     ; start at the empty byte above
        ldx #0
DRAWLP  lda FLYSHP,x
        sta (PTR),y
        iny
        inx
        cpx #10
        bne DRAWLP
        ldx FLY
        rts

; =====================================================================
;  CHKWAVE -- when every medfly is out and dead, start the next wave
; =====================================================================
CHKWAVE
        lda TOSPAWN
        ora ALIVE
        beq NEXTWAVE
        rts

NEXTWAVE
        inc WAVE
        lda WAVE
        sta TOSPAWN             ; wave N has N medflies
        lda #60
        sta SPWNTMR             ; a second's rest first

        ldx #1                  ; add one to the wave number on the
WAVELP  inc WAVEDIG,x           ; screen, the same way as the score
        lda WAVEDIG,x
        cmp #NINE1
        bne WAVEDONE
        lda #ZERO
        sta WAVEDIG,x
        dex
        bpl WAVELP
WAVEDONE
        rts

; =====================================================================
;  TEXT
;  The tables hold plain screen codes.  They are given their colour as
;  they are copied.
; =====================================================================
SHOWSTAT
        ldy #19
SHOWST1 lda STATTXT,y
        ora #TEXTCOL
        sta STATUS,y
        dey
        bpl SHOWST1
        rts

SHOWA   sta PTR                 ; A = low, X = high byte of the text
        stx PTR+1
        ldy #19
SHOWA1  lda (PTR),y
        ora #TEXTCOL
        sta MSGA,y
        dey
        bpl SHOWA1
        rts

SHOWB   sta PTR
        stx PTR+1
        ldy #19
SHOWB1  lda (PTR),y
        ora #TEXTCOL
        sta MSGB,y
        dey
        bpl SHOWB1
        rts

; ---------------------------------------------------------------------
;  CLRPGS -- clear X pages of memory starting at (PTR)
; ---------------------------------------------------------------------
CLRPGS  lda #0
        tay
CLRPGS1 sta (PTR),y
        iny
        bne CLRPGS1
        inc PTR+1
        dex
        bne CLRPGS1
        rts

; =====================================================================
;  VBI -- deferred vertical blank routine: the sound effects
;
;  The OS calls this 60 times a second, after its own VBLANK work, no
;  matter what the main program is doing.  Each sound is just a timer
;  that the game sets to 15.  While a timer is running we count it down
;  and use it as the volume, so every sound fades away by itself.
;
;  AUDC = distortion in the top 3 bits + volume in the bottom 4.
; =====================================================================
VBI
        lda SND1                ; the spray: white noise
        beq VBI2
        dec SND1
        lda SND1
        ora #$80
        sta AUDC1

VBI2    lda SND2                ; a dead medfly: a pure tone sliding down
        beq VBI3
        dec SND2
        lda SND2
        ora #$A0
        sta AUDC2
        lda SND2                ; timer 14 ... 0
        eor #$0F                ; becomes  1 ... 15
        asl
        asl
        adc #30                 ; a bigger number is a lower note
        sta AUDF2

VBI3    lda SND3                ; a car being eaten: a low buzz
        beq VBIX
        dec SND3
        lda SND3
        ora #$C0
        sta AUDC3

VBIX    jmp XITVBV              ; a deferred VBI must leave this way

; =====================================================================
;  DISPLAY LIST
;
;  ANTIC builds the picture by reading this list, one instruction per
;  row.  Mixing modes is just a matter of using different numbers.
;
;    mode 4   40 characters, 8 scan lines, four colours in a character
;    mode 6   20 characters, 8 scan lines, one colour per character
;    mode 7   20 characters, 16 scan lines, one colour per character
;
;  8 + 7*8 + 16 + 8 + 8 + 9*8 + 3*8 = 192 scan lines, a full screen.
;  The rows marked "sky" hold nothing but spaces; the medflies and the
;  puff are players and missiles and are not in screen memory at all.
; =====================================================================
DLIST
        dta DLBLANK8,DLBLANK8,DLBLANK8  ; 24 blank lines, off the top of the tube
        dta 6+DLLMS,a(SCREEN)           ; status line; screen memory is at SCREEN
        dta 4,4,4,4,4,4,4               ; sky
        dta 7                           ; big message
        dta 4                           ; sky
        dta 6                           ; small message
        dta 4,4,4,4,4,4,4,4,4           ; sky
        dta 4                           ; sprayer
        dta 4,4                         ; cars
        dta DLJVB,a(DLIST)              ; wait for VBLANK, then start again

; =====================================================================
;  TABLES
; =====================================================================
STATTXT  dta d'SCORE 00000  WAVE 00'
TITLETXT dta d'  MEDFLY INVASION   '
OVERTXT  dta d'     GAME OVER      '
STARTTXT dta d'    PRESS START     '

; Each player's stripe of memory.
PLRLO   dta <PLAYER0,<PLAYER1,<PLAYER2,<PLAYER3
PLRHI   dta >PLAYER0,>PLAYER1,>PLAYER2,>PLAYER3

; Each car: its left-hand column on the screen, its first character
; number, and where that character's bytes are in the character set.
CARCOL  dta 1,9,17,25,33
CARCODE dta CARCH,CARCH+12,CARCH+24,CARCH+36,CARCH+48
CARGLO  dta <CARGLYPH,<(CARGLYPH+96),<(CARGLYPH+192),<(CARGLYPH+288),<(CARGLYPH+384)
CARGHI  dta >CARGLYPH,>(CARGLYPH+96),>(CARGLYPH+192),>(CARGLYPH+288),>(CARGLYPH+384)

; The medfly: a player is 8 bits wide, one bit per pixel.  The empty
; bytes top and bottom do the erasing (see DRAWFLY).
FLYSHP
        dta %00000000
        dta %10000001           ; X......X
        dta %11011011           ; XX.XX.XX
        dta %11111111           ; XXXXXXXX
        dta %01111110           ; .XXXXXX.
        dta %00111100           ; ..XXXX..
        dta %01011010           ; .X.XX.X.
        dta %00111100           ; ..XXXX..
        dta %00011000           ; ...XX...
        dta %00000000

; Mode 4 characters are 4 pixels wide and each pixel is 2 bits:
;   00 background   01 colour 0   10 colour 1   11 colour 2
;   (or colour 3, when the character on the screen has bit 7 set)
; In the pictures:  . background   B colour 0   W colour 1   T colour 2/3

; The sprayer: two characters side by side.
SPRAYSHP
                                ; left half
        dta %00000011           ; ...T
        dta %00000011           ; ...T
        dta %00001111           ; ..TT
        dta %00111111           ; .TTT
        dta %11111010           ; TTWW
        dta %11111111           ; TTTT
        dta %11111111           ; TTTT
        dta %00101000           ; .WW.
                                ; right half
        dta %11000000           ; T...
        dta %11000000           ; T...
        dta %11110000           ; TT..
        dta %11111100           ; TTT.
        dta %10101111           ; WWTT
        dta %11111111           ; TTTT
        dta %11111111           ; TTTT
        dta %00101000           ; .WW.

; A car: six characters across and two down, 24 by 16 pixels.  The top
; row's six characters come first, then the bottom row's.
CARSHAPE
                                ; top row, character 1
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000101           ; ..BB
                                ; top row, character 2
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000001           ; ...B
        dta %00000101           ; ..BB
        dta %00010110           ; .BBW
        dta %01010110           ; BBBW
        dta %01010101           ; BBBB
                                ; top row, character 3
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %01010101           ; BBBB
        dta %10101010           ; WWWW
        dta %10101010           ; WWWW
        dta %10101010           ; WWWW
        dta %01010101           ; BBBB
                                ; top row, character 4
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %01010101           ; BBBB
        dta %01101010           ; BWWW
        dta %01101010           ; BWWW
        dta %01101010           ; BWWW
        dta %01010101           ; BBBB
                                ; top row, character 5
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %01000000           ; B...
        dta %10010000           ; WB..
        dta %10100100           ; WWB.
        dta %10100101           ; WWBB
        dta %01010101           ; BBBB
                                ; top row, character 6
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %00000000           ; ....
        dta %01010000           ; BB..
                                ; bottom row, character 1
        dta %00010101           ; .BBB
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %00010111           ; .BBT
        dta %00000011           ; ...T
        dta %00000000           ; ....
        dta %00000000           ; ....
                                ; bottom row, character 2
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %11111111           ; TTTT
        dta %11111111           ; TTTT
        dta %11111111           ; TTTT
        dta %11111111           ; TTTT
        dta %00000000           ; ....
                                ; bottom row, character 3
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %11010101           ; TBBB
        dta %11000000           ; T...
        dta %00000000           ; ....
        dta %00000000           ; ....
                                ; bottom row, character 4
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %01010111           ; BBBT
        dta %00000011           ; ...T
        dta %00000000           ; ....
        dta %00000000           ; ....
                                ; bottom row, character 5
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %11111111           ; TTTT
        dta %11111111           ; TTTT
        dta %11111111           ; TTTT
        dta %11111111           ; TTTT
        dta %00000000           ; ....
                                ; bottom row, character 6
        dta %01010100           ; BBB.
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %01010101           ; BBBB
        dta %11010100           ; TBB.
        dta %11000000           ; T...
        dta %00000000           ; ....
        dta %00000000           ; ....

        run START
