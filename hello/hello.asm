; =====================================================================
;  HELLO -- proves the toolchain works.
;
;  Changes the screen colours and prints one line of text through the
;  OS, then sits in a loop.  Nothing clever: the OS has already built a
;  GRAPHICS 0 display list and opened the screen editor on IOCB 0.
; =====================================================================

        icl 'atari.inc'

        org $2000

START
; --- colours -----------------------------------------------------------
; We store into the OS shadows, not into GTIA.  The vertical blank
; routine copies the shadows to the hardware 60 times a second, so a
; value put straight into COLPF2 would last one frame at most.
; A colour byte is hue * 16 + luminance.

        lda #$B4                ; hue 11 (green), luminance 4
        sta COLOR2              ; GR.0 text background
        lda #$0E                ; luminance only matters here: brightest
        sta COLOR1              ; GR.0 text
        lda #$34                ; hue 3 (red-orange), luminance 4
        sta COLOR4              ; border

; --- print a line through CIO ------------------------------------------
; IOCB 0 is the screen editor E:, already open.  PUT RECORD sends
; bytes from the buffer until it has sent an EOL ($9B) or run out of
; length, whichever comes first.

        ldx #$00                ; IOCB 0  (X = channel * 16)
        lda #PUTREC
        sta ICCOM,x
        lda #<MESSAGE
        sta ICBAL,x
        lda #>MESSAGE
        sta ICBAH,x
        lda #<MSGLEN
        sta ICBLL,x
        lda #>MSGLEN
        sta ICBLH,x
        jsr CIOV

; --- done --------------------------------------------------------------
FOREVER jmp FOREVER

MESSAGE dta c'HELLO FROM THE ATARI 800',EOL
MSGLEN  = * - MESSAGE

; A binary load file runs from the address left in RUNAD.
        run START
