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
;  START begins a game.  OPTION, during a game or on the GAME OVER
;  screen, goes back to the title screen; so does leaving the GAME OVER
;  screen alone for a minute.
;
;  HOW IT IS DRAWN
;    sky        a GTIA mode 9 picture: 16 shades of one blue, in bands
;               from dark at the top to pale at the horizon
;    palms      drawn into the sky picture in its darkest shade, so
;               the only things that ever pass in front of them are
;               players and missiles
;    mountains  three rows of ANTIC mode 4 with a character set of
;               their own
;    ground     the background colour, changed to brown part way down
;    medflies   the four PLAYERS of player-missile graphics
;    the puff   MISSILE 0
;    sprayer    two redefined characters in ANTIC mode 4
;    cars       redefined characters in ANTIC mode 4, twelve per car,
;               and every car has its own twelve so that each one can
;               dissolve separately
;    text       ANTIC mode 6 and 7 lines at the top
;
;  Three display list interrupts change mode, colours and character set
;  on the way down the screen.  See DISPLAY LIST and the DLI routines.
;
;  MEMORY
;    $2000  program
;    $3000  screen memory for the text and character rows
;    $3400  character set for the mountains
;    $3800  player-missile graphics (1K, double line resolution)
;    $3C00  character set for everything else (1K)
;    $4740  the sky picture, 112 lines of 40 bytes
;    $6000  the title screen: display list, text, picture (titlepic.asm)
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
MSGA    = SCREEN+20             ; big message line
MSGB    = SCREEN+40             ; small message line
HILLROW = SCREEN+60             ; three rows of mountains
SPRAYROW = HILLROW+120          ; the row the sprayer drives along
CARROW  = SPRAYROW+40           ; two rows of cars

; The sky picture.  ANTIC cannot read a picture straight across a 4K
; boundary in memory, so the picture is placed for line 56 to begin
; exactly at $5000, and the display list points ANTIC there afresh.
SKY     = $5000-56*40
SKY2    = $5000
SKYLINES = 112

HILLSET = $3400                 ; the mountains' own character set
TRUNKCH = 9                     ; add to a mountain character for one with a trunk

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

; Colours.  A colour byte is hue * 16 + brightness.
SKYHUE  = $90                   ; blue; mode 9 supplies the brightness
HORIZON = $9E                   ; the palest sky, behind the mountains
HILLCOL = $B4                   ; mountain green
GROUND  = $22                   ; dark brown
CARRED  = $46
TYREGRY = $06
SPRAYCOL = $DA                  ; yellow-green: the sprayer, and a rising puff
FALLCOL = $38                   ; orange: a puff on its way back down

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

; The title picture: 52 rows, and the top one is at this index into
; player-missile memory (it starts 40 scan lines down the display).
TPICROWS = 52
TPICY   = 36
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
FLAPTMR = $94                   ; frame counter for the wings
FLAPOFF = $95                   ; which wing picture this frame
SHAPEOFF = $96                  ; which picture DRAWFLY is to draw
TEMP2   = $97
TRIGUP  = $98                   ; non-zero once the trigger has been let go
OVERTMR = $99                   ; 2 bytes: frames left on the end screen
STARTCOL = $9B                  ; PRESS START's colour this frame
DLI1ST  = $9C                   ; 2 bytes: first display list interrupt of the frame

FLYON   = $A0                   ; 4 bytes each: 0 free, 1 alive, 2 dying
FLYX    = $A4                   ; horizontal position
FLYY    = $A8                   ; vertical position
FLYDX   = $AC                   ; +1 or -1 ($FF)
FLYDY   = $B0                   ; +1 or -1 ($FF)
FLYSPD  = $B4                   ; speed, in 256ths of a step per frame
FLYFRC  = $B8                   ; fraction of a step saved up so far
FLYTMR  = $BC                   ; frames left of its death

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
        ldx #5                  ; as far as the mountains' character set
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

; --- scenery ---------------------------------------------------------------
        jsr MAKESKY
        jsr MAKEHILL

; --- character set and player-missile graphics ----------------------------
        lda #>CHARSET
        sta CHBAS
        lda #>PMG
        sta PMBASE              ; ANTIC fetches P/M data from here
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

