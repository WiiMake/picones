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

.segment "HEADER"
; .inesprg 2 ; 2x 16kb PRG code

INES_MAPPER = 4 ; MMC3 mapper (yes, it is 4, not 3)
INES_MIRROR = 1 ; Vertical mirroring (https://www.nesdev.org/wiki/Mirroring#Nametable_Mirroring)
INES_SRAM = 0 ; (Static Random Access Memory; volatile)

; .byte stores data in NES ROM, tricking the assembler into thinking the 16 bit iNES header is part of the code
.byte 'N', 'E', 'S', $1A ; ID
.byte $10 ; 16k PRG chunk count; 32 x 8 chunks
.byte $01 ; 8k CHR chunk count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4) ; setting config flags in 2 bytes
.byte (INES_MAPPER & %11110000) 
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding

.segment "BSS"
nmi_busy: .res 1 ; 1 byte for our busy flag

.segment "RODATA"

.segment "VECTORS"
    .word nmi_handler   ; NMI vector at $FFFA
    .word main          ; Reset vector at $FFFC
    .word irq_handler   ; IRQ vector at $FFFE

; Embed raw binary sample data
; The $C000-$FFFF range is read for DPCM data.
; With a mapper, the number of banks can be expanded (which is a requirement, since the DPCM data is 177.7kB)
.segment "DPCM0"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc0"

.segment "DPCM1"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc1"

.segment "DPCM2"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc2"

.segment "DPCM3"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc3"

.segment "DPCM4"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc4"

.segment "DPCM5"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc5"

.segment "DPCM6"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc6"

.segment "DPCM7"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc7"

.segment "DPCM8"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc8"

.segment "DPCM9"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc9"

.segment "DPCM10"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc10"

.segment "DPCM11"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc11"

.segment "DPCM12"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc12"

.segment "DPCM13"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc13"

.segment "DPCM14"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc14"

.segment "DPCM15"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc15"

.segment "DPCM16"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc16"

.segment "DPCM17"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc17"

.segment "DPCM18"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc18"

.segment "DPCM19"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc19"

.segment "DPCM20"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc20"

.segment "DPCM21"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc21"

.segment "DPCM22"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc22"

.segment "DPCM23"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc23"

.segment "DPCM24"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc24"

.segment "DPCM25"
    .incbin "BadAppleSrc/audio/dpcmchunks/BadAppleSongMapped.dmc25"


.segment "CODE"
; Include the FamiStudio sound engine
; FamiStudio/SoundEngine/famistudio_ca65.s FamiStudio/SoundEngine/famistudio_cc65.h
.include "../externals/FamiStudio/SoundEngine/famistudio_ca65.s"

.segment "RODATA"

; Include the song data
.include "BadAppleSongMapped.s"

.segment "CODE"

nmi_handler:
    ; Check if NMI is already being handled (to prevent a giant call stack)
    ; If it is, drop the frame
    lda nmi_busy
    bne nmi_exit

    inc nmi_busy
    
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

    ; Clear the flag so the next nmi can be handled
    lda #$00
    sta nmi_busy

nmi_exit:
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

    lda #$01                   ; NTSC
    ldx #<music_data_bad_apple ; Pointer to music data (lo)
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

    ; Enable all 5 APU channels (Square 1/2, Triangle, Noise, and DPCM)
    lda #$1F
    sta $4015

    ; ;later, if we have other variables we want to initialize, we will do that here.

    ; Start playing song $00 (first song)
    lda #$00
    jsr famistudio_music_play

    rts

sound_play_frame:
    ; Advance sound engine by one frame
    ; lda sound_disable_flag
    ; bne .done_playing
    jsr famistudio_update

    ; Start song playback with famistudio_music_play (updated in NMI)
    ; a : Song index (assuming starting with 0)
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
    ; The bank number is passed in the Y register.
    ; We must preserve A and X.
    
    ; MMC3 logic
    pha ; Save A
    txa ; Save X (by pushing it to A, then stack)
    pha

    ; Write to the MMC3 selection register to trigger bank select mode to swap $C000-$DFFF ($8000)
    ; Bit 6 -> alterante mode (swap $C000-$DFFF)
    ; bits 2 and 1; register 6, controls $C000-$DFFF bank
    lda #%01000110 ; Get bank number from Y into A
    sta $8000

    ; Write the bank number from Y to the PRG bank register ($8001)
    tya
    sta $8001

    ; MMC1 logic
;     pha ; Save A
;     txa ; Save X (by pushing it to A, then stack)
;     pha

;     ; 1. Reset MMC1 shift register (same for MMC3)
;     ; (This part is fine, it uses A temporarily)
;     lda #%10000000
;     sta $8000

;     ; 2. Get the bank number from Y into A
;     tya

;     ; 3. Write the 5 bits from A to the mapper
;     ldx #5 ; 5 bits to write
; mmc1_write_loop:
;     pha        ; Save bank number (in A)
;     lsr a      ; Shift rightmost bit into Carry
;     lda #0
;     adc #0
;     sta $E000  ; Write the bit to the PRG bank register ($E000-$FFFF)
;     pla        ; Restore bank number (in A)
;     dex
;     bne mmc1_write_loop

;     ; Restore X and A
    pla
    tax ; (pop A from stack, restore to X)
    pla ; (pop A from stack, restore to A)
    
    rts
.endproc

main:
    ; Initialize MMC1 Mapper
    ; Bit 4 (C): 0 = 8KB CHR bank mode
    ; Bit 3 (S): 0 = Fix $C000-$FFFF, Swap $8000-$BFFF
    ; Bit 2 (P): 1 = 16KB PRG bank mode
    ; Bit 1 (M): 1 = Vertical Mirroring
    ; lda #%00000101

    ; Migrated to MMC3; No need to write a reset bit because reset vector is guaranteed to be called on power-up

    ; MMC1 reset logic
    ; lda #%10000000 ; Fix $E000 (where the code is), $C000 swappable
    ; sta $8000

vblank_wait:
    bit $2002   ; Read PPU status
    bpl vblank_wait ; Loop until VBlank bit (bit 7) is set

    ; Optional but good practice: Clear all RAM
    lda #$00
    ldx #$00
    
clear_ram:
    sta $0300,X ; Clear RAM $0300-$07FF
    sta $0400,X
    sta $0500,X
    sta $0600,X
    sta $0700,X
    inx
    bne clear_ram

    ; Turn on the PPU (enable rendering)
    lda #%00011110  ; Enable background (bit 3) and sprites (bit 4)
    sta $2001       ; Write to PPUMASK

    ; Tell the PPU to start triggering NMIs
    lda #%10000000  ; Enable NMI (bit 7)
    sta $2000       ; Write to PPUCTRL

sound_engine_setup:
    ; Set DPCM bank callback
    ldy #$00
    jsr famistudio_dpcm_bank_callback

    ; Initialize sound engine
    jsr sound_init

loop:
    jmp loop ; infinite loop to prevent running into uninitialized memory