;
; BDoing sound effect playback code
;
; This is a reference implementation for playing sounds
; exported from BDoing. It has been resyntaxed to assemble
; on most assemblers with little fixup. Depending on what
; other audio code is running you probably want to review
; BDoing_Init and manage SID filters accordingly.
;
; I encourage a rewrite of the whole thing to
; customize the sound effect code fit better with the rest
; of your code.
;

XDEF BDoing_Init        ; Initialize all channels
XDEF BDoing_Play        ; Play a sound with A = channel, X lo/Y hi sound data
XDEF BDoing_Update      ; Call every frame
XDEF BDoing_ExitLoop    ; Stop a looping sound, X = channel
XDEF BDoing_Playing     ; Z=false if sound in channel X is currently playing

// zero page use is temporary while BDoing_Play and BDoing_Update is running
const zpEvent = $fe ; 2 bytes of zero page
const zpChannel = $fd ; 1 byte of zero page

const SIDBase = $d400
const SIDVol = 24
const SIDFilters = 21
const SIDChannels = 3

const SoundReg_freq = 0
const SoundReg_pulse = 2
const SoundReg_control = 4
const SoundReg_attackDecay = 5
const SoundReg_sustainRelease = 6

const BDoingStatus_off = 0
const BDoingStatus_on = 1
const BDoingStatus_deltaFreq = 2
const BDoingStatus_deltaPulse = 4
const BDoingStatus_loopExit = 8

const SoundCtrl_KeyOn = 1
const SoundCtrl_SyncOn = 2
const SoundCtrl_RingOn = 4
const SoundCtrl_Disable = 8
const SoundCtrl_Triangle = 16
const SoundCtrl_SawTooth = 32
const SoundCtrl_Rectangle = 64
const SoundCtrl_Noise = 128

SECTION BSS, bss

BDoing_Channels:    ds SIDChannels ; 1 status per channel
BDoing_Wait:        ds SIDChannels ; 1 # frames to wait for next event
BDoing_Curr:        ds 2 * SIDChannels ; 1 ptr to events / channel
BDoing_Freq:        ds 2 * SIDChannels
BDoing_DeltaFreq:   ds 2 * SIDChannels
BDoing_Pulse:       ds 2 * SIDChannels
BDoing_DeltaPulse:  ds 2 * SIDChannels

SECTION Code, code

BDoing_x7:
    dc.b 0, 7, 14

BDoing_Init:
    lda #BDoingStatus.off
    ldx #SIDChannels
.reset
    dex
    sta BDoing_Channels,x
    sta SIDBase + SIDFilters,x
    bne .reset
    
    lda #15
    sta SIDBase + SIDVol
    rts

; x = channel, will only set loop end if sound is playing
BDoing_ExitLoop:
    lda BDoing_Channels,x
    beq .stopped
    ora #BDoingStatus.loopExit
    sta BDoing_Channels,x
.stopped
    rts

; x = channel
; Z => not playing
BDoing_Playing:
    lda BDoing_Channels,x
    rts

; a channel, x lo/y hi
BDoing_Play:
    stx zpEvent
    sty zpEvent+1
    tax
    lda #BDoingStatus.on
    sta BDoing_Channels,x
; fallthrough to first event
; read from and increment zpEvent
BDoing_Event:
    stx zpChannel

    ldy #0
.next   lda (zpEvent),y ; time
    bne .not_end ; exit if frames == 0
    ldy BDoing_x7,x
    lda #SoundCtrl.Disable
    sta SIDBase + SoundReg.control,y
    lda #BDoingStatus.off
    sta BDoing_Channels,x
    rts
.not_end
    bpl .time ; not a loop if frames > 0
.loop   pha
    lda BDoing_Channels,x
    and #BDoingStatus.loopExit
    beq .rewind
    pla
    iny ; when loop should exit, get next byte and continue
    bne .next
.rewind 
    clc
    pla
    adc zpEvent
    sta zpEvent
    bcs .next
    dec zpEvent+1
    bne .next