; --- interrupts ------------------------------------------------------------
; The vertical blank routine first.  SETVBV changes the vector safely
; even if a VBLANK arrives half way through.  A = 7 means the deferred
; vector, VVBLKD.
;
; Then the display list interrupts.  DLI1ST holds the address of the
; first one on whichever screen is showing; the vertical blank routine
; copies it into the vector at the start of every frame.  $C0 in NMIEN
; allows vertical blank interrupts ($40) and display list ones ($80).
        lda #<DLIT1
        sta DLI1ST
        sta VDSLST
        lda #>DLIT1
        sta DLI1ST+1
        sta VDSLST+1
        ldy #<VBI
        ldx #>VBI
        lda #7
        jsr SETVBV
        lda #$C0
        sta NMIEN

        jsr SHOWSTAT

; =====================================================================
;  TITLE SCREEN
;
;  MEDFLY INVASION at the top in cycling colours, the picture of the
;  medfly, and PRESS START at the bottom blinking red and white.
;
;  Both lines of text are drawn in colour register 0, and so are the
;  grey parts of the picture between them.  That works because display
;  list interrupts give the register a different value for each: the OS
;  shadow holds the title's colour, DLIT1 changes it to grey under the
;  title, and DLIT3 changes it to STARTCOL above PRESS START.  All this
;  loop has to do is keep choosing the two colours.
; =====================================================================
TITLE   jsr SETTITLE
TITLELP jsr WAITVB
        lda #0
        sta ATRACT

        lda RTCLOK+2            ; the frame counter, times 4, gives a hue
        asl                     ; in the top four bits that moves on
        asl                     ; one step every four frames
        and #$F0
        ora #$0A                ; with a fixed brightness
        sta COLOR0

        lda RTCLOK+2            ; bit 5 of the counter changes every 32
        and #$20                ; frames: about half a second red, half
        beq TITLEWH             ; a second white
        lda #$46
        bne TITLEST
TITLEWH lda #$0E
TITLEST sta STARTCOL

; START is bit 0 of CONSOL, and reads 0 while the key is down.
        lda CONSOL
        and #CONSTART
        bne TITLELP

; =====================================================================
;  NEW GAME
; =====================================================================
NEWGAME
        jsr SETGAME             ; game display list, colours, P/M set-up
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
        sta TRIGUP
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
        lda CONSOL              ; OPTION abandons the game
        and #CONOPTION
        bne PLAYON
        jmp TITLE               ; too far away for a branch
PLAYON  jsr CHECKHIT
        jsr MOVESPR
        jsr MOVEPUFF
        lda OVER
        bne GAMEOVER
        jsr SPAWN
        jsr MOVEFLY
        jsr CHKWAVE
        jmp PLAY

; ---------------------------------------------------------------------
;  The end screen.  START plays again, OPTION goes to the title screen,
;  and so does doing nothing for a minute: 3600 frames, counted down in
;  two bytes.
; ---------------------------------------------------------------------
GAMEOVER
        lda #<OVERTXT
        ldx #>OVERTXT
        jsr SHOWA
        lda #<STARTTXT
        ldx #>STARTTXT
        jsr SHOWB
        lda #<3600
        sta OVERTMR
        lda #>3600
        sta OVERTMR+1

OVERLP  jsr WAITVB
        lda #0
        sta ATRACT
        lda CONSOL
        and #CONSTART
        bne OVER1
        jmp NEWGAME
OVER1   lda CONSOL
        and #CONOPTION
        beq OVERTTL
        lda OVERTMR             ; take one from the 16-bit timer
        bne OVER2
        dec OVERTMR+1
OVER2   dec OVERTMR
        lda OVERTMR
        ora OVERTMR+1
        bne OVERLP
OVERTTL jmp TITLE

; =====================================================================
;  SETGAME and SETTITLE -- change from one screen to the other
;
;  The two screens have different display lists, colours, interrupts
;  and uses for the players and missiles.  Everything is changed just
;  after a vertical blank, so that the next frame is drawn entirely the
;  new way.  The display list and colours go in the OS shadows; the
;  player sizes and positions have no shadows and go straight to GTIA.
; =====================================================================
SETGAME
        jsr WAITVB
        lda #<DLIST
        sta SDLSTL
        lda #>DLIST
        sta SDLSTH
        lda #<DLISKY
        sta DLI1ST
        lda #>DLISKY
        sta DLI1ST+1

        lda #CARRED
        sta COLOR0              ; car bodies
        lda #$0C                ; white
        sta COLOR1              ; car windows, sprayer cab, all the text
        lda #TYREGRY
        sta COLOR2              ; tyres
        lda #SPRAYCOL
        sta COLOR3              ; the puff (see below), and the sprayer
        lda #SKYHUE             ; dark blue
        sta COLOR4              ; background, and the hue of the sky
        lda #$28                ; orange
        sta PCOLR0              ; medflies
        sta PCOLR1
        sta PCOLR2
        sta PCOLR3

