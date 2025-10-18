;
; iNES header
;

;
; 6502 ASM NOTES
; # is load immediate value, $ is hex value, % is binary value
; .include "filename.asm" to include another asm file (can clean this file up later with this)
;

; BANK NUMBER: $5FF8 - $5FFF
; Uses the famistudio sound engine (BadAppleEngine.asm) and the sound data (BadAppleSong.asm, BadApple.dmc) to playback music

; TODO: figure out why still getting range errors and assemble (only goal is to get it to assemble)

.segment "HEADER"
; .inesprg 2 ; 2x 16kb PRG code

INES_MAPPER = 1 ; MMC1B mapper
INES_MIRROR = 1 ; Vertical mirroring (https://www.nesdev.org/wiki/Mirroring#Nametable_Mirroring)
INES_SRAM = 0 ; (Static Random Access Memory; volatile)

; .byte stores data in NES ROM, tricking the assembler into thinking the 16 bit iNES header is part of the code
.byte 'N', 'E', 'S', $1A ; ID
.byte $02 ; 16k PRG chunk count; a chunk is 8 or 16kB
.byte $01 ; 8k CHR chunk count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4) ; setting config flags in 2 bytes
.byte (INES_MAPPER & %11110000) 
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding

.segment "RODATA"

.segment "VECTORS"
    .word nmi_handler   ; NMI vector at $FFFA
    .word main          ; Reset vector at $FFFC
    .word irq_handler   ; IRQ vector at $FFFE

; Embed raw binary sample data
; The $C000-$FFFF range is fixed for DPCM data.
; With a mapper, the number of banks can be expanded (which is a requirement, since the DPCM data is 177.7kB)
.segment "DPCM0" 
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcaa"

.segment "DPCM1"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcab"

.segment "DPCM2"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcac"

.segment "DPCM3"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcad"

.segment "DPCM4"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcae"

.segment "DPCM5"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcaf"

.segment "DPCM6"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcag"

.segment "DPCM7"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcah"

.segment "DPCM8"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcai"

.segment "DPCM9"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcaj"

.segment "DPCM10"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcak"

.segment "DPCM11"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcal"

.segment "DPCM12"
    .incbin "BadApple/dpcm16kb/BadAppleSongMapped.dmcam"


.segment "CODE"
; Include the FamiStudio sound engine
; FamiStudio/SoundEngine/famistudio_ca65.s FamiStudio/SoundEngine/famistudio_cc65.h
.include "FamiStudio/SoundEngine/famistudio_ca65.s"

.segment "RODATA"

; Include the song data
.include "BadAppleSongMapped.s"

.segment "CODE"

nmi_handler:
    ; Called at the end of each frame
    pha     ;push a to stack
    txa     ;transfer x to a
    pha     ;push a to stack
    tya     ;transfer y to a
    pha     ;push a to stack

    ; DRAWING CODE (needs to come BEFORE the audio code since the PPU has to draw during VBlank, whereas audio can be done anytime)
    
    ; AUDIO CODE (NMI is used for timing)
    jsr sound_play_frame
    ; lda #$00
    ; sta sleeping 

    pla     ;pop a from stack
    tay     ; transfer a to y
    pla
    tax
    pla
    RTI ; return from interrupt

irq_handler:
    RTI ; return from interrupt

; .rsset $0300 ;sound engine variables will be on the $0300 page of RAM
; sound_disable_flag  .rs 1   ;a flag variable that keeps track of whether the sound engine is disabled or not.
; .bank 0
; .org $8000  ;first PRG bank starts at $8000.

sound_init:
    ; Initialize the audio engine with:
    ; a : Playback platform, zero for PAL, non-zero for NTSC.
    ; x : Pointer to music data (lo)
    ; y : Pointer to music data (hi)

    ldx #$01                   ; NTSC
    lda #<music_data_bad_apple ; Pointer to music data (lo)
    ldy #>music_data_bad_apple ; Pointer to music data (hi)

    jsr famistudio_init

    ; ; Enable and silence channels (#$ is a literal)
    ; lda #$0F
    ; sta $4015   ;enable Square 1, Square 2, Triangle and Noise channels

    ; lda #$30    ;sets 3rd bit
    ; sta $4000   ;set Square 1 volume to 0
    ; sta $4004   ;set Square 2 volume to 0
    ; sta $400C   ;set Noise volume to 0
    ; lda #$80    ;(128 in decimal; sets 8th bit to 1)
    ; sta $4008   ;silence Triangle

    ; lda #$00
    ; sta sound_disable_flag  ;clear disable flag

    ; ;later, if we have other variables we want to initialize, we will do that here.

    rts

sound_load:
    ; Set up sound engine variables and initialize headers

sound_play_frame:
    ; Advance sound engine by one frame
    ; lda sound_disable_flag
    ; bne .done_playing
    jsr famistudio_update

    ; Start song playback with famistudio_music_play (updated in NMI)
    ; a : Song index (assuming starting with 0)
    lda #$00
    jsr famistudio_music_play
    rts

; .done_playing:
;     rts

; sound_disable:
;     lda #$00
;     sta $4015   ;disable all channels ($4015)
;     lda #$01
;     sta sound_disable_flag  ;set disable flag
;     rts

.proc famistudio_dpcm_bank_callback
    ; The MMC1 listens for 5-bit writes to the entire cartridge space ($8000-$FFFF)
    ; Commands written to this space are picked up by the mapper, NOT sent directly to the ROM chips
    
    ; Reset MMC1 shift register by writing a value with bit 7 set
    lda #%10000000
    sta $8000

    ; Write the bank number to the MMC1 (one bit at a time to handle the shift register)
    ldx #5 ; 5 bits to write
    tya    ; Load bank number from y into A
    mmc1_write_loop:
        pha        ; Save current value of A
        lsr a      ; Shift rightmost bit into Carry
        lda #0     ; Clear A
        adc #0     ; A = 0 + Carry
        sta $E000  ; Write the bit (0 or 1)
        pla        ; Restore A
        dex
        bne mmc1_write_loop
    rts
.endproc

main:
    ; Initialize MMC1 Mapper
    lda #%00011000  ; Bit 2 Sets 16kB PRG mode, Bit 3 fixes $8000 bank and makes $C000 swappable 
    sta $8000

    ldy #$00
    jsr famistudio_dpcm_bank_callback

    ; Initialize sound engine
    jsr sound_init

loop:
    jmp loop ; infinite loop to prevent running into uninitialized memory