.time
    sta BDoing_Wait,x
    lda BDoing_x7,x
    tax ; SID channel offset
    iny
    lda (zpEvent),y ; register mask
    lsr
    bcc .not_frequency
    pha
    iny
    lda (zpEvent),y
    sta SIDBase + SoundReg.freq,x
    pha
    iny
    lda (zpEvent),y
    sta SIDBase + SoundReg.freq+1,x
    ldx zpChannel
    sta BDoing_Freq,x
    pla
    sta BDoing_Freq+SIDChannels,x
    lda BDoing_Channels,x
    and #$ff ^ BDoingStatus.deltaFreq
    sta BDoing_Channels,x
    lda BDoing_x7,x
    tax
    pla
.not_frequency
    lsr
    bcc .not_pulse
    pha
    iny
    lda (zpEvent),y
    sta SIDBase + SoundReg.pulse,x
    pha
    iny
    lda (zpEvent),y
    sta SIDBase + SoundReg.pulse+1,x
    ldx zpChannel
    sta BDoing_Pulse,x
    pla
    sta BDoing_Pulse+SIDChannels,x
    lda BDoing_Channels,x
    and #$ff ^ BDoingStatus.deltaPulse
    sta BDoing_Channels,x
    lda BDoing_x7,x
    tax
    pla
.not_pulse
    lsr
    bcc .not_attack_decay
    pha
    iny
    lda (zpEvent),y
    sta SIDBase + SoundReg.attackDecay,x
    pla
.not_attack_decay
    lsr
    bcc .not_sustain_release
    pha
    iny
    lda (zpEvent),y
    sta SIDBase + SoundReg.sustainRelease,x
    pla
.not_sustain_release
    lsr
    bcc .not_control
    pha
    iny
    lda (zpEvent),y
    sta SIDBase + SoundReg.control,x
    pla
.not_control
    ldx zpChannel
    lsr
    bcc .not_delta_freq
    pha
    lda BDoing_Channels,x
    ora #BDoingStatus.deltaFreq
    sta BDoing_Channels,x
    iny
    lda (zpEvent),y
    sta BDoing_DeltaFreq+SIDChannels,x
    iny
    lda (zpEvent),y
    sta BDoing_DeltaFreq,x
    pla
.not_delta_freq
    lsr
    bcc .not_delta_pulse
    pha
    lda BDoing_Channels,x
    ora #BDoingStatus.deltaPulse
    sta BDoing_Channels,x
    iny
    lda (zpEvent),y
    sta BDoing_DeltaPulse+SIDChannels,x
    iny
    lda (zpEvent),y
    sta BDoing_DeltaPulse,x
    pla
.not_delta_pulse
    sec
    tya
    adc zpEvent
    sta BDoing_Curr,x
    lda zpEvent+1
    adc #0
    sta BDoing_Curr+SIDChannels,x
    rts

BDoing_Update:
    ldx #2
.channel
    lda BDoing_Channels,x
    beq .silent
    ldy BDoing_x7,x
    pha
    and #BDoingStatus.deltaFreq
    beq .not_delta_freq
    clc
    lda BDoing_Freq+SIDChannels,x
    adc BDoing_DeltaFreq+SIDChannels,x
    sta BDoing_Freq+SIDChannels,x
    sta SIDBase + SoundReg.freq,y
    lda BDoing_Freq,x
    adc BDoing_DeltaFreq,x
    sta BDoing_Freq,x
    sta SIDBase + SoundReg.freq+1,y
.not_delta_freq
    pla
    and #BDoingStatus.deltaPulse
    beq .not_delta_pulse
    clc
    lda BDoing_Pulse+SIDChannels,x
    adc BDoing_DeltaPulse+SIDChannels,x
    sta BDoing_Pulse+SIDChannels,x
    sta SIDBase + SoundReg.pulse,y
    lda BDoing_Pulse,x
    adc BDoing_DeltaPulse,x
    sta BDoing_Pulse,x
    sta SIDBase + SoundReg.pulse+1,y
.not_delta_pulse
    dec BDoing_Wait,x
    bne .wait
    txa
    pha
    lda BDoing_Curr,x
    sta zpEvent
    lda BDoing_Curr+SIDChannels,x
    sta zpEvent+1
    jsr BDoing_Event
.wait
    pla
    tax
.silent
    dex
    bpl .channel
    rts