; A missile normally takes the colour of its own player, which would
; make the puff the colour of medfly 0.  Bit 4 of the priority register
; turns on the "fifth player": all four missiles take playfield colour
; 3 instead.  Bit 0 puts players in front of the playfield.
        lda #$11
        sta GPRIOR
        lda #$01
        sta SIZEM               ; missile 0 double width: 4 colour clocks
        lda #0
        sta SIZEP0              ; players normal width
        sta SIZEP1
        sta SIZEP2
        sta SIZEP3

; $2E = normal width playfield ($22) + missile DMA ($04) + player DMA
; ($08), with bit 4 clear for double line resolution.
        lda #$2E
        sta SDMCTL
        rts

SETTITLE
        jsr WAITVB
        lda #<TDLIST
        sta SDLSTL
        lda #>TDLIST
        sta SDLSTH
        lda #<DLIT1
        sta DLI1ST
        lda #>DLIT1
        sta DLI1ST+1

        lda #<PMG               ; take the medflies and puff away
        sta PTR
        lda #>PMG
        sta PTR+1
        ldx #4
        jsr CLRPGS

; The players and missiles become parts of the picture.  Each table is
; one byte per row of the picture, and the picture's top row is at
; TPICY in player-missile memory.
        ldx #TPICROWS-1
STPM    lda TP0,x
        sta PLAYER0+TPICY,x
        lda TP1,x
        sta PLAYER1+TPICY,x
        lda TP2,x
        sta PLAYER2+TPICY,x
        lda TP3,x
        sta PLAYER3+TPICY,x
        lda TMIS,x
        sta MISSILES+TPICY,x
        dex
        bpl STPM

        lda #TP0X
        sta HPOSP0
        lda #TP1X
        sta HPOSP1
        lda #TP2X
        sta HPOSP2
        lda #TP3X
        sta HPOSP3
        ldx #3
STMISX  lda TMISX,x
        sta HPOSM0,x
        dex
        bpl STMISX

        lda #3                  ; a player's 8 bits can be 8, 16 or 32
        sta SIZEP0              ; colour clocks wide.  Thorax and wings
        sta SIZEP2              ; are 32 (size 3) ...
        sta SIZEP3
        lda #1
        sta SIZEP1              ; ... and the face is 16 (size 1)
        lda #0
        sta SIZEM               ; missiles their normal 2

; Priority $14: bit 2 puts the whole playfield in front of the players,
; and bit 4 is the fifth player again, so the feet get colour 3.
        lda #$14
        sta GPRIOR

        lda #$0C
        sta COLOR1              ; light grey: veins, bristles, highlights
        lda #$44
        sta COLOR2              ; red: eyes  (DLIT2 makes it orange lower down)
        lda #$0E
        sta COLOR3              ; white: feet
        lda #$00
        sta COLOR4              ; black background
        lda #$A4
        sta PCOLR0              ; blue-green: thorax
        lda #$1A
        sta PCOLR1              ; pale gold: face
        lda #$96
        sta PCOLR2              ; blue: wings
        sta PCOLR3

        lda #$2E
        sta SDMCTL
        rts

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
        lda FLYON,x             ; only a live one: a medfly that is still
        cmp #1                  ; dissolving is drawn by the same player
        bne HITNEXT             ; and would otherwise be killed twice
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
;  KILLFLY -- medfly X has been sprayed.  Keeps X.
; ---------------------------------------------------------------------
KILLFLY
        stx FLY
        lda #2
        sta FLYON,x             ; dying: MOVEFLY plays out the animation
        lda #32
        sta FLYTMR,x
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

; One press, one puff.  Holding the trigger down does not fire again:
; TRIGUP is set when we see the trigger let go, and a shot uses it up.
; And there is never a second puff until the first is completely over,
; whether it hit a medfly or went all the way back down.
TRIGGER lda STRIG0              ; 0 = pressed
        beq TRIGDN
        lda #1
        sta TRIGUP
        rts
TRIGDN  lda TRIGUP
        beq MOVEDONE            ; still held from last time
        lda PUFFST
        bne MOVEDONE            ; only one puff in the air at a time

        lda #0
        sta TRIGUP
        lda #SPRAYCOL
        sta COLOR3
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
;  MOVEPUFF -- up to the middle of the screen, then slowly down onto a car
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
        lda #2                  ; got to the middle and hit nothing:
        sta PUFFST              ; it turns round and changes colour
        lda #FALLCOL
        sta COLOR3
PUFFSHOW
        jmp DRAWPUF

FALLING inc PUFFY               ; falling: 1 step a frame, half the speed
        lda PUFFY               ; it went up at
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
        lda FLAPOFF
        sta SHAPEOFF
        jmp DRAWFLY

; =====================================================================
;  MOVEFLY -- move and animate every medfly
;
;  Speeds are less than one step a frame, so each medfly saves up
;  fractions.  Add its speed to its fraction byte every frame; when the
;  byte overflows, the carry says it has saved up a whole step.
;
;  Every medfly is redrawn every frame whether it moved or not, because
;  its wings may have.  There are three wing pictures, shown in the
;  order spread, half, back, half, each for four frames.
; =====================================================================
MOVEFLY
        inc FLAPTMR
        lda FLAPTMR
        lsr
        lsr
        and #$03
        tax
        lda FLAPSEQ,x
        sta FLAPOFF

        ldx #MAXFLY-1
FLYLOOP stx FLY
        lda FLYON,x
        beq FLYNEXT
        cmp #1
        bne FLYDYING

        clc                     ; alive
        lda FLYFRC,x
        adc FLYSPD,x
        sta FLYFRC,x
        bcc FLYSHOW
        jsr STEPFLY
FLYSHOW lda FLAPOFF
        sta SHAPEOFF
        jsr DRAWFLY
        jmp FLYNEXT

; A sprayed medfly stays where it is and dissolves through four
; pictures, eight frames each.  Its timer counts 31 down to 0, so the
; timer divided by 8 says which picture: 3, 2, 1, 0.  Until it has
; finished it still occupies its player, and still counts as on screen.
FLYDYING
        dec FLYTMR,x
        beq FLYGONE
        lda FLYTMR,x
        lsr
        lsr
        lsr
        tay
        lda DIEOFF,y
        sta SHAPEOFF
        jsr DRAWFLY
        jmp FLYNEXT

FLYGONE lda #0
        sta FLYON,x
        lda PLRLO,x             ; wipe that player's whole stripe
        sta PTR
        lda PLRHI,x
        sta PTR+1
        ldy #127
        lda #0
FLYWIPE sta (PTR),y
        dey
        bpl FLYWIPE
        dec ALIVE

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
        rts
STEPRGT cmp #XMAX
        bcc STEPDONE
        lda #$FF                ; bounced off the right edge
        sta FLYDX,x
STEPDONE
        rts

; ---------------------------------------------------------------------
;  DRAWFLY -- put medfly X (also in FLY) on the screen, using the
;  picture that starts SHAPEOFF bytes into the FLYSHP table
;
;  Every picture has an empty byte above and below the medfly.  A
;  medfly only ever moves one step at a time, so drawing the picture
;  one byte higher or lower than before automatically rubs out the line
;  it left behind.  No separate erase is needed.
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
        ldx SHAPEOFF
        lda #10
        sta COUNT
DRAWLP  lda FLYSHP,x
        sta (PTR),y
        iny
        inx
        dec COUNT
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
;  MAKESKY -- paint the sky and the palm trees
;
;  The sky is an ANTIC mode F picture shown through GTIA mode 9.  In
;  that mode a byte is two pixels, four bits each, and the four bits
;  are a brightness from 0 to 15 of the one hue held in the background
;  colour register.  16 bands of 7 lines make the 112 lines, and band N
;  is filled with brightness N: $00, $11, $22 ... $FF.
; =====================================================================
MAKESKY
        lda #<SKY
        sta PTR
        lda #>SKY
        sta PTR+1
        lda #0
        sta TEMP                ; this band's byte
SKYBAND ldx #7
SKYLINE ldy #39
        lda TEMP
SKYFILL sta (PTR),y
        dey
        bpl SKYFILL
        jsr NEXTLINE
        dex
        bne SKYLINE
        lda TEMP
        clc
        adc #$11
        sta TEMP
        bcc SKYBAND             ; $FF + $11 carries: all 16 done

; Palms.  A palm is cut out of the sky with AND masks: wherever the
; mask has a 0 nybble the pixel becomes brightness 0, the darkest blue.
; The crown is 5 rows of the PALMSHP table, each used for 3 lines
; because a mode 9 pixel is four times as wide as it is high.  The
; trunk is one pixel wide and runs on down to the last line of the sky.
        ldx #NPALMS-1
PALM    stx TEMP2
        lda PALMX,x             ; PTR = SKY + 40 * top line + byte across
        clc
        adc #<SKY
        sta PTR
        lda #>SKY
        adc #0
        sta PTR+1
        ldy PALMTOP,x
PALMDN  jsr NEXTLINE
        dey
        bne PALMDN

        lda #0
        sta TEMP                ; index of this row of the crown
PALMROW lda #3
        sta COUNT
PALMLN  ldy #0
        ldx TEMP
PALMAND lda (PTR),y
        and PALMSHP,x
        sta (PTR),y
        inx
        iny
        cpy #5
        bne PALMAND
        jsr NEXTLINE
        dec COUNT
        bne PALMLN
        lda TEMP
        clc
        adc #5
        sta TEMP
        cmp #25
        bne PALMROW

        ldx TEMP2               ; trunk: from under the crown to the
        lda #SKYLINES-15        ; bottom of the sky
        sec
        sbc PALMTOP,x
        tax
        ldy #2                  ; the trunk is the left pixel of byte 2
PALMTRK lda (PTR),y
        and #$0F
        sta (PTR),y
        jsr NEXTLINE
        dex
        bne PALMTRK

        ldx TEMP2
        dex
        bpl PALM
        rts

; Move PTR down one line of the sky picture.  Keeps X and Y.
NEXTLINE
        lda PTR
        clc
        adc #40
        sta PTR
        bcc NEXTLN1
        inc PTR+1
NEXTLN1 rts

; =====================================================================
;  MAKEHILL -- the mountains
;
;  The mountains are three rows of mode 4 characters with a character
;  set of their own, switched in by a display list interrupt.  The set
;  only needs ten characters:
;      0       empty (sky)
;      1 - 8   green in the bottom 1 to 8 lines
;      9 - 17  the same nine again with a palm trunk down the left half
;  MTNHGT says how many lines high the mountains are in each of the 40
;  columns, from 0 to 24.  Each column is then three characters: as
;  much of the height as fits in the bottom one, then the middle, then
;  the top.
; =====================================================================
MAKEHILL
; Characters 1 to 8.  X counts through their 64 bytes.  A byte is line
; (X and 7) of character (X / 8) + 1, and that character is green from
; line 8 - number downwards, which comes to: line + X / 8 >= 7.
        ldx #0
HILLCH  txa
        and #$07
        sta TEMP
        txa
        lsr
        lsr
        lsr
        clc
        adc TEMP
        cmp #7
        lda #0
        bcc HILLCH1
        lda #%01010101          ; four pixels of colour 0
HILLCH1 sta HILLSET+8,x
        inx
        cpx #64
        bne HILLCH

; Characters 9 to 17: copy 0 to 8 and set the two left-hand pixels to
; colour 2.  A mode 9 pixel in the sky is half a character wide, so
; half a character is what joins up with the trunk coming down.
        ldx #71
HILLTRK lda HILLSET,x
        ora #%11110000
        sta HILLSET+TRUNKCH*8,x
        dex
        bpl HILLTRK

        ldy #39                 ; the three rows
HILLCOLM
        lda MTNHGT,y
        sec
        jsr CLAMP8
        sta HILLROW+80,y
        lda MTNHGT,y
        sec
        sbc #8
        jsr CLAMP8
        sta HILLROW+40,y
        lda MTNHGT,y
        sec
        sbc #16
        jsr CLAMP8
        sta HILLROW,y
        dey
        bpl HILLCOLM

        ldx #NPALMS-1           ; the palm trunks carry on down in front:
HILLPLM ldy PALMCOL,x           ; swap the three characters in each
        lda HILLROW,y           ; trunk's column for the ones with trunks
        clc
        adc #TRUNKCH
        sta HILLROW,y
        lda HILLROW+40,y
        clc
        adc #TRUNKCH
        sta HILLROW+40,y
        lda HILLROW+80,y
        clc
        adc #TRUNKCH
        sta HILLROW+80,y
        dex
        bpl HILLPLM
        rts

; What is left of the height after a subtraction, held between 0 and 8.
; Carry clear means the subtraction went below zero.
CLAMP8  bcc CLAMP0
        cmp #9
        bcc CLAMPX
        lda #8
CLAMPX  rts
CLAMP0  lda #0
        rts

; =====================================================================
;  DISPLAY LIST INTERRUPTS
;
;  A display list instruction with bit 7 set makes ANTIC interrupt the
;  6502 at the start of that row's last scan line.  The routine stores
;  into WSYNC, which holds the 6502 until the line has been drawn, and
;  then changes the hardware registers while the beam is off the edge
;  of the picture.  The new values apply from the next line down.
;
;  These go to the hardware registers, not the OS shadows.  At the next
;  vertical blank the OS copies the shadows back, so the top of the
;  screen always starts with the ordinary colours.
;
;  There are three, and there is only one vector, so each one finishes
;  by pointing the vector at the next.
; =====================================================================

; --- under the text lines: into GTIA mode 9 for the sky ------------------
; Bit 6 of PRIOR is mode 9.  The $11 is what GPRIOR already holds.
DLISKY  pha
        lda #$51
        sta WSYNC
        sta PRIOR
        lda #<DLIHILL
        sta VDSLST
        lda #>DLIHILL
        sta VDSLST+1
        pla
        rti

; --- bottom of the sky: back to ordinary colour for the mountains ---------
; Mode 9 takes no notice of the playfield colour registers, so the
; mountain and trunk colours can go in early, while the last line of
; sky is still being drawn.  That matters: the first scan line of a row
; of characters is when ANTIC fetches the row from memory, and it stops
; the 6502 to do it, so anything stored after WSYNC arrives late.  The
; three that must change exactly at the edge go in A, X and Y, to be
; stored the instant WSYNC lets go.
;
; A sky line is one scan line, and ANTIC takes most of it to fetch the
; picture.  By the time the OS has handed the interrupt on to us and we
; have got this far, the line that asked for it is over and the next
; one has begun.  So the interrupt is asked for on line 110, and the
; WSYNC below ends up waiting for the end of line 111.
DLIHILL pha
        txa
        pha
        tya
        pha
        lda #HILLCOL
        sta COLPF0              ; mountains
        lda #SKYHUE
        sta COLPF2              ; trunks, the same dark blue as up in the sky
        lda #$11                ; GTIA mode off
        ldx #HORIZON            ; pale sky behind the mountains
        ldy #>HILLSET           ; the mountains' character set
        sta WSYNC               ; end of line 111, the last of the sky
        sta PRIOR
        stx COLBK
        sty CHBASE
        lda #<DLIGND
        sta VDSLST
        lda #>DLIGND
        sta VDSLST+1
        pla
        tay
        pla
        tax
        pla
        rti

; --- bottom of the mountains: the ground ----------------------------------
; The background stays brown from here to the bottom of the tube,
; overscan included, because nothing changes it until vertical blank.
;
; Colour 3 is the puff's colour, and may be a falling puff's orange.
; The sprayer uses colour 3 too and is always green, so it is put back
; here.  The car colours are stored last because they are not needed
; until the row after the sprayer's.
;
; There is no room to do anything more before the WSYNC: the scan line
; this interrupt arrives on is nearly used up by the time we get here.
DLIGND  pha
        txa
        pha
        tya
        pha
        lda #GROUND
        ldx #>CHARSET           ; sprayer and car characters again
        ldy #SPRAYCOL
        sta WSYNC
        sta COLBK
        stx CHBASE
        sty COLPF3
        lda #CARRED
        sta COLPF0
        lda #TYREGRY
        sta COLPF2
        lda #<DLISKY
        sta VDSLST
        lda #>DLISKY
        sta VDSLST+1
        pla
        tay
        pla
        tax
        pla
        rti

; =====================================================================
;  DISPLAY LIST INTERRUPTS FOR THE TITLE SCREEN
;  Three again, each handing on to the next.
; =====================================================================

; --- under MEDFLY INVASION: colour 0 becomes the picture's grey ------------
DLIT1   pha
        lda #$06
        sta WSYNC
        sta COLPF0
        lda #<DLIT2
        sta VDSLST
        lda #>DLIT2
        sta VDSLST+1
        pla
        rti

; --- under the eyes: colour 2 goes from red to orange for the mouth ---------
; This is how the picture gets more colours than there are registers:
; the same register is a different colour on different scan lines.
DLIT2   pha
        lda #$26
        sta WSYNC
        sta COLPF2
        lda #<DLIT3
        sta VDSLST
        lda #>DLIT3
        sta VDSLST+1
        pla
        rti

; --- above PRESS START: colour 0 becomes this moment's red or white ---------
DLIT3   pha
        lda STARTCOL
        sta WSYNC
        sta COLPF0
        lda #<DLIT1
        sta VDSLST
        lda #>DLIT1
        sta VDSLST+1
        pla
        rti

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
        lda DLI1ST              ; make sure the first interrupt of the
        sta VDSLST              ; new frame is the first one of whichever
        lda DLI1ST+1            ; screen is showing
        sta VDSLST+1

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
;    mode F   320 dots, 1 scan line -- which GTIA mode 9 turns into 80
;             pixels of 16 brightnesses
;
;  8 + 16 + 8 + 112 + 3*8 + 8 + 2*8 = 192 scan lines, a full screen.
;
;  Adding $40 (DLLMS) to an instruction makes ANTIC take the two bytes
;  after it as the address of the screen memory to use from there on.
;  Adding $80 (DLDLI) asks for a display list interrupt on that row.
;
;  ":55 dta ..." is the assembler's way of writing a line 55 times.
; =====================================================================
; (The list itself is further down, next to the title screen's, at $6000.)

; =====================================================================
;  TABLES
; =====================================================================
STATTXT  dta d'SCORE 00000  WAVE 00'
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

; The medfly, seen from above: head at the top, wings either side.  A
; player is 8 bits wide, one bit per pixel.  Seven
; pictures of 10 bytes: three for the wings, four for dying.  The empty
; bytes top and bottom of each do the erasing (see DRAWFLY).
FLYSHP
                                ; wings spread
        dta %00000000
        dta %00111100           ; ..XXXX..
        dta %00011000           ; ...XX...
        dta %11011011           ; XX.XX.XX
        dta %11111111           ; XXXXXXXX
        dta %11011011           ; XX.XX.XX
        dta %10011001           ; X..XX..X
        dta %00011000           ; ...XX...
        dta %00011000           ; ...XX...
        dta %00000000
                                ; wings half
        dta %00000000
        dta %00111100           ; ..XXXX..
        dta %00011000           ; ...XX...
        dta %01011010           ; .X.XX.X.
        dta %11111111           ; XXXXXXXX
        dta %11011011           ; XX.XX.XX
        dta %11011011           ; XX.XX.XX
        dta %10011001           ; X..XX..X
        dta %00011000           ; ...XX...
        dta %00000000
                                ; wings back
        dta %00000000
        dta %00111100           ; ..XXXX..
        dta %00011000           ; ...XX...
        dta %00011000           ; ...XX...
        dta %01111110           ; .XXXXXX.
        dta %01011010           ; .X.XX.X.
        dta %01011010           ; .X.XX.X.
        dta %01011010           ; .X.XX.X.
        dta %00011000           ; ...XX...
        dta %00000000
                                ; dissolving 1
        dta %00000000
        dta %00101100           ; ..X.XX..
        dta %00010000           ; ...X....
        dta %01011010           ; .X.XX.X.
        dta %10110111           ; X.XX.XXX
        dta %11001010           ; XX..X.X.
        dta %01011011           ; .X.XX.XX
        dta %10010001           ; X..X...X
        dta %00001000           ; ....X...
        dta %00000000
                                ; dissolving 2
        dta %00000000
        dta %00100100           ; ..X..X..
        dta %00000000           ; ........
        dta %01001000           ; .X..X...
        dta %10010010           ; X..X..X.
        dta %01000010           ; .X....X.
        dta %00010010           ; ...X..X.
        dta %10000000           ; X.......
        dta %00001000           ; ....X...
        dta %00000000
                                ; dissolving 3
        dta %00000000
        dta %00100000           ; ..X.....
        dta %00000000           ; ........
        dta %00001000           ; ....X...
        dta %10000010           ; X.....X.
        dta %00000000           ; ........
        dta %00010000           ; ...X....
        dta %00000000           ; ........
        dta %00001000           ; ....X...
        dta %00000000
                                ; dissolving 4
        dta %00000000
        dta %00000000           ; ........
        dta %00000000           ; ........
        dta %00001000           ; ....X...
        dta %00000000           ; ........
        dta %00000000           ; ........
        dta %00010000           ; ...X....
        dta %00000000           ; ........
        dta %00000000           ; ........
        dta %00000000

; How far into FLYSHP each picture starts.
FLAPSEQ dta 0,10,20,10          ; spread, half, back, half
DIEOFF  dta 60,50,40,30         ; by timer / 8, so the last comes first

; The mountains: height in scan lines, 0 to 24, for each of 40 columns.
MTNHGT
        dta 19,22,21,18,14,11,10,11,12,11
        dta 8,4,2,2,4,8,13,14,14,13
        dta 13,14,18,20,21,18,13,8,5,5
        dta 7,8,8,6,3,3,5,10,15,18

; The palms: how many bytes across the sky picture the crown starts,
; how many lines down its top is, and the screen column its trunk comes
; down in.  A byte of the sky is as wide as a character, and the trunk
; is in the crown's third byte, so that is bytes across + 2.
NPALMS  = 3
PALMX   dta 2,17,31
PALMTOP dta 50,28,62
PALMCOL dta 4,19,33

; A palm crown, 10 pixels wide, as AND masks.  A mode 9 pixel is one
; hex digit: F leaves the sky alone, 0 cuts the palm out of it.
PALMSHP
        dta $FF,$00,$FF,$00,$FF ; ..XX..XX..
        dta $F0,$00,$00,$00,$0F ; .XXXXXXXX.
        dta $00,$F0,$00,$0F,$00 ; XX.XXXX.XX
        dta $0F,$F0,$00,$0F,$F0 ; X..XXXX..X
        dta $0F,$FF,$00,$FF,$F0 ; X...XX...X

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

; =====================================================================
;  THE TITLE SCREEN'S DISPLAY LIST, TEXT AND PICTURE
;
;  These live in a block of their own higher up in memory, out of the
;  way of the screen memory at $3000 and the sky at $4740.  The display
;  list shows the text and picture straight from here; nothing is
;  copied.
;
;    mode 7   20 characters, 16 scan lines: the two lines of text
;    mode D   160 pixels in four colours, 2 scan lines to a row: the
;             picture, 52 rows
;
;  A blank-line instruction can ask for an interrupt too ($70 + $80).
; =====================================================================
        org $6000

TDLIST
        dta DLBLANK8,DLBLANK8,DLBLANK8  ; 24 blank lines, off the top of the tube
        dta DLBLANK8
        dta 7+DLLMS+DLDLI,a(TTEXT1)     ; MEDFLY INVASION   -> DLIT1
        dta DLBLANK8,DLBLANK8
        dta $0D+DLLMS,a(TPIC)           ; picture, row 0
        :32 dta $0D                     ; rows 1-32
        dta $0D+DLDLI                   ; row 33            -> DLIT2
        :18 dta $0D                     ; rows 34-51
        dta DLBLANK8,DLBLANK8
        dta DLBLANK8+DLDLI              ;                   -> DLIT3
        dta 7+DLLMS,a(TTEXT2)           ; PRESS START
        dta DLJVB,a(TDLIST)

; The game screen's display list, described under DISPLAY LIST above.
; A display list must not cross a 1K boundary in memory (ANTIC's
; counter for it is only 10 bits), and here both are safely inside one.
DLIST
        dta DLBLANK8,DLBLANK8,DLBLANK8  ; 24 blank lines, off the top of the tube
        dta 6+DLLMS,a(SCREEN)           ; status line
        dta 7                           ; big message
        dta 6+DLDLI                     ; small message   -> DLISKY
        dta $0F+DLLMS,a(SKY)            ; sky, line 0
        :55 dta $0F                     ; sky, lines 1-55
        dta $0F+DLLMS,a(SKY2)           ; sky, line 56, across the 4K boundary
        :53 dta $0F                     ; sky, lines 57-109
        dta $0F+DLDLI                   ; sky, line 110   -> DLIHILL
        dta $0F                         ; sky, line 111
        dta 4+DLLMS,a(HILLROW)          ; mountains
        dta 4
        dta 4+DLDLI                     ; mountains       -> DLIGND
        dta 4                           ; sprayer
        dta 4,4                         ; cars
        dta DLJVB,a(DLIST)              ; wait for VBLANK, then start again

TTEXT1  dta d'  MEDFLY INVASION   '
TTEXT2  dta d'    PRESS START     '

        icl 'titlepic.asm'

        run START
