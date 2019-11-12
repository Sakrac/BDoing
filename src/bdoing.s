; d400: 7 bytes / channel
; 0/1: freq
; 2/3: pulse width
; 4: control bits
;  0: key off / key on (0/1)
;  1: sync enable
;  2: ring mod enable
;  3: disable voice
;  4: triangle enable
;  5: sawtooth enable
;  6: rectangle enable
;  7: noise enable
; 5: AD length
;  0-3: decay (0 = 6 ms, 15 = 24 s)
;  4-7: attack (0 = 2 ms, 15 = 8 s)
; 6: SR vol/length
;  0-3: release (0 = 6 ms, 15 = 24 s)
;  4-7: sustain volume

enum Options {
    Name,
    Duration,
    Frequency,
    Pulse,
    Key,
    Disable,
    Type,
    Attack,
    Decay,
    Sustain,
    Release,
    FreqDelta,
    PulseDelta,
    Loop,
    Count
}

struct SoundInt {
    byte setValue ; 1 bit / value that follows
    byte expLabel ; 1 bit / value export an extra label for this byte
    byte frames ; frames to next sound event (0 terminates)
    byte loop ; only one sound may use loop and must point to prior sound
    word freq
    word pulse
    byte control
    byte attackDecay
    byte sustainRelease
    word deltaFreq
    word deltaPulse
}

eval SoundInt.bytes

const SoundBase = $d400
enum SoundReg {
    freq = 0,
    pulse = 2,
    control = 4,
    attackDecay = 5,
    sustainRelease = 6
}
const FilterControl = 23
const SoundVol = 24

; a sound mask of zero indicates end
enum SoundMask {
    Freq = 1,
    Pulse = 2,
    AtkDcy = 4,
    SusRel = 8,
    Control = 16,
    FreqDelta = 32,
    PulsDelta = 64,
    Loop = 128
}

enum SoundCtrl {
    KeyOn = 1,
    SyncOn = 2,
    RingOn = 4,
    Disable = 8,
    Triangle = 16,
    SawTooth = 32,
    Rectangle = 64,
    Noise = 128
}

const FileSound = $4000 ; array of SoundInts
const WorkStart = $7800 ; current sound

const SoundNameLen = $20
const WorkSound = WorkStart + SoundNameLen
const CurrSoundName = WorkStart

; the file begins with an identifier, then a sound count and then
; an end address
const LoadedSoundCount = FileSound + SoundFileIDLen
const LoadedSoundsEnd = LoadedSoundCount + 1
const FirstLoadedSound = LoadedSoundsEnd + 2

const ExportStart = $2f2f //

const MAX_EVENTS = 64
const MAX_SOUNDS = 32

STRING petsci = "@abcdefghijklmnopqrstuvwxyz[~]^` !@#$%&'()*+,-./0123456789:@<=>??ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                ;0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
pool zpLocal $f0-$100

SECTION BSS, bss
org $c000

CurrSound:
    ds 2
CurrEvent:
    ds 1
EventPtr:
    ds 2
CurrOption: ; current tool menu index
    ds 1
CurrOptionEnter: ; current option has focus
    ds 1
Cursor:
    ds 1
CursorFlash:
    ds 1
;InputScreen:
;    ds 2
InputMaxLength:
    ds 1
KeyboardBits:
	ds 8
KeyboardBitsChange:
	ds 8
KeyboardBitsLen = *-KeyboardBits
;CurrSoundName:
;    ds 20

TotalTime:
    ds 2    ; frames
CurrTime:
    ds 2
Hex2Dec:
    ds 3
Hex2DecResult:
    ds 3
NumAlign:
    ds 1

SoundPlaying:   ; nonzero if currently playing
    ds 3

SoundPlayStopLoop:
    ds 3

SoundLoopEvent:
    ds 3

SoundPlayCursor:
    ds 3
SoundPlayCursorFrame:
    ds 3

SoundPlayWait:  ; number of frames until next event
    ds 3

SoundPlayEvent: ; current event
    ds 3

TestSoundStartLo:
    ds 3

TestSoundStartHi:
    ds 3

SoundPlayFreq:  ; sliding frequency
    ds 6

SoundPlayFrameFreq: ; sliding frequency amount
    ds 6

SoundPlayPulse:  ; sliding frequency
    ds 6

SoundPlayFramePulse: ; sliding frequency amount
    ds 6

CurrentExportSound:
    ds 1

CurrentSoundIndex: ; counter for iterating through sounds
    ds 1

CurrentExportType:  ; 0: _SND, 1: _PAL, 2: _NTSC
    ds 1

ExportEventLabels:
    ds 1

ExportByteInLine:
    ds 1

CurrentExportLabelIndex:
    ds 8

CurrentSoundStart:
    ds 2

CurrentSoundSize:
    ds 2

CurrentWorkSize:
    ds 2

BankEndAddress:
    ds 2

DiskDirNameRead:
    ds 1

NumFiles:
    ds 1

InputUpper:
    ds 1


NumOptions:
    ds 1

FilenameScratch:
    ds 2 ; prefix filename with S: to overwrite file

Filename:
    ds 16

LoadedSoundsLo:
    ds MAX_SOUNDS

LoadedSoundsHi:
    ds MAX_SOUNDS

SoundEventScreen:
    ds MAX_EVENTS

ExportSoundEventsLo:
    ds MAX_EVENTS

ExportSoundEvent:
    ds 1

ExportBytes:
    ds 1

ExportNTSCEvent:
    ds SoundInt.bytes

DirFiles:
    ds 2048

SECTION Tool,code
org $0801

; 1 SYS 2064
dc.b $0b, $08, $01, $00, $9e, $32, $30, $36, $34, $00, $00, $00, $00, $00, $00
; Startup takes care of various one-time setups

    jmp StartFileMenu

TestSound:
{
;SoundPlayCursor:
;    ds 2
;SoundPlayCursorFrame:
;    ds 2
    lda #0
    sta MathNumber+2
    sta SoundPlayCursor
    sta SoundPlayCursor+1
    sta Divisor+2
    lda #128
    sta MathNumber
    lda #39
    sta MathNumber+1
    lda TotalTime
    sta Divisor
    lda TotalTime+1
    sta Divisor+1
    jsr Divide24
    lda MathNumber
    sta SoundPlayCursorFrame
    lda MathNumber+1
    sta SoundPlayCursorFrame+1
    ldx #0
    lda #<WorkSound
    ldy #>WorkSound
    jsr InitTestSound
    jmp SoundEvent
    rts
}

TestSoundBank:
{
    jsr InitTestSound
    jmp SoundEventBank
}

InitTestSound:
{
    sta TestSoundStartLo,x
    tya
    sta TestSoundStartHi,x
    lda #1
    sta SoundPlaying,x
    lda #0
    sta SoundPlayStopLoop,x
    sta SoundPlayEvent,x
    sta SoundBase + FilterControl
    lda #$ff
    sta SoundLoopEvent,x
    lda #$0f
    sta SoundBase + SoundVol
    rts
}

; x = channel
UpdateTestSound:
{
    ldx #0
    {
        lda SoundPlaying,x
        beq %
        ldy SoundPlayCursor+1
        lda #$20
        sta $400+80,y
        clc
        lda SoundPlayCursorFrame
        adc SoundPlayCursor
        sta SoundPlayCursor
        lda SoundPlayCursorFrame+1
        adc SoundPlayCursor+1
        sta SoundPlayCursor+1
        tay
        lda #$1e
        sta $400+80,y
    }
    {
        lda SoundPlaying,x
        beq %
        jsr UpdateTestSoundSlide
        dec SoundPlayWait,x
        bne %
        jsr SoundEvent
    }
    rts
}

UpdateBankSound:
{
    {
        lda SoundPlaying,x
        beq %
        jsr UpdateTestSoundSlide
        dec SoundPlayWait,x
        bne %
        jmp SoundEventBank
    }
    rts
}

UpdateTestSoundSlide:
{        
    clc
    lda SoundPlayFreq,x
    adc SoundPlayFrameFreq,x
    sta SoundPlayFreq,x
    lda SoundPlayFreq+3,x
    adc SoundPlayFrameFreq+3,x
    sta SoundPlayFreq+3,x

    clc
    lda SoundPlayPulse,x
    adc SoundPlayFramePulse,x
    sta SoundPlayPulse,x
    lda SoundPlayPulse+3,x
    adc SoundPlayFramePulse+3,x
    sta SoundPlayPulse+3,x

    lda SoundPlayFreq,x
    ldy ChannelToSID,x
    sta SoundBase + SoundReg.freq,y
    lda SoundPlayFreq+3,x
    sta SoundBase + SoundReg.freq+1,y
    
    lda SoundPlayPulse,x
    sta SoundBase + SoundReg.pulse,y
    lda SoundPlayPulse+3,x
    sta SoundBase + SoundReg.pulse+1,y
    rts
}

ChannelToSID: dc.b 0, 7, 14

; x is channel
; test sounds are always channel 0 so x should be 0
SoundEvent:
{
    zpLocal .zpEvent.w
    ldy SoundPlayCursor+1
    lda #$20
    sta $400+80,y
SoundEventBank:
    ldy SoundPlayEvent,x
    {
        lda SoundPlayStopLoop,x
        bne %
        {
            lda SoundLoopEvent,x
            bmi %
            tay
            sta SoundPlayEvent,x
        }
        lda #$ff
        sta SoundLoopEvent,x
    }
    ; do this for all channels, only one channel is used in sound edit mode and cursor is not used in bank mode
    lda SoundEventScreen,y
    sta SoundPlayCursor+1
    lda #0
    sta SoundPlayCursor

    clc
    lda SoundEventsOffsLo,y
    adc TestSoundStartLo,x
    sta .zpEvent
    lda SoundEventsOffsHi,y
    adc TestSoundStartHi,x
    sta .zpEvent+1

    ldy #SoundInt.setValue
    lda (.zpEvent),y
    pha
    ldy #SoundInt.frames
    lda (.zpEvent),y
    {
        bne %
        sta SoundPlaying,x
        lda #SoundCtrl.Disable
        sta SoundBase + SoundReg.control,x
        pla
        rts
    }
    sta SoundPlayWait,x
    pla
    {
        lsr
        bcc %
        pha
        ldy #SoundInt.freq
        lda (.zpEvent),y
        pha
        sta SoundPlayFreq,x
        lda #0
        sta SoundPlayFrameFreq+0,x
        sta SoundPlayFrameFreq+3,x
        iny
        lda (.zpEvent),y
        sta SoundPlayFreq+3,x
        ldy ChannelToSID,x
        sta SoundBase + SoundReg.freq+1,y
        pla
        sta SoundBase + SoundReg.freq,y
        pla
    }
    {
        lsr
        bcc %
        pha
        lda #0
        sta SoundPlayFramePulse+0,x
        sta SoundPlayFramePulse+3,x

        ldy #SoundInt.pulse
        lda (.zpEvent),y
        pha
        sta SoundPlayPulse,x
        iny
        lda (.zpEvent),y
        sta SoundPlayPulse+3,x

        ldy ChannelToSID,x
        sta SoundBase + SoundReg.pulse+1,y
        pla
        sta SoundBase + SoundReg.pulse,y

        pla
    }
    {
        lsr
        bcc %
        pha
        ldy #SoundInt.attackDecay
        lda (.zpEvent),y
        ldy ChannelToSID,x
        sta SoundBase + SoundReg.attackDecay,y
        pla
    }
    {
        lsr
        bcc %
        pha
        ldy #SoundInt.sustainRelease
        lda (.zpEvent),y
        ldy ChannelToSID,x
        sta SoundBase + SoundReg.sustainRelease,y
        pla
    }
    {
        lsr
        bcc %
        pha
        ldy #SoundInt.control
        lda (.zpEvent),y
        ldy ChannelToSID,x
        sta SoundBase + SoundReg.control,y
        pla
    }
    {
        lsr
        bcc %
        pha
        ldy #SoundInt.deltaFreq
        lda (.zpEvent),y
        sta SoundPlayFrameFreq,x
        iny
        lda (.zpEvent),y
        sta SoundPlayFrameFreq+3,x
        pla
    }
    {
        lsr
        bcc %
        pha
        ldy #SoundInt.deltaPulse
        lda (.zpEvent),y
        sta SoundPlayFramePulse,x
        iny
        lda (.zpEvent),y
        sta SoundPlayFramePulse+3,x
        pla
    }
    {
        lsr
        bcc %
        {
            ldy #SoundInt.loop
            lda (.zpEvent),y
            sta SoundLoopEvent,x
        }
    }
    inc SoundPlayEvent,x
    rts
}


; TIMELINE - ?? Frames total
; X---------X---------X-----X--------X
; ^
; Frame: ??
; * Fq: $xxxx
; * Ps: $xxxx
; * Key: on/off
; * Disable: on/off
; * Type: tri/saw/rect/noise
; * Attack: ?
; * Decay: ?
; * Sustain: ?
; * Release: ?

; data format:
; 1 byte = flags for bytes to set
; 1 byte in order / register

const TimeTotalScreen = $400 + 40 - 3
const EventNumberScreen = $400 + 40*4 + 37
const SoundNameInputScreen = $400 + 3*40 + 6
const DurationInputScreen = $400 + 4*40 + 12
const FreqInputScreen = $400 + 5*40 + 8
const PulseInputScreen = $400 + 6*40 + 9
const KeyValueScreen = $400 + 7*40 + 7
const DisableValueScreen = $400 + 8*40 + 11
const TypeValueScreen = $400 + 9*40 + 8
const AttackValueScreen = $400 + 10*40 + 10
const DecayValueScreen = $400 + 11*40 + 9
const SustainValueScreen = $400 + 12*40 + 11
const ReleaseValueScreen = $400 + 13*40 + 11
const FreqDeltaInputScreen = $400 + 14*40 + 13
const PulseDeltaInputScreen = $400 + 15*40 + 14
const LoopValueScreen = $400 + 16*40 + 7

TitleText:
TEXT [petsci] "BDoing SID FX editor"
dc.b $ff

Timeline:
TEXT [petsci] "-#"

NameText:
TEXT [petsci] "Name: "
dc.b $ff

EventText:
TEXT [petsci] "Event: "
dc.b $ff

DurationText:
TEXT [petsci] "Duration:"
dc.b $ff

FreqText:
TEXT [petsci] "Freq:"
dc.b $ff

FreqDelta:
TEXT [petsci] "FreqSlide:"
dc.b $ff

PulseText:
TEXT [petsci] "Pulse:"
dc.b $ff

PulseDelta:
TEXT [petsci] "PulseSlide:"
dc.b $ff

KeyText:
TEXT [petsci] "Key:"
dc.b $ff

DisableText:
TEXT [petsci] "Disable:"
dc.b $ff

TypeText:
TEXT [petsci] "Type:"
dc.b $ff

AttackText:
TEXT [petsci] "Attack:"
dc.b $ff

DecayText:
TEXT [petsci] "Decay:"
dc.b $ff

SustainText:
TEXT [petsci] "Sustain:"
dc.b $ff

ReleaseText:
TEXT [petsci] "Release:"
dc.b $ff

OnText:
TEXT [petsci] "On "
dc.b $ff

OffText:
TEXT [petsci] "Off"
dc.b $ff

TriangleText:
TEXT [petsci] "Triangle "
dc.b $ff

SawText:
TEXT [petsci] "SawTooth "
dc.b $ff

RectText:
TEXT [petsci] "Rectangle"
dc.b $ff

NoiseText:
TEXT [petsci] "Noise    "
dc.b $ff

LoopText:
TEXT [petsci] "Loop:"
dc.b $ff

InfoText:     ;0123456789012345678901234567890123456789
TEXT [petsci] "Main menu:M     Step:@/*     New Event:N"
dc.b $ff

InfoText2:    ;0123456789012345678901234567890123456789
TEXT [petsci] "Change:Left/Right         Del Event:C=+D"
dc.b $ff

InfoText3:    ;0123456789012345678901234567890123456789
TEXT [petsci] "Toggle:=   Nav:Up/Down   Type Num:Return"
dc.b $ff

InfoText4:    ;0123456789012345678901234567890123456789
TEXT [petsci] "Save:S    Play/End:Space     Export:C=+E"
dc.b $ff

; * Type: tri/saw/rect/noise

macro ToolText( x, y, s, c ) {
    dc.w x+y*40 + $400
    dc.w s
    dc.b c
}

SidFXScreen:
    ToolText 0,  0, TitleText, 1
    ToolText 0,  3, NameText, 10
    ToolText 2,  4, DurationText, 14
    ToolText 2,  5, FreqText, 14
    ToolText 2,  6, PulseText, 14
    ToolText 2,  7, KeyText, 14
    ToolText 2,  8, DisableText, 14
    ToolText 2,  9, TypeText, 14
    ToolText 2, 10, AttackText, 14
    ToolText 2, 11, DecayText, 14
    ToolText 2, 12, SustainText, 14
    ToolText 2, 13, ReleaseText, 14
    ToolText 2, 14, FreqDelta, 14
    ToolText 2, 15, PulseDelta, 14
    ToolText 2, 16, LoopText, 14
    ToolText 30, 4, EventText, 7
    ToolText 0, 21, InfoText, 15
    ToolText 0, 22, InfoText2, 15
    ToolText 0, 23, InfoText3, 15
    ToolText 0, 24, InfoText4, 15

const SidFXLines = * - SidFXScreen

BitShift:
	rept 8 { dc.b 1<<rept }

BitShiftInv:
	rept 8 { dc.b (1<<rept) ^ 255 }

SoundEventsLo:
    rept MAX_EVENTS { dc.b <(WorkSound + rept * SoundInt.bytes) }

SoundEventsHi:
    rept MAX_EVENTS { dc.b >(WorkSound + rept * SoundInt.bytes) }

SoundEventsOffsLo:
    rept MAX_EVENTS { dc.b <( rept * SoundInt.bytes ) }

SoundEventsOffsHi:
    rept MAX_EVENTS { dc.b >( rept * SoundInt.bytes ) }


; AD-R timing values for reference
;Value	Attack	Decay	Release
;0	    2 ms	6 ms	6 ms
;1	    8 ms	24 ms	24 ms
;2	    16 ms	48 ms	48 ms
;3	    24 ms	72 ms	72 ms
;4	    38 ms	114 ms	114 ms
;5	    56 ms	168 ms	168 ms
;6	    68 ms	204 ms	204 ms
;7	    80 ms	240 ms	240 ms
;8	    100 ms	0.3 s	0.3 s
;9	    0.25 s	0.75 s	0.75 s
;10	    0.5 s	1.5 s	1.5 s
;11	    0.8 s	2.4 s	2.4 s
;12	    1 s	    3 s	    3 s
;13	    3 s	    9 s	    9 s
;14	    5 s	    15 s	15 s
;15	    8 s	    24 s	24 s

; when creating a new sound instance, default to this, 3 events worth of data
DefaultSound:
    dc.b SoundMask.Freq | SoundMask.Control | SoundMask.AtkDcy | SoundMask.SusRel
    dc.b 0
    dc.b 25 ; frames, 1/2 second for PAL
    dc.b 255
    dc.w $1D45 ; 440 Hz in PAL
    dc.w $0800 ; Square pulse
    dc.b SoundCtrl.KeyOn | SoundCtrl.SawTooth
    dc.b $48 ; Hi: Attack, Lo: Decay
    dc.b $88 ; Hi: Sustain, Lo: Release
    dc.w 0, 0 ; delta freq, delta pulse

    dc.b SoundMask.Control
    dc.b 0
    dc.b 25 ; frames, 1/2 second for PAL
    dc.b 255
    dc.w $1D45 ; 440 Hz in PAL
    dc.w $0800 ; Square pulse
    dc.b SoundCtrl.SawTooth ; key off sound
    dc.b $48 ; Hi: Attack, Lo: Decay
    dc.b $88 ; Hi: Sustain, Lo: Release
    dc.w 0, 0 ; delta freq, delta pulse

    dc.b 0 ; end, disable sound
    dc.b 0
    dc.b 0 ; end
    dc.b 0
    dc.w 0 ; 440 Hz in PAL
    dc.w 0 ; Square pulse
    dc.b 0 ; key off sound
    dc.b 0 ; Hi: Attack, Lo: Decay
    dc.b 0 ; Hi: Sustain, Lo: Release
    dc.w 0, 0 ; delta freq, delta pulse
DefaultSoundLen = * - DefaultSound

NewSound:
{
    ldx #DefaultSoundLen
    {
        dex
        lda DefaultSound,x
        sta WorkSound,x
        txa
        bne !
    }
    ldx #DefaultSoundNameLen-1
    {
        lda DefaultSoundName,x
        sta WorkStart,x
        dex
        bpl !
    }
    lda #0
    jsr SetCurrEvent
    rts
}

DefaultSoundName:
    TEXT [petsci] "Default"
    dc.b 0
const DefaultSoundNameLen = *-DefaultSoundName


; returns x = number of events
; returns y lo / a hi of end (potentially next sound)
GetEventCount:
{
    ldy #<WorkSound
    lda #>WorkSound
} ; fallthrough
; input: y lo / a hi start of first event
GetEventCountAt:
{
    zpLocal .zpEvent.w
    sty .zpEvent
    sta .zpEvent+1
    ldy #SoundInt.frames
    ldx #0
    {
        lda (.zpEvent),y
        beq %
        inx
        tya
        clc
        adc #SoundInt.bytes
        {
            bcc %
            inc .zpEvent+1
        }
        tay
        jmp !
    }
    clc
    tya
    adc .zpEvent
    tay
    {
        bcc %
        inc .zpEvent+1
    }
    clc
    tya
    adc #SoundInt.bytes - SoundInt.frames
    tay
    lda .zpEvent+1
    adc #0
    rts
}

AddEvent:
{
    jsr GetEventCount
    sty MemCpyBwdSrc
    sta MemCpyBwdSrc+1

    pha
    pha
    tya
    clc
    adc #SoundInt.bytes
    sta MemCpyBwdTrg
    pla
    adc #0
    sta MemCpyBwdTrg+1

    tya
    sec
    ldy CurrEvent
    sbc SoundEventsLo,y
    sta .restoreA+1
    pla
    sbc SoundEventsHi,y
    tay
.restoreA
    lda #0
    jsr MemCpyBwd
    clc
    lda CurrEvent
    adc #0
    jmp SetCurrEvent
}


InsertEvent:
{
    jsr AddEvent
    jsr DrawEventValues
    jmp DrawTime
}

DeleteEvent:
{
    {   ; check if this is the last event. don't delete the last event.
        lda WorkSound + SoundInt.bytes + SoundInt.frames
        bne %
        rts
    }

    ldx CurrEvent
    lda SoundEventsLo,x
    sta MemCpyFwdTrg
    lda SoundEventsHi,x
    sta MemCpyFwdTrg+1
    inx
    lda SoundEventsLo,x
    sta MemCpyFwdSrc
    lda SoundEventsHi,x
    sta MemCpyFwdSrc+1
    {
        jsr GetEventCount
        cpx #1  ; can't delete last event
        bcs %
        rts
    }
    sec
    tya
    ldy CurrEvent
    iny
    sbc SoundEventsLo,y
    pha
    lda SoundEventsHi,x
    sbc SoundEventsHi,y
    tay
    pla
    jsr MemCpyFwd
    {
        lda CurrEvent
        beq %
        dec CurrEvent
    }
    jsr DrawEventValues
    jmp DrawTime
}


; sets the current event, does not change x
SetCurrEvent:
{
    {
        cmp CurrEvent
        beq %
        sta CurrEvent
        tay
        lda SoundEventsLo,y
        sta GetCurrEventValue+1
        sta SetCurrEventValue+1
        sta AddCurrEventValue+1
        lda SoundEventsHi,y
        sta GetCurrEventValue+2
        sta SetCurrEventValue+2
        sta AddCurrEventValue+2
    }
    rts
}

GetCurrControlValue:
    ldy #SoundInt.control
GetCurrEventValue:
{
    lda WorkSound,y
    rts
}

SetCurrControlValue:
    ldy #SoundInt.control
    bne SetCurrEventValue
SetEventValue2:
{
    pha
    txa
    jsr SetCurrEventValue
    pla
    iny
} ; fallthrough
SetCurrEventValue:
{
    sta WorkSound,y
    rts
}

AddCurrEventValue:
{
    adc WorkSound,y
    jmp SetCurrEventValue
}

DrawTime:
{
    jsr DrawSoundTotalFrames
    jmp DrawTimeline
}

DrawEventValues:
{
    jsr DrawToggles
    jsr DrawExportLabels
    jsr DrawEventNumber
    jsr DrawValueName
    jsr DrawValueDuration
    jsr DrawValueFreq
    jsr DrawValuePulse
    jsr DrawValueKey
    jsr DrawValueDisable
    jsr DrawValueType
    jsr DrawAttackValue
    jsr DrawDecayValue
    jsr DrawSustainValue
    jsr DrawReleaseValue
    jsr DrawValueDeltaFreq
    jsr DrawValueDeltaPulse
    jmp DrawValueLoop
}

DrawSoundTotalFrames:
{
    lda #0
    sta TotalTime
    sta TotalTime+1
    sta Hex2Dec+2
    lda #<(WorkSound+SoundInt.frames)
    sta DrawSoundIter+1
    lda #>(WorkSound+SoundInt.frames)
    sta DrawSoundIter+2
    {
DrawSoundIter:
        lda WorkSound+SoundInt.frames
        beq %
        clc
        adc TotalTime
        sta TotalTime
        {
            bcc %
            inc TotalTime+1
        }
        clc
        lda DrawSoundIter+1
        adc #SoundInt.bytes
        sta DrawSoundIter+1
        {
            bcc %
            inc DrawSoundIter+2
        }
        jmp !
    }
    lda TotalTime
    sta Hex2Dec
    lda TotalTime+1
    sta Hex2Dec+2

    lda #$01
    sta NumAlign
    ldy #<TimeTotalScreen
    lda #>TimeTotalScreen
    ldx #3
    jmp PrintNum
}

DrawTimeline:
{
    ldx #39
    {
        lda #$2d ; '-'
        sta $400+40,x
        lda #14
        sta $d800+40,x
        dex
        bpl !
    }

    lda CurrEvent
    pha

    ldx #0
    stx CurrTime
    stx CurrTime+1
    {
        txa
        pha
        jsr SetCurrEvent
        ldy #SoundInt.frames
        jsr GetCurrEventValue
        beq %
        pha
        ldx CurrTime
        lda CurrTime+1
        ldy #81 ; 40 * 2 + 1
        jsr Mul16x8 ; MathNumber is
        lda TotalTime
        sta Divisor
        lda TotalTime+1
        sta Divisor+1
        lda #0
        sta Divisor+2
        jsr Divide24
        lda MathNumber
        lsr
        tay
        pla
        {
            clc
            adc CurrTime
            sta CurrTime
            bcc %
            inc CurrTime+1
        }
        pla
        tax
        tya
        sta SoundEventScreen,x
        inx
        jmp !
    }
    pla
    sta DrawTimeCount
    tax
    lda #39
    sta SoundEventScreen,x

    ldx #0
    {
        txa
        jsr SetCurrEvent
        ldy #SoundInt.frames
        jsr GetCurrEventValue
        beq %
        ldy #SoundInt.loop
        jsr GetCurrEventValue
        {
            bmi %
            tay
            lda SoundEventScreen,y
            sta DrawLoopArrows
            inx
            cmp SoundEventScreen,x
            beq .DoneLoop
            ldy SoundEventScreen,x
            lda #$1f
            {
                sta $400+40,y
                dey
const DrawLoopArrows = *+1
                cpy #1
                bne !
            }
            jmp .DoneLoop
        }
        inx
        jmp !
    }
.DoneLoop



    ldy #0
    {
const DrawTimeCount = * + 1
        cpy #1
        bcs %
        ldx SoundEventScreen,y
        tya
        clc
        adc #$31
        {
            cmp #$3a
            bcc %
            sbc #$3a - 1
        }
        sta $400+40,x
        lda #1
        sta $d800+40,x
        iny
        bne !
    }

    pla
    jmp SetCurrEvent
}

PrintNum:
{
    zpLocal .zpLeft
    stx .numChars
;    stx .rgtAlign
    sty PlotNibble+4
    sta PlotNibble+5
    lda #$20
    {
        jsr PlotTrg
        bpl !
    }
    jsr ConvertToDec

    jsr Hex2DecLen
    sta .zpLeft

    ; max fig = 5
.numChars = *+1
    ldx #4
    dex
    ldy #0
    {
        zpLocal .zpNum
        lda Hex2DecResult,y
        pha
        jsr PlotNibble
        pla
        dec .zpLeft
        beq %
        lsr
        lsr
        lsr
        lsr
        jsr PlotNibble
        dec .zpLeft
        beq %
        iny
        bne !
    }
    rts
}

PrintHexNum:
{
    zpLocal .zpLeft
    sty PlotNibble+4
    sta PlotNibble+5

    ldy #0
    {
        zpLocal .zpNum
        lda Hex2DecResult,y
        jsr PlotNibble
        bmi %
        lda Hex2DecResult,y
        lsr
        lsr
        lsr
        lsr
        jsr PlotNibble
        bmi %
        iny
        bne !
    }
    rts
}

PlotNibble:
{
    jsr NibToPet
PlotTrg:
    sta TimeTotalScreen,x
    dex
    rts
}

; a = hex nibble (hi nibble masked off), return '0'-'9' or 'A'-'F'
; x, y untouched
NibToPet:
{
    and #$f
    clc
    adc #$30
    {
        cmp #$3a
        bcc %
        sbc #$3a-1 ; A = 1
    }
    rts
}

; x/lo, a/hi: screen address
; return value in x/lo, a/hi
InputToHex:
{
    zpLocal .zpScrn.w
    zpLocal .zpVal.w

    stx .zpScrn
    sta .zpScrn+1
    ldy #0
    {
        ldx #3
        {
            asl .zpVal
            rol .zpVal+1
            dex
            bpl !
        }
        lda (.zpScrn),y
        {
            and #$3f ; make uppercase alpha same as lowercase
            cmp #$30
            bcs %
            adc #$3a-1
        }
        sec
        sbc #$30
        and #$f
        ora .zpVal
        sta .zpVal
        iny
        cpy #4
        bcc !
    }
    ldx .zpVal
    lda .zpVal+1
    rts
}

SetDrawStringTrg:
{
    stx DrawStringDest+1
    sta DrawStringDest+2
    stx DrawStringColDest+1
    clc
    adc #$d4
    sta DrawStringColDest+2
    rts
}

IncDrawStringSrc:
{
    sec
    txa
    adc DrawStringSrc+1
    sta DrawStringSrc+1
    {
        bcc %
        inc DrawStringSrc+2
    }
    rts
}

IncDrawStringDest:
{
    clc
    txa
    adc DrawStringDest+1
    sta DrawStringDest+1
    {
        bcc %
        inc DrawStringDest+2
    }
    rts
}

DrawStringSrc:
{
    lda $1234,x
    rts
}

SkipString:
{
    stx DrawStringSrc+1
    sta DrawStringSrc+2
    ldx #0
    {
        jsr DrawStringSrc
        bmi %
        inx
        bpl !
    }
    rts
}

DrawString:
{
    stx DrawStringSrc+1
    sta DrawStringSrc+2
DrawStringNext:
    sty DrawStringCol+1
    ldx #0
    {
        jsr DrawStringSrc
        bmi %
DrawStringDest:
        sta $2345,x
DrawStringCol:
        lda #14
DrawStringColDest:
        sta $d845,x
        inx
        bpl !
    }
    rts
}

DrawEventNumber:
{
    ldx CurrEvent
    inx
    stx Hex2Dec
    lda #0
    sta Hex2Dec+1
    sta Hex2Dec+2
    lda #$ff
    sta NumAlign
    ldy #<EventNumberScreen
    lda #>EventNumberScreen
    ldx #2
    jmp PrintNum
}

GetTooggleChar:
{
    {
        lda #$20
        bcc %
        lda #$3d
    }
    rts
}

GetTooggleLabel:
{
    {
        lda #$20
        bcc %
        lda #$2a
    }
    rts
}

DrawToggles:
{
    ldy #SoundInt.setValue
    jsr GetCurrEventValue
    lsr ; freq
    pha
    jsr GetTooggleChar
    sta $400+5*40 ; Key
    lda #10
    sta $d800+5*40 ; Key
    pla
    lsr ; pulse
    pha
    jsr GetTooggleChar
    sta $400+6*40 ; Key
    lda #10
    sta $d800+6*40 ; Key
    pla
    lsr ; attack / decay
    pha
    jsr GetTooggleChar
    sta $400+10*40 ; Key
    sta $400+11*40 ; Key
    lda #10
    sta $d800+10*40 ; Key
    sta $d800+11*40 ; Disable
    pla
    lsr ; sustain / release    
    pha
    jsr GetTooggleChar
    sta $400+12*40 ; Key
    sta $400+13*40 ; Key
    lda #10
    sta $d800+12*40 ; Key
    sta $d800+13*40 ; Disable
    pla
    lsr
    pha
    jsr GetTooggleChar
    sta $400+7*40 ; Key
    sta $400+8*40 ; Disable
    sta $400+9*40 ; Waveform
    lda #10
    sta $d800+7*40 ; Key
    sta $d800+8*40 ; Disable
    sta $d800+9*40 ; Waveform
    pla
    lsr
    pha
    jsr GetTooggleChar
    sta $400+14*40 ; Key
    lda #10
    sta $d800+14*40 ; Key
    pla
    lsr
    pha
    jsr GetTooggleChar
    sta $400+15*40 ; Key
    lda #10
    sta $d800+15*40 ; Key
    pla
    lsr
    jsr GetTooggleChar
    sta $400+16*40 ; Key
    lda #10
    sta $d800+16*40 ; Key
    rts
}

DrawExportLabels:
{
    ldy #SoundInt.expLabel
    jsr GetCurrEventValue
    lsr ; freq
    pha
    jsr GetTooggleLabel
    sta $401+5*40 ; Key
    lda #10
    sta $d801+5*40 ; Key
    pla
    lsr ; pulse
    pha
    jsr GetTooggleLabel
    sta $401+6*40 ; Key
    lda #10
    sta $d801+6*40 ; Key
    pla
    lsr ; attack / decay
    pha
    jsr GetTooggleLabel
    sta $401+10*40 ; Key
    sta $401+11*40 ; Key
    lda #10
    sta $d801+10*40 ; Key
    sta $d801+11*40 ; Disable
    pla
    lsr ; sustain / release    
    pha
    jsr GetTooggleLabel
    sta $401+12*40 ; Key
    sta $401+13*40 ; Key
    lda #10
    sta $d801+12*40 ; Key
    sta $d801+13*40 ; Disable
    pla
    lsr
    pha
    jsr GetTooggleLabel
    sta $401+7*40 ; Key
    sta $401+8*40 ; Disable
    sta $401+9*40 ; Waveform
    lda #10
    sta $d801+7*40 ; Key
    sta $d801+8*40 ; Disable
    sta $d801+9*40 ; Waveform
    pla
    lsr
    pha
    jsr GetTooggleLabel
    sta $401+14*40 ; Key
    lda #10
    sta $d801+14*40 ; Key
    pla
    lsr
    pha
    jsr GetTooggleLabel
    sta $401+15*40 ; Key
    lda #10
    sta $d801+15*40 ; Key
    pla
    lsr
    jsr GetTooggleLabel
    sta $401+4*40 ; Key
    lda #10
    sta $d801+4*40 ; Key
    rts
}



DrawValueName:
{
    ldx #0
    {
        lda CurrSoundName,x
        beq %
        sta SoundNameInputScreen,x
        lda #14
        sta SoundNameInputScreen + $d400,x
        inx
        bne !
    }
    lda #$20
    {
        sta SoundNameInputScreen,x
        inx
        cpx #21
        bcc !
    }
    rts
}

DrawValueDuration:
{
    ldy #SoundInt.frames
    jsr GetCurrEventValue
    sta Hex2Dec
    lda #0
    sta Hex2Dec+1
    sta Hex2Dec+2
    jsr ConvertToDec
    lda #$ff
    sta NumAlign
    ldy #<DurationInputScreen
    lda #>DurationInputScreen
    ldx #3
    jmp PrintNum
}

DrawValueFreq:
{
    zpLocal .zpEvent.w
    ldy CurrEvent
    lda SoundEventsLo,y
    sta .zpEvent
    lda SoundEventsHi,y
    sta .zpEvent+1
    ldy #SoundInt.freq
    lda (.zpEvent),y
    sta Hex2DecResult
    iny
    lda (.zpEvent),y
    sta Hex2DecResult+1
    ldy #<FreqInputScreen
    lda #>FreqInputScreen
    ldx #3
    jmp PrintHexNum
}

DrawValueDeltaFreq:
{
    ldy #SoundInt.deltaFreq
    jsr GetCurrEventValue
    sta Hex2DecResult
    iny
    jsr GetCurrEventValue
    sta Hex2DecResult+1
    ldy #<FreqDeltaInputScreen
    lda #>FreqDeltaInputScreen
    ldx #3
    jmp PrintHexNum
}

DrawValuePulse:
{
    zpLocal .zpEvent.w
    ldy CurrEvent
    lda SoundEventsLo,y
    sta .zpEvent
    lda SoundEventsHi,y
    sta .zpEvent+1
    ldy #SoundInt.pulse
    lda (.zpEvent),y
    sta Hex2DecResult
    iny
    lda (.zpEvent),y
    sta Hex2DecResult+1
    ldy #<PulseInputScreen
    lda #>PulseInputScreen
    ldx #3
    jmp PrintHexNum
}

DrawValueDeltaPulse:
{
    ldy #SoundInt.deltaPulse
    jsr GetCurrEventValue
    sta Hex2DecResult
    iny
    jsr GetCurrEventValue
    sta Hex2DecResult+1
    ldy #<PulseDeltaInputScreen
    lda #>PulseDeltaInputScreen
    ldx #3
    jmp PrintHexNum
}

DrawValueLoop:
{
    ldy #SoundInt.loop
    jsr GetCurrEventValue
    {
        bpl %
        ldx #<LoopValueScreen
        lda #>LoopValueScreen
        jsr SetDrawStringTrg
        lda #0
        jmp DrawOnOff
    }
    clc
    adc #1
    sta Hex2Dec
    lda #0
    sta Hex2Dec+2
    lda #$ff
    sta NumAlign
    ldy #<LoopValueScreen
    lda #>LoopValueScreen
    ldx #2
    jmp PrintNum
}

; a = current event
CheckLoop:
{
    zpLocal .zpChk.w
    lda #<WorkSound
    sta .zpChk
    lda #>WorkSound
    sta .zpChk+1
    ldx #0
    {
        ldy #SoundInt.setValue
        lda (.zpChk),y
        beq %
        {
            cpx CurrEvent
            beq %
            ldy #SoundInt.loop
            lda #$ff
            sta (.zpChk),y
            ldy #SoundInt.setValue
            lda (.zpChk),y
            and #SoundMask.Loop ^ $ff
        }
        clc
        lda .zpChk
        adc #SoundInt.bytes
        sta .zpChk
        {
            bcc %
            inc .zpChk
        }
        inx
        bne !
    }
    rts
}

DrawValueKey:
{
    ldx #<KeyValueScreen
    lda #>KeyValueScreen
    jsr SetDrawStringTrg
    ldy #SoundInt.control
    jsr GetCurrEventValue
    and #SoundCtrl.KeyOn
} ; fallthrough
DrawOnOff:
{
    bne .on
    ldx #<OffText
    lda #>OffText
    ldy #14
    jmp DrawString
.on
    ldx #<OnText
    lda #>OnText
    ldy #1
    jmp DrawString
}

DrawValueDisable:
{
    ldx #<DisableValueScreen
    lda #>DisableValueScreen
    jsr SetDrawStringTrg
    ldy #SoundInt.control
    jsr GetCurrEventValue
    and #SoundCtrl.Disable
    jmp DrawOnOff
}

DrawValueType:
{
    ldx #<TypeValueScreen
    lda #>TypeValueScreen
    jsr SetDrawStringTrg
    ldy #SoundInt.control
    jsr GetCurrEventValue
    tax
    and #SoundCtrl.Triangle
    beq .not_tri
    ldx #<TriangleText
    lda #>TriangleText
    ldy #10
    jmp DrawString
.not_tri
    txa
    and #SoundCtrl.SawTooth
    beq .not_saw
    ldx #<SawText
    lda #>SawText
    ldy #10
    jmp DrawString
.not_saw
    txa
    and #SoundCtrl.Rectangle
    beq .not_rect
    ldx #<RectText
    lda #>RectText
    ldy #10
    jmp DrawString
.not_rect
    ldx #<NoiseText
    lda #>NoiseText
    ldy #10
    jmp DrawString
}

DrawAttackValue:
{
    ldy #SoundInt.attackDecay
    jsr GetCurrEventValue
    lsr
    lsr
    lsr
    lsr
    jsr NibToPet
    sta AttackValueScreen
    lda #1
    sta AttackValueScreen + $d400
    rts
}

DrawDecayValue:
{
    ldy #SoundInt.attackDecay
    jsr GetCurrEventValue
    jsr NibToPet
    sta DecayValueScreen
    lda #1
    sta DecayValueScreen + $d400
    rts
}

DrawSustainValue:
{
    ldy #SoundInt.sustainRelease
    jsr GetCurrEventValue
    lsr
    lsr
    lsr
    lsr
    jsr NibToPet
    sta SustainValueScreen
    lda #1
    sta SustainValueScreen + $d400
    rts
}

DrawReleaseValue:
{
    ldy #SoundInt.sustainRelease
    jsr GetCurrEventValue
    jsr NibToPet
    sta ReleaseValueScreen
    lda #1
    sta ReleaseValueScreen + $d400
    rts
}

GetOptionMask:
{
    ldx #0
    {
        lda CurrOption
        cmp #Options.Count
        bcs %
        cmp #Options.Loop
        bcc .notLop
        ldx #SoundMask.Loop
        bcs %
.notLop cmp #Options.PulseDelta
        bcc .notPDL
        ldx #SoundMask.PulsDelta
        bcs %
.notPDL cmp #Options.FreqDelta
        bcc .notFDL
        ldx #SoundMask.FreqDelta
        bcs %
.notFDL cmp #Options.Sustain
        bcc .notSR
        ldx #SoundMask.SusRel
        bcs %
.notSR  cmp #Options.Attack
        bcc .notAD
        ldx #SoundMask.AtkDcy
        bcs %
.notAD  cmp #Options.Key
        bcc .notCT
        ldx #SoundMask.Control
        bcs %
.notCT  cmp #Options.Pulse
        bcc .notPL
        ldx #SoundMask.Pulse
        bcs %
.notPL  cmp #Options.Frequency
        bcc %
        ldx #SoundMask.Freq
    }
    rts
}

ToggleControl:
{
    jsr GetOptionMask
    stx .meor+1
    ldy #SoundInt.setValue
    jsr GetCurrEventValue
.meor
    eor #$00
    jsr SetCurrEventValue
    jmp DrawToggles
}

ToggleExportLabel:
{
    lda CurrOption
    {
        cmp #Options.Duration
        bne %
        ldx #$80
        bne .tog
    }
    {
        cmp #Options.Loop
        bne %
        rts
    }
    jsr GetOptionMask
.tog
    stx .meor+1
    ldy #SoundInt.expLabel
    jsr GetCurrEventValue
.meor
    eor #$00
    jsr SetCurrEventValue
    jmp DrawExportLabels
}

CheckChangeEvents:
{
    ; check for changing events
    ; 5 |   ,  |   @  |   :  |   .  |   -  |   l  |   p  |   +  |
    ; 6 |   /  |   ^  |   =  |R-SHFT| HOME |   ;  |   *  |   £  |
    {
        lda KeyboardBitsChange+5    ; @
        and #$40
        beq %
        ldx CurrEvent
        dex
        bmi %
        txa
        jsr SetCurrEvent
        jsr DrawEventValues
    }

    {
        zpLocal .zpNext.w
        lda KeyboardBitsChange+6    ; *
        and #$02
        beq %
        ldx CurrEvent
        inx
        lda SoundEventsLo,x
        sta .zpNext
        lda SoundEventsHi,x
        sta .zpNext+1
        ldy #SoundInt.frames
        lda (.zpNext),y
        beq %
        txa
        jsr SetCurrEvent
        jsr DrawEventValues
    }

    {   ; move up / down unless currently editing the option
        lda CurrOptionEnter
        bne %
        {
            jsr KeyUp
            beq %
            lda #$ff
            jsr ChangeOption
        }
        {
            jsr KeyDown
            beq %
            lda #1
            jsr ChangeOption
        }

    { ; = will toggle sound write
        lda KeyboardBitsChange + 6
        and #$20 ; "="
        beq %
        jsr ToggleControl
    }

    { ; L will toggle export label
        lda KeyboardBitsChange + 5
        and #$04 ; "L"
        beq %
        jsr ToggleExportLabel
    }

    {; n for insert event
        ; 4 |   n  |   o  |   k  |   m  |   0  |   j  |   i  |   9  |
        lda KeyboardBitsChange + 4
        and #$80 ; "n"
        beq %
        jsr InsertEvent
    }

    { ; s will save a sound event
        lda KeyboardBitsChange+1
        and #$20
        beq %
        jsr SaveSoundFile
    }

    { ; c= + e will export
        ; 7 | STOP |   q  |  C=  |SPACE |   2  | CTRL |  <-  |   1  |
        lda KeyboardBits+7
        and #$20
        beq %
        {
            ; 1 |L-SHFT|   e  |   s  |   z  |   4  |   a  |   w  |   3  |
            lda KeyboardBitsChange+1
            and #$40
            beq %
            jsr WriteBackSound
            lda #0
            sta CurrentExportType
            jsr ExportSounds
        }

        { ; c= + d will delete a sound event
            ; 2 |   x  |   t  |   f  |   c  |   6  |   d  |   r  |   5  |
            lda KeyboardBitsChange+2
            and #$04
            beq %
            jsr DeleteEvent
        }

    }
    rts
}

UpdateMenu:
{
    {   ; check for keyboard input unless entering something
        ldx CurrOptionEnter
        bne %
        jsr CheckChangeEvents
    }

    ldx CurrOption
    {
        cpx #NumMenus
        bcc %
        rts
    }
    lda MenuLo,x
    sta .func
    lda MenuHi,x
    sta .func+1
.func = *+1
    jmp *
}

MenuLo:
    dc.b <UpdateMenuName, <UpdateMenuFrames, <UpdateMenuFrequency
    dc.b <UpdateMenuPulse, <UpdateMenuKeyOn, <UpdateMenuDisable
    dc.b <UpdateMenuType, <UpdateMenuAttack, <UpdateMenuDecay
    dc.b <UpdateMenuSustain, <UpdateMenuRelease, <UpdateMenuFreqDelta
    dc.b <UpdateMenuPulseDelta, <UpdateMenuLoop
MenuHi:
    dc.b >UpdateMenuName, >UpdateMenuFrames, >UpdateMenuFrequency
    dc.b >UpdateMenuPulse, >UpdateMenuKeyOn, >UpdateMenuDisable
    dc.b >UpdateMenuType, >UpdateMenuAttack, >UpdateMenuDecay
    dc.b >UpdateMenuSustain, >UpdateMenuRelease, >UpdateMenuFreqDelta
    dc.b >UpdateMenuPulseDelta, >UpdateMenuLoop

const NumMenus = * - MenuHi

UpdateMenuName:
    {   ; NAME
        ldx #<SoundNameInputScreen
        lda #>SoundNameInputScreen
        ldy #14
        jsr SetInputScreen
        {
            lda #19
            jsr UpdateInputString
            bcc %
            ldx Cursor
            sta CurrSoundName,x
            {
                dex
                bmi %
                lda SoundNameInputScreen,x
                sta CurrSoundName,x
                bne !
            }
        }
        rts
    }
UpdateMenuFrames:
    {   ; FRAMES
        {
            ldx CurrOptionEnter
            bne %
            jsr CheckLeftRight
            beq %
            clc
            ldy #SoundInt.frames
            jsr AddCurrEventValue
            {
                bne %   ; don't allow < 1 frame events
                lda #1
                jsr SetCurrEventValue
            }
            jsr DrawValueDuration
            jmp DrawTime
        }
        ldx #<DurationInputScreen
        lda #>DurationInputScreen
        ldy #14
        jsr SetInputScreen
        {
            lda #3
            jsr UpdateInputString
            bcc %
            ldx #<DurationInputScreen
            lda #>DurationInputScreen
            jsr ScreenToDecByte
            {
                bcs %
                ldy #SoundInt.frames
                jsr SetCurrEventValue
            }
            jsr DrawValueDuration
            jmp DrawTime
        }
        rts
    }

UpdateMenuFrequency:
    {   ; FREQ
        {
            ldx CurrOptionEnter
            bne %
            ldy #SoundInt.freq
            jsr LeftRightWord
            bcc %
            jmp DrawValueFreq
        }
        ldx #<FreqInputScreen
        lda #>FreqInputScreen
        ldy #14
        jsr SetInputScreen
        {
            lda #4
            jsr UpdateInputString
            bcc %
            ldx #<FreqInputScreen
            lda #>FreqInputScreen
            jsr InputToHex
            ldy #SoundInt.freq
            jsr SetEventValue2
            jsr DrawValueFreq
        }
        rts
    }

UpdateMenuPulse:
    {   ; PULS
        {
            ldx CurrOptionEnter
            bne %
            ldy #SoundInt.pulse
            jsr LeftRightWord
            bcc %
            jmp DrawValuePulse
        }
        ldx #<PulseInputScreen
        lda #>PulseInputScreen
        ldy #14
        jsr SetInputScreen
        {
            lda #4
            jsr UpdateInputString
            bcc %
            ldx #<PulseInputScreen
            lda #>PulseInputScreen
            jsr InputToHex
            ldy #SoundInt.pulse
            jsr SetEventValue2
            jsr DrawValuePulse
        }
        rts
    }

UpdateMenuKeyOn:
    {   ; KEY
        {
            lda KeyboardBitsChange
            and #$04
            beq %
            jsr GetCurrControlValue
            eor #SoundCtrl.KeyOn
            jsr SetCurrControlValue
            jsr DrawValueKey
        }
        rts
    }

UpdateMenuDisable:
    {   ; DIS
        {
            lda KeyboardBitsChange
            and #$04
            beq %
            jsr GetCurrControlValue
            eor #SoundCtrl.Disable
            jsr SetCurrControlValue
            jsr DrawValueDisable
        }
        rts
    }

UpdateMenuType:
    {   ; TYPE
        ;KeyboardBits + 0 & 0x4
        {
            lda KeyboardBitsChange
            and #$04
            beq %
            jsr GetCurrControlValue
            {
                zpLocal .zpVal
                pha
                and #$f
                sta .zpVal
                pla
                and #$f0
                asl
                {
                    bne %
                    lda #$10
                }
                ora .zpVal
                jsr SetCurrControlValue
                jsr DrawValueType
            }
        }
        rts
    }

UpdateMenuAttack:
    {   ; ATAK
        {
            lda KeyboardBitsChange
            and #$04
            beq %
            ldy #SoundInt.attackDecay
            jsr GetCurrEventValue
            pha
            jsr ShiftHeld
            bne .dec2
            pla
            clc
            adc #$10
            jmp .set2
.dec2       pla
            sec
            sbc #$10
.set2       ldy #SoundInt.attackDecay
            jsr SetCurrEventValue
            jsr DrawAttackValue
        }
        rts
    }

UpdateMenuDecay:
    {   ; DCAY
        {
            zpLocal .zpVal
            lda KeyboardBitsChange
            and #$04
            beq %
            ldy #SoundInt.attackDecay
            jsr GetCurrEventValue
            pha
            and #$f0
            sta .zpVal
            jsr ShiftHeld
            clc
            bne .dec3
            pla
            adc #$01
            jmp .set3
.dec3       pla
            adc #$ff            
.set3       and #$f
            ora .zpVal
            ldy #SoundInt.attackDecay
            jsr SetCurrEventValue
            jsr DrawDecayValue
        }
        rts
    }

UpdateMenuSustain:
    {   ; SUST
        {
            lda KeyboardBitsChange
            and #$04
            beq %
            ldy #SoundInt.sustainRelease
            jsr GetCurrEventValue
            pha
            jsr ShiftHeld
            bne .dec4
            pla
            clc
            adc #$10
            jmp .set4
.dec4       pla
            sec
            sbc #$10
.set4       ldy #SoundInt.sustainRelease
            jsr SetCurrEventValue
            jsr DrawSustainValue
        }
        rts
    }

UpdateMenuRelease:
    {   ; REL
        {
            zpLocal .zpVal
            lda KeyboardBitsChange
            and #$04
            beq %
            ldy #SoundInt.sustainRelease
            jsr GetCurrEventValue
            pha
            and #$f0
            sta .zpVal
            jsr ShiftHeld
            clc
            bne .dec0
            pla
            adc #$01
            jmp .set0
.dec0       pla
            adc #$ff            
.set0       and #$f
            ora .zpVal
            ldy #SoundInt.sustainRelease
            jsr SetCurrEventValue
            jsr DrawReleaseValue
        }
        rts
    }

UpdateMenuFreqDelta:
    {   ; FREQ DELTA
        {
            ldx CurrOptionEnter
            bne %
            ldy #SoundInt.deltaFreq
            jsr LeftRightWord
            bcc %
            jmp DrawValueDeltaFreq
        }
        ldx #<FreqDeltaInputScreen
        lda #>FreqDeltaInputScreen
        ldy #14
        jsr SetInputScreen
        {
            lda #4
            jsr UpdateInputString
            bcc %
            ldx #<FreqDeltaInputScreen
            lda #>FreqDeltaInputScreen
            jsr InputToHex
            ldy #SoundInt.deltaFreq
            jsr SetEventValue2
            jsr DrawValueDeltaFreq
        }
        rts
    }

UpdateMenuPulseDelta:
    {   ; PULSE DELTA
        {
            ldx CurrOptionEnter
            bne %
            ldy #SoundInt.deltaPulse
            jsr LeftRightWord
            bcc %
            jmp DrawValueDeltaPulse
        }
        ldx #<PulseDeltaInputScreen
        lda #>PulseDeltaInputScreen
        ldy #14
        jsr SetInputScreen
        {
            lda #4
            jsr UpdateInputString
            bcc %
            ldx #<PulseDeltaInputScreen
            lda #>PulseDeltaInputScreen
            jsr InputToHex
            ldy #SoundInt.deltaPulse
            jsr SetEventValue2
            jsr DrawValueDeltaPulse
        }
        rts
    }

UpdateMenuLoop:
    {   ; LOOP
        lda CurrEvent
        beq %
        lda KeyboardBitsChange
        and #$04
        beq %
        ldy #SoundInt.loop
        jsr GetCurrEventValue
        pha
        jsr ShiftHeld
        clc
        bne .dec0
        pla
        bmi .ok
        cmp CurrEvent
        bcs %
.ok     clc
        adc #$01
        jmp .set0
.dec0   pla
        adc #$ff
        cmp #$fe
        beq %
.set0   ldy #SoundInt.loop
        jsr SetCurrEventValue
        {
            cmp #$ff
            beq %
            jsr CheckLoop
        }
        jsr DrawTimeline
        jmp DrawValueLoop
        rts
    }
}

; Z set: no change
; S set: -1 : +1
CheckLeftRight:
{
    {
        lda KeyboardBitsChange
        and #$04
        beq %
        {
            jsr ShiftHeld
            bne %
            lda #1
            rts
        }
        lda #$ff
    }
    rts
}

LeftRightWord:
{
    jsr CheckLeftRight
    clc
    bne .change
    rts
.change
    pha
    lda KeyboardBits+7
    and #$20
    beq .nothi
    pla
.addhi
    iny
    jsr AddCurrEventValue
    sec
    rts
.nothi
    pla
    bmi .neg
    jsr AddCurrEventValue
    lda #0
    beq .addhi
.neg
    jsr AddCurrEventValue
    lda #$ff
    bne .addhi
}

SetInputScreen:
    stx SetInputChar+1
    stx GetInputChar+1
    sta SetInputChar+2
    sta GetInputChar+2
    clc
    adc #>($d800-$400)
    stx SetInputChar + 7
    sta SetInputChar + 8
    sty SetInputChar+5
    rts

SetInputChar:
    sta $1234,y
    pha
    lda #14
    sta $d823,y
    pla
    rts
GetInputChar:
    lda $1234,y
    rts

UpdateInputString:
{
    sta InputMaxLength
    {
        ldx CurrOptionEnter
        bne %
        jsr CheckEnter
        clc
        rts
    }
    {
        zpLocal .zpScrn.w
        {
            inc CursorFlash
            lda CursorFlash
            and #$1f
            bne %
            ldy Cursor
            jsr GetInputChar
            eor #$80
            jsr SetInputChar
        }

        {   ; check delete
            lda KeyboardBitsChange
            and #1
            beq %
            ldy Cursor
            beq %
            lda #$20
            jsr SetInputChar
            dey
            sty Cursor
            eor #$80
            jsr SetInputChar
        }

        jsr HitEnter
        bne .complete
        jsr TextKey
        beq %
        ldy Cursor
        jsr SetInputChar
        iny
        sty Cursor
        cpy InputMaxLength
        bne %
.complete
        ldy Cursor
        lda #$20
        jsr SetInputChar
        lda #0
        sta CurrOptionEnter
        sec
        rts
    }
    lda #1
    clc
    rts
}

CheckEnter:
{
    {
        jsr HitEnter
        beq %
        sta CurrOptionEnter
        lda #0
        sta Cursor
        ldy #0
        lda #$20
        {
            jsr SetInputChar
            iny
            cpy InputMaxLength
            bcc !
        }
    }
    rts
}

; a = option delta
ChangeOption:
{
    clc
    adc CurrOption
    bmi .over
    cmp #Options.Count
    bcs .over
    pha
    lda CurrOption
    ldy #$ff
    jsr HighlightOption
    pla
    sta CurrOption
    ldy #1
    jsr HighlightOption
.over
    rts
}

; y = color (-1 for reset), a = option index
HighlightOption:
{
    zpLocal .zpIdx
    clc
    adc #1
    sta .zpIdx
    asl
    asl
    adc .zpIdx
    tax
    jmp DrawToolLine
}

ClearScreen:
{
    ldx #0
    {
        lda #$20
        sta $400,x
        sta $500,x
        sta $600,x
        sta $700,x
        lda #14
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $db00,x
        inx
        bne !
    }
    rts
}

{
    zpLocal .zpScreen.w
    zpLocal .zpColor.w
    zpLocal .zpText.w
    zpLocal .zpCol
; x = 6 * line index, y = color or -1 for default
DrawToolLine:
{
    lda SidFXScreen,x
    sta .zpScreen
    sta .zpColor
    inx
    lda SidFXScreen,x
    sta .zpScreen+1
    clc
    adc #$d4
    sta .zpColor+1
    inx
    lda SidFXScreen,x
    sta .zpText
    inx
    lda SidFXScreen,x
    sta .zpText+1
    inx
    {
        tya
        bpl %
        lda SidFXScreen,x
    }
    sta .zpCol
    inx
    ldy #0
    {
        lda (.zpText),y
        bmi %
        sta (.zpScreen),y
        lda .zpCol
        sta (.zpColor),y
        iny
        bne !
    }
    rts
}

DrawToolScreen:
    ldx #0
    {
        ldy #$ff
        jsr DrawToolLine
        cpx #SidFXLines
        bcc !
    }
    rts
}

ToolStart:
    sei

    lda #$ff
    sta CurrEvent
    lda #0
    sta InputUpper
    sta CurrOption
    sta SoundPlaying
    jsr SetCurrEvent

    jsr ClearScreen
    jsr DrawToolScreen

    lda #1
    sta CurrOptionEnter+1


    jsr DrawSoundTotalFrames

    jsr DrawTime
    jsr DrawEventValues

    ; show the current option
    lda CurrOption
    ldy #1
    jsr HighlightOption

    lda #14
    sta $d020

    {
        lda #$80
        {
            cmp $d012
            bne !
        }
        sei
        jsr UpdateTestSound
        jsr UpdateKeyboard
        jsr UpdateMenu
        {
            lda CurrOptionEnter
            bne %
            {
    ; 7 | STOP |   q  |  C=  |SPACE |   2  | CTRL |  <-  |   1  |
                lda KeyboardBitsChange + 7
                and #$10
                beq %
                lda SoundPlaying
                beq .start
                lda #1
                sta SoundPlayStopLoop ; work sound is always channel 0
                bne %
.start          jsr TestSound
            }
            {
            ; m for main menu
    ; 4 |   n  |   o  |   k  |   m  |   0  |   j  |   i  |   9  |
                lda KeyboardBitsChange+4
                and #$10
                beq %
                lda #13
                sta $d020
                jsr WriteBackSound
                jmp SoundBank
            }
        }
       
        lda KeyboardBits + 7
        and #$20 ; C=
        beq !
        lda KeyboardBitsChange + 7
        and #$40 ; Q
        beq !
    }

    cli
    jsr ClearScreen
    rts


;
;
; KEYBOARD INPUT
;
;

; returns Z clear if return hit
HitEnter:
{
    lda KeyboardBitsChange
    and #2
    rts
}

; holding shift if Z=0 or C=1
ShiftHeld:
{
    sec
    {
        lda KeyboardBits+1
        and #$80
        bne %
        lda KeyboardBits+6
        and #$20
        bne %
        clc
    }
    rts    
}

KeyDown:
{
    jsr ShiftHeld
    beq CursorDownKey
    lda #0
    rts
}

KeyUp:
{
    {
        jsr ShiftHeld
        beq %
CursorDownKey:
        lda KeyboardBitsChange
        and #$80
    }
    rts
}

; returns valid key screen code input otherwise 0 and Z set
TextKey:
{
    ldx #0
    ldy #0
    {
        lda KeyboardBitsChange,x
        {
            beq %
            {
                lsr
                {
                    bcc %
                    lda TextKeyLookup,y
                    cmp #$ff
                    beq .noqy
                    pha
                    jsr ShiftHeld
                    pla
                    bcs .mayup
                    ldx InputUpper
                    beq .noup
.mayup              cmp #$1b
                    bcs .noup
                    adc #$40
.noup               inx ; make sure Z clear
.noqy               rts
                }
                iny
                bne !
            }
        }
        clc
        tya
        adc #8
        tay
        inx
        cpx #8
        bcc !
    }
    lda #0
    rts
}

TextKeyLookup:
    dc.b $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
    TEXT [petsci] "3wa4zse"
    dc.b $ff ; L-SHIFT
    TEXT [petsci] "5rd6cftx"
    TEXT [petsci] "7yg8bhuv"
    TEXT [petsci] "9ij0mkon"
    TEXT [petsci] "+pl-.:@,"
    TEXT [petsci] "~*"
    dc.b $3b,$ff,$ff ; semi colon, home, right shift
    TEXT [petsci] "=^/"
    TEXT [petsci] "1`"
    dc.b $ff ; ctrl
    TEXT [petsci] "2 "
    dc.b $ff ; c=
    TEXT [petsci] "q"
    dc.b $ff ; stop

; KEYBOARD MATRIX
;   |   38 |   30 |   28 |   20 |   18 |   10 |   8  |   0  |
;---+------+------+------+------+------+------+------+------+
; 0 | DOWN |  F5  |  F3  |  F1  |  F7  |RIGHT |  RET |  DEL |
; 1 |L-SHFT|   e  |   s  |   z  |   4  |   a  |   w  |   3  |
; 2 |   x  |   t  |   f  |   c  |   6  |   d  |   r  |   5  |
; 3 |   v  |   u  |   h  |   b  |   8  |   g  |   y  |   7  |
; 4 |   n  |   o  |   k  |   m  |   0  |   j  |   i  |   9  |
; 5 |   ,  |   @  |   :  |   .  |   -  |   l  |   p  |   +  |
; 6 |   /  |   ^  |   =  |R-SHFT| HOME |   ;  |   *  |   £  |
; 7 | STOP |   q  |  C=  |SPACE |   2  | CTRL |  <-  |   1  |
;---+------+------+------+------+------+------+------+------+
;   |  80  |  40  |  20  |  10  |   8  |   4  |   2  |   1  |
; KEYBOARD MASK
InitKeyboard:
{
    lda #0
    ldx #KeyboardBitsLen-1
    {
        sta KeyboardBits,x
        dex
        bpl !
    }
    rts
}

UpdateKeyboard:
{
	lda #$00	; Set to input
	sta $dc03	; Port B data direction register
	ldx #$ff	; Set to output
	stx $dc02	; Port A data direction register

	ldx #7
	{
		lda BitShiftInv,x ; ~(1<<x), KeyboardColumnMasks
		sta $dc00
		lda $dc01
		pha
		ora KeyboardBits,x
		eor #$ff
		sta KeyboardBitsChange,x
		pla
		eor #$ff
		sta KeyboardBits,x
		dex
		bpl !
	}
    rts
}

;
;
; Hex to dec
;
;

; value in Hex2Dec
; => a = decimal value of first 5 bits (0-63)
ConvertToDec0_99:
{
    pha
    lsr
    lsr
    lsr
    and #$0f
    tax
    pla
    and #$07 ; bit 0-2 is the same in decimal (0-7)
    sei
    sed
    clc
    adc BitValuesDec3_5,x
    cld
    cli
    rts
}

ConvertToDec:
{
    lda Hex2Dec
    and #$3f
    jsr ConvertToDec0_99
    sta Hex2DecResult
    lda #0
    sta Hex2DecResult+1
    sta Hex2DecResult+2

    sei
    sed
    {
        lda #$40
        and Hex2Dec
        beq %
        lda Hex2DecResult
        clc
        adc #$64
        sta Hex2DecResult
        bcc %
        inc Hex2DecResult+1
    }
    {
        lda #$80
        and Hex2Dec
        beq %
        lda Hex2DecResult
        clc
        adc #$28
        sta Hex2DecResult
        lda Hex2DecResult+1
        adc #$01
        sta Hex2DecResult+1
    }
    cld
    cli
    {
        lda Hex2Dec+1
        beq %
        ldx #0
        {
            {
                lsr
                bcc %
                pha
                clc
                sei
                sed
                lda BitValuesDec8_12,x
                adc Hex2DecResult
                sta Hex2DecResult
                lda BitValuesDec8_12+1,x
                adc Hex2DecResult+1
                sta Hex2DecResult+1
                cld
                cli
                pla
            }
            inx
            inx
            cpx #10
            bne !
        }
        ldx #0
        {
            {
                lsr
                bcc %
                pha
                clc
                sei
                sed
                lda BitValuesDec13_15,x
                adc Hex2DecResult
                sta Hex2DecResult
                lda BitValuesDec13_15+1,x
                adc Hex2DecResult+1
                sta Hex2DecResult+1
                lda BitValuesDec13_15+2,x
                adc Hex2DecResult+2
                sta Hex2DecResult+2
                cld
                cli
                pla
            }
            inx
            inx
            inx
            cpx #9
            bne !
        }
    }
    {
        lda Hex2Dec+2
        beq %
        sei
        sed
        clc
        lda Hex2DecResult
        adc #$36
        sta Hex2DecResult
        lda Hex2DecResult+1
        adc #$55
        sta Hex2DecResult+1
        lda Hex2DecResult+2
        adc #$06
        sta Hex2DecResult+2
        cld
        cli
    }
    rts
}

Hex2DecLen:
{
    lda Hex2DecResult+2
    beq .le4
    lda #5
    rts
.le4
    lda Hex2DecResult+1
    beq .le2
    cmp #$10
    bcc .is3
    lda #4
    rts
.is3   
    lda #3
    rts
.le2
    lda Hex2DecResult
    cmp #$10
    bcc .is1
    lda #2
    rts
.is1
    lda #1
    rts
}

BitValuesDec3_5:
    dc.b $00,$08,$16,$24,$32,$40,$48,$56,$64,$72,$80,$88,$96
BitValuesDec8_12:
    dc.w $256, $512, $1024, $2048, $4096
BitValuesDec13_15
    dc.t $8192,$16384,$32768


MathNumber: // result of multiply, number to divide by divisor
    ds 4
MathProduct:
Divisor:
    ds 3
MathShift:
DivRemainder:
    ds 3
DivTemp:
    ds 1

Mul16x8:    // x/lo, a/hi * y
{
    stx MathShift
    sta MathShift+1
    sty MathProduct
    lda #0
    sta MathShift+2
    sta MathNumber
    sta MathNumber+1
    sta MathNumber+2
    ldx #8
    {
        {
            lsr MathProduct
            bcc %
            clc
            rept 3 {
                lda MathShift + rept
                adc MathNumber + rept
                sta MathNumber + rept
            }
        }
        asl MathShift
        rol MathShift+1
        rol MathShift+2
        dex
        bne !
    }
    rts
}

Mul16x16:
{
    lda #0
    ldx #3
    {
        sta MathNumber,x
        dex
        bpl !
    }
    ldx #16
    {
        {
            lsr MathProduct+1
            ror MathProduct
            bcc %
            clc
            lda MathShift
            adc MathNumber
            sta MathNumber
            lda MathShift+1
            adc MathNumber+1
            sta MathNumber+1
            lda MathShift+2
            adc MathNumber+2
            sta MathNumber+2
            lda MathShift+3
            adc MathNumber+3
            sta MathNumber+3
        }
        asl MathShift
        rol MathShift+1
        rol MathShift+2
        rol MathShift+3
        dex
        bne !
    }
    rts
}

Divide24:
{
	lda #0
	sta DivRemainder
	sta DivRemainder+1
	sta DivRemainder+2
	ldx #23
    {
        asl MathNumber
        rol MathNumber+1	
        rol MathNumber+2
        rol DivRemainder
        rol DivRemainder+1
        rol DivRemainder+2
        lda DivRemainder
        sec
        sbc Divisor
        tay
        lda DivRemainder+1
        sbc Divisor+1
        sta DivTemp
        lda DivRemainder+2
        sbc Divisor+2
        {
            bcc %
            sta DivRemainder+2
            txa
            lda DivTemp
            sta DivRemainder+1
            sty DivRemainder	
            inc MathNumber
        }
        dex
        bpl !
    }
	rts
}

const SETNAM = $FFBD
const SETLFS = $FFBA
const OPEN = $FFC0
const CHKIN = $FFC6
const CHKOUT = $FFC9
const CHROUT = $FFD2
const CLOSE = $FFC3
const CLRCHN = $FFCC
const READST = $FFB7
const CHRIN = $FFCF
const SAVE = $FFD8
const LOADFILE = $FFD5

; http://codebase64.org/doku.php?id=base:reading_the_directory
LoadDirectory:
{
    jsr InitDir
    lda #DiskDirFileNameLen
    ldx #<DiskDirFileName
    ldy #>DiskDirFileName
    jsr SETNAM      ; call SETNAM

    lda #2       ; filenumber 2
    {
        ldx $ba
        bne %
        ldx #$08       ; default to device number 8
    }

    ldy #0       ; secondary address 0 (required for dir reading!)
    jsr SETLFS     ; call SETLFS

    jsr OPEN      ; call OPEN (open the directory)
    bcc .opened

    ; Accumulator contains BASIC error code
    ; most likely error:
    ; a = $05 (DEVICE NOT PRESENT)

LoadDirExit:
    ldx #3
    {
        lda #$ff
        jsr AddCharToDir
        dex
        bne !
    }
    lda #$02       ; filenumber 2
    jsr CLOSE      ; call CLOSE
    jmp CLRCHN     ; call CLRCHN

.opened
    ldx #2       ; filenumber 2
    jsr CHKIN      ; call CHKIN

    {
        lda #0
        sta ExportByteInLine
        sta DiskDirNameRead
        jsr getbyte    ; get a byte from dir and ignore it
        jsr getbyte    ; get a byte from dir and ignore it
        {
            jsr getbyte
            beq %
;            pha
;            jsr CHROUT
;            pla
            cmp #$22 ; '"'
            bne .chkName
            inc DiskDirNameRead
            bne !
.chkName    ldx DiskDirNameRead
            dex
            bne !
            jsr AddCharToDir
            inc ExportByteInLine
            jmp !
        }
        lda DiskDirNameRead
        beq !
        lda ExportByteInLine
        beq !
        lda #$ff
        jsr AddCharToDir
        jmp !
    }

InitDir:
{
    lda #<DirFiles
    sta AddCharToDir+1
    lda #>DirFiles
    sta AddCharToDir+2
    rts
}

AddCharToDir:
{
    sta DirFiles
    {
        inc AddCharToDir+1
        bne %
        inc AddCharToDir+2
    }
    rts
}

getbyte:
{
    {
        jsr READST     ; call READST (read status byte)
        bne %          ; read error or end of file
        jmp CHRIN      ; call CHRIN (read byte from directory)
    }
    pla            ; don't return to dir reading loop
    pla
    jmp LoadDirExit
}

DiskDirFileName:
    TEXT "$"      ; filename used to access directory
const DiskDirFileNameLen = * - DiskDirFileName

const FileMenuTitle = $400+24*40
const FileMenuDirectory = $400+40+2
const FileMenuFirstFile = FileMenuDirectory+40

FileMenuTitleStr:
                  ;0123456789012345678901234567890123456789
    TEXT [petsci] "Nav:Up/Down      Select:Return     New:="
    dc.b $ff

NewFileMenuTitleStr:
                  ;0123456789012345678901234567890123456789
    TEXT [petsci] "Type a <File>.SND, press Return to save"
    dc.b $ff

FileMenuStartStr:
                  ;0123456789012345678901234567890123456789
    TEXT [petsci] "Reading disk directory"
const FileMenuStartStrLen = *-FileMenuStartStr
    dc.b $ff

CreditStr:
                  ;0123456789012345678901234567890123456789
    TEXT [petsci] "github.com/sakrac/BDoing   (Alta 4/2018)"
const CreditStrLen = *-CreditStr
    dc.b $ff


StartFileMenu:
{
    cli

    jsr ClearScreen
    ldx #<($400 + 12*40 + (40-FileMenuStartStrLen)/2)
    lda #>($400 + 12*40 + (40-FileMenuStartStrLen)/2)
    jsr SetDrawStringTrg
    ldx #<FileMenuStartStr
    lda #>FileMenuStartStr
    ldy #14
    jsr DrawString

    ldx #<($400 + 25*40 - CreditStrLen )
    lda #>($400 + 25*40 - CreditStrLen )
    jsr SetDrawStringTrg
    ldx #<CreditStr
    lda #>CreditStr
    ldy #4
    jsr DrawString

    lda #23
    sta $d018
    lda #9
    jsr CHROUT

    lda #8
    sta $d020
    jsr LoadDirectory
    lda #13
    sta $d020
    jsr ClearScreen

    sei

    ldx #<$400
    lda #>$400
    jsr SetDrawStringTrg
    ldx #<TitleText
    lda #>TitleText
    ldy #1
    jsr DrawString

    ldx #<FileMenuTitle
    lda #>FileMenuTitle
    jsr SetDrawStringTrg
    ldx #<FileMenuTitleStr
    lda #>FileMenuTitleStr
    ldy #1
    jsr DrawString

    lda #0
    sta CurrOption
    sta NumFiles

    ldx #<FileMenuDirectory
    lda #>FileMenuDirectory
    jsr SetDrawStringTrg

    ; make sure there is dummy file data in place if selecting new file
    lda #<FirstLoadedSound
    sta BankEndAddress
    lda #>FirstLoadedSound
    sta BankEndAddress+1
    lda #0
    sta LoadedSoundCount
    ldx #SoundFileIDLen-1
    {
        lda SoundFileID,x
        sta FileSound,x
        dex
        bpl !
    }

    lda #$53
    sta FilenameScratch
    lda #$3a
    sta FilenameScratch+1

    ldx #<DirFiles
    lda #>DirFiles
    jsr SkipString
    {
        jsr IncDrawStringSrc
        ldx #0
        jsr DrawStringSrc
        cmp #$ff
        beq %
        inc NumFiles
        ldy #14
        jsr DrawStringNext
        txa
        pha
        ldx #40
        jsr IncDrawStringDest
        pla
        tax
        jmp !
    }

    lda #1
    sta InputUpper

    lda #0
    jsr UpdateFileOption

    lda NumFiles
    sta NumOptions

    lda #14
    sta $d020

    {
        lda #$80
        {
            cmp $d012
            bne !
        }
        jsr UpdateKeyboard
        ldx #1
        jsr MenuUpDown

        {
            jsr HitEnter
            bne LoadCurrentOption
        }

        ; '=' for new
; 6 |   /  |   ^  |   =  |R-SHFT| HOME |   ;  |   *  |   £  |
        lda KeyboardBitsChange + 6
        and #$20
        beq !
    }

    lda #13
    sta $d020

    jsr NewFileName
    jsr ClearScreen
    lda #0
    sta NumOptions
    jmp NewSoundNameBank
}

LoadCurrentOption:
{
    lda #13
    sta $d020

    zpLocal .zpLine.w
    lda CurrOption
    clc
    adc #1
    jsr LineToOffset
    ora #4
    inx
    inx
    stx .zpLine
    sta .zpLine+1
    ldy #0
    {
        lda (.zpLine),y
        and #$7f
        cmp #$20
        beq %
        sta Filename,y
        iny
        cpy #16
        bcc !
    }
    tya
    pha
    lda #0
    {
        cpy #16
        bcs %
        sta Filename,y
        iny
        bne !
    }

    lda #0
    sta FileSound
    pla
    ldx .zpLine
    ldy .zpLine+1
    jsr LoadSoundFile
    bcs .notSoundFile ; file error

    ldx #SoundFileIDLen-1
    {
        lda SoundFileID,x
        cmp FileSound,x
        bne .notSoundFile
        dex
        bpl !
    }
    jmp SoundBank

.notSoundFile
    jmp StartFileMenu ; redo file load
}

MenuUpDown:
{
    {
        jsr KeyDown
        beq %
        ldy CurrOption
        iny
        cpy NumOptions
        beq %
        lda #1
        jsr UpdateFileOption
    }

    {
        jsr KeyUp
        beq %
        lda CurrOption
        beq %
        lda #-1
        jsr UpdateFileOption
    }
    rts
}

UpdateFileOption:
{
    pha
    clc
    lda #1
    adc CurrOption
    ldy #14
    jsr MarkFileMenuLine
    pla
    clc
    adc CurrOption
    sta CurrOption
    clc
    adc #1
    ldy #1
} ; fallthrough to MarkFileMenuLine
; a = line
; y = color
MarkFileMenuLine:
{
    zpLocal .zpLine.w
    pha
    jsr LineToOffset
    ora #$d8
    stx .zpLine
    sta .zpLine+1
    tya
    ldy #40
    {
        dey
        sta (.zpLine),y
        bne !
    }
    pla
    rts
}

; in: a = line #
; out: x / lo, a / hi
; y untouched
LineToOffset:
{
    zpLocal .zpLine
    sta .zpLine
    asl
    asl
    adc .zpLine ; x5, 0-120
    asl ; 0-240
    asl ; 0-480
    rol .zpLine
    asl ; 0-960
    rol .zpLine
    tax
    lda .zpLine
    and #3
    rts
}

NewFileName:
{
    ldx #<$400
    lda #>$400
    jsr SetDrawStringTrg
    ldx #<TitleText
    lda #>TitleText
    ldy #1
    jsr DrawString

    ldx #<FileMenuTitle
    lda #>FileMenuTitle
    jsr SetDrawStringTrg
    ldx #<NewFileMenuTitleStr
    lda #>NewFileMenuTitleStr
    ldy #5
    jsr DrawString

    lda #14
    sta $d020

    jsr InputNewOptionLine
    debugbreak

    lda #13
    sta $d020

    ldy #16
    lda #0
    {
        dey
        sta Filename,y
        bne !
    }
    ldy Cursor
    {
        dey
        bmi %
        jsr GetInputChar
        sta Filename,y
        jmp !
    }

    ; make sure filename ends with .snd
    ldx #0  ; x = len
    {
        lda Filename,x
        beq %
        inx
        cpx #16
        bcc !
    }
    ; find last '.'
    txa
    tay
    {
        dey
        bmi %
        lda Filename,y
        cmp #$2e ; '.'
        bne !
    }
    ; if y < 0 then no dot, otherwise last dot at y
    {
        tya
        bpl .hasDot
        txa
        tay
.hasDot
        {
            cpy #16-4
            bcc %
            ldy #16-4
        }
        ldx #0
        {
            lda .soundExt,x
            sta Filename,y
            iny
            inx
            cpx #4
            bcc !
        }
        {   ; terminate filename
            cpy #16
            bcs %
            lda #0
            sta Filename,y
        }
    }
    rts
.soundExt
    TEXT ".SND"
}



InputNewOptionLine:
{
    lda #0
    sta Cursor

    lda NumOptions
    jsr LineToOffset
    pha
    txa
    clc
    adc #40 + 2 ; 1 lines down, 2 chars right
    tax
    pla
    adc #4 ; text memory starts at $400
    ldy #1
    jsr SetInputScreen

    lda #1
    sta CurrOptionEnter
    {
        lda #$80
        {
            cmp $d012
            bne !
        }
        jsr UpdateKeyboard
        {
            lda #16
            jsr UpdateInputString
            bcc %
            rts
        }
        jmp !
    }
}

MemCpySetDest:
{
    stx MemCpyAddr+4
    sta MemCpyAddr+5
    sty MemCpyAddr+1
    rts
}

MemCpy:
{
    stx MemCpyAddr+2
    pha
    {
        tya
        beq %
        ldx #0
        {
            jsr .docopy
            dey
            bne !
        }
    }
    {
        pla
        beq %
        tax
.docopy
        {
            dex
MemCpyAddr:
const MemCpySrc = *+1
            lda $1234,x
const MemCpyTrg = *+1
            sta $1234,x
            txa
            bne !
        }
    }
    rts
}

; Filename is the current filename
; a = length (preserved)
ScratchFile:
{
    pha
    clc
    adc #2
    ldx #<FilenameScratch
    ldy #>FilenameScratch

    cli

    jsr SETNAM     ; call SETNAM
    {
        lda #1
        ldy #$15
        ldx $ba       ; last used device number
        bne %
        ldx #8      ; default to device 8
    }
    jsr SETLFS     ; call SETLFS

    jsr OPEN      ; call OPEN (open the directory)
    lda #1
    jsr CLOSE
    pla
    rts
}

SaveSoundFile:
{
    lda #13
    sta $d020
    jsr WriteBackSound
    ldx #0
    {
        lda Filename,x
        beq %
        inx
        cpx #16
        bcc !
    }
    txa
    jsr ScratchFile
    ldx #<Filename
    ldy #>Filename

    cli

    jsr SETNAM     ; call SETNAM
    lda #0
    ldx $ba       ; last used device number
    bne .skip
    ldx #8      ; default to device 8
.skip
    ldy #$00
    jsr SETLFS     ; call SETLFS

    lda #<FileSound
    sta $c1
    lda #>FileSound
    sta $c2

    ldx BankEndAddress
    ldy BankEndAddress+1
    lda #$c1

    jsr SAVE     ; call SAVE
    bcs .error    ; if carry set, a load error has happened

    sei
    lda #14
    sta $d020
    rts
.error
    ; accumulator contains BASIC error code
    lda #2
    sta $d020 ; show error as color?
    rts
}

SoundFileID:
    TEXT "BDOING"
const SoundFileIDLen = *-SoundFileID

; a = name len, x = name lo, y = name hi
LoadSoundFile:
{
    cli
    jsr SETNAM     ; call SETNAM
    lda #1
    ldx $ba       ; last used device number
    bne .skip
    ldx #8      ; default to device 8
.skip
    ldy #1      ; not $01 means: load to address stored in file
    jsr SETLFS     ; call SETLFS

    lda #$00      ; $00 means: load to memory (not verify)
    jsr LOADFILE     ; call LOAD
    sei
    lda $ae ; LOAD last written byte
    sta BankEndAddress
    lda $af
    sta BankEndAddress+1
    rts
;    bcs .error    ; if carry set, a load error has happened
;    rts
.error
    ; accumulator contains BASIC error code

    ; most likely errors:
    ; a = $05 (DEVICE NOT PRESENT)
    ; a = $04 (FILE NOT FOUND)
    ; a = $1D (LOAD ERROR)
    ; a = $00 (BREAK, RUN/STOP has been pressed during loading)

    ;... error handling ...
    rts
}

; assume all sounds are included at FileSound
{
    zpLocal .zpSnd.w
    zpLocal .zpDst.w
ExportSounds:
    lda #13
    sta $d020

    ldx #<FirstLoadedSound
    ldy #>FirstLoadedSound
    stx .zpSnd
    sty .zpSnd+1
    lda #0
    sta CurrentExportSound

    ldx #<ExportStart
    ldy #>ExportStart
    stx .zpDst
    sty .zpDst+1

    {
        lda .zpSnd
        sta ExportSoundNameSrc
        lda .zpSnd+1
        sta ExportSoundNameSrc+1

        ldy #0  ; extra linebreak between sounds
        jsr ExportLinebreak
        jsr AddExportLabel
        {
            lda ExportLabelSuffix,y
            sta (.zpDst),y
            iny
            cpy #ExportLabelSuffixLen
            bcc !
        }
        jsr ExportCatchUp
        clc
        lda .zpSnd
        adc #$20
        sta .zpSnd
        {
            bcc %
            inc .zpSnd+1
        }

        ldx #8
        lda #$31
        {
            dex
            sta CurrentExportLabelIndex,x
            bne !
        }

        lda #0
        sta ExportSoundEvent

        ; one line per event
        {
            {
                lda CurrentExportType
                cmp #2
                bne %
                jsr MakeNTSCEvent
                lda .zpSnd
                pha
                lda .zpSnd+1
                pha
                lda #<ExportNTSCEvent
                sta .zpSnd
                lda #>ExportNTSCEvent
                sta .zpSnd+1
            }

            ldx ExportSoundEvent
            lda ExportBytes
            sta ExportSoundEventsLo,x
            jsr ExportOneEvent
            php

            {
                lda CurrentExportType
                cmp #2
                bne %
                pla
                tax
                pla
                sta .zpSnd+1
                pla
                sta .zpSnd
                txa
                pha
            }

            clc
            lda .zpSnd
            adc #SoundInt.bytes
            sta .zpSnd
            lda .zpSnd+1
            adc #0
            sta .zpSnd+1
            inc ExportSoundEvent
            plp
            bcc !
        }
        ldy #0
        jsr ExportLinebreak
        inc CurrentExportSound
        lda CurrentExportSound
        cmp LoadedSoundCount
        bcs .done
        jmp !
.done   lda CurrentExportType
        beq %
        cmp #2
        beq %
        inc CurrentExportType
        ldx #<FirstLoadedSound
        ldy #>FirstLoadedSound
        stx .zpSnd
        sty .zpSnd+1
        lda #0
        sta CurrentExportSound
        jmp !
    }
    jmp ExportSaveFile

AddExportLabel:
    {
        ; add a label for the sound name
        {
const ExportSoundNameSrc = *+1
            lda $1234,y
;            lda (.zpSnd),y
            beq %
            {
                cmp #$1b ; check for lowercase screencodes
                bcs %
                ora #$60
            }
            sta (.zpDst),y
            iny
            cpy #$20
            bcc !
        }
        jmp ExportCatchUp
    }

ExportDCB:
{
    ldy #0
    sty ExportByteInLine
    {    ; "\n\tdc.b "
        lda ExportDataPrefix,y
        sta (.zpDst),y
        iny
        cpy #ExportDataPrefixLen
        bcc !
    }
    jmp ExportCatchUp
}

AddExportSymbol:
{
    lda CurrentExportLabelIndex,x
    inc CurrentExportLabelIndex,x
    sta (.zpDst),y
    iny
    lda ExpLblLo,x
    sta ExpLabelSuffix
    lda ExpLblHi,x
    sta ExpLabelSuffix+1
    ldx #0
    {
const ExpLabelSuffix = *+1
        lda $1234,x
        cmp #$ff
        beq %
        sta (.zpDst),y
        inx
        iny
        bne !
    }
    jmp ExportCatchUp
}

ExpLblLo:
    dc.b <ExpLbl_Freq
    dc.b <ExpLbl_Pulse
    dc.b <ExpLbl_AD
    dc.b <ExpLbl_SR
    dc.b <ExpLbl_Control
    dc.b <ExpLbl_FreqDelta
    dc.b <ExpLbl_PulseDelta
    dc.b <ExpLbl_Dur
ExpLblHi:
    dc.b >ExpLbl_Freq
    dc.b >ExpLbl_Pulse
    dc.b >ExpLbl_AD
    dc.b >ExpLbl_SR
    dc.b >ExpLbl_Control
    dc.b >ExpLbl_FreqDelta
    dc.b >ExpLbl_PulseDelta
    dc.b >ExpLbl_Dur
ExpLbl_Freq: TEXT "_FRQ:"
    dc.b $ff
ExpLbl_Pulse: TEXT "_PLS:"
    dc.b $ff
ExpLbl_AD: TEXT "_AD:"
    dc.b $ff
ExpLbl_SR: TEXT "_SR:"
    dc.b $ff
ExpLbl_Control: TEXT "_CTL:"
    dc.b $ff
ExpLbl_FreqDelta: TEXT "_FDT:"
    dc.b $ff
ExpLbl_PulseDelta: TEXT "_PDT:"
    dc.b $ff
ExpLbl_Dur: TEXT "_DUR:"
    dc.b $ff

ExportOneEvent:
{

    ldy #SoundInt.expLabel
    lda (.zpSnd),y
    sta ExportEventLabels
    {
        bpl %
        ldy #0
        jsr ExportLinebreak
        jsr AddExportLabel
        ldx #7
        jsr AddExportSymbol
    }
        
    jsr ExportDCB
    jsr ExportCatchUp

    ldy #SoundInt.frames
    lda (.zpSnd),y
    pha
    jsr ExportByte
    pla
    {
        bne % ; end of this sound!
        sec
        rts
    }

    ldy #SoundInt.setValue
    lda (.zpSnd),y
    pha
    and #$7f ; don't export loop bit
    jsr ExportNextByte ; bit mask
    pla

    lsr
    pha
    {
        bcc %
        {
            lda ExportEventLabels
            and #1
            beq %
            ldy #0
            jsr ExportLinebreak
            jsr AddExportLabel
            ldx #0
            jsr AddExportSymbol
            jsr ExportDCB
        }

        ldy #SoundInt.freq
        lda (.zpSnd),y
        jsr ExportNextByte
        ldy #SoundInt.freq+1
        lda (.zpSnd),y
        jsr ExportNextByte
    }
    pla
    lsr
    pha
    {
        bcc %
        {
            lda ExportEventLabels
            and #2
            beq %
            ldy #0
            jsr ExportLinebreak
            jsr AddExportLabel
            ldx #1
            jsr AddExportSymbol
            jsr ExportDCB
        }
        ldy #SoundInt.pulse
        lda (.zpSnd),y
        jsr ExportNextByte
        ldy #SoundInt.pulse+1
        lda (.zpSnd),y
        jsr ExportNextByte
    }
    pla
    lsr
    pha
    {
        bcc %
        {
            lda ExportEventLabels
            and #4
            beq %
            ldy #0
            jsr ExportLinebreak
            jsr AddExportLabel
            ldx #2
            jsr AddExportSymbol
            jsr ExportDCB
        }
        ldy #SoundInt.attackDecay
        lda (.zpSnd),y
        jsr ExportNextByte
    }
    pla
    lsr
    pha
    {
        bcc %
        {
            lda ExportEventLabels
            and #8
            beq %
            ldy #0
            jsr ExportLinebreak
            jsr AddExportLabel
            ldx #3
            jsr AddExportSymbol
            jsr ExportDCB
        }
        ldy #SoundInt.sustainRelease
        lda (.zpSnd),y
        jsr ExportNextByte
    }
    pla
    lsr
    pha
    {
        bcc %
        {
            lda ExportEventLabels
            and #16
            beq %
            ldy #0
            jsr ExportLinebreak
            jsr AddExportLabel
            ldx #4
            jsr AddExportSymbol
            jsr ExportDCB
        }
        ldy #SoundInt.control
        lda (.zpSnd),y
        jsr ExportNextByte
    }
    pla
    lsr
    pha
    {
        bcc %
        {
            lda ExportEventLabels
            and #32
            beq %
            ldy #0
            jsr ExportLinebreak
            jsr AddExportLabel
            ldx #5
            jsr AddExportSymbol
            jsr ExportDCB
        }
        ldy #SoundInt.deltaFreq
        lda (.zpSnd),y
        jsr ExportNextByte
        ldy #SoundInt.deltaFreq+1
        lda (.zpSnd),y
        jsr ExportNextByte
    }
    pla
    lsr
    pha
    {
        bcc %
        {
            lda ExportEventLabels
            and #64
            beq %
            ldy #0
            jsr ExportLinebreak
            jsr AddExportLabel
            ldx #6
            jsr AddExportSymbol
            jsr ExportDCB
        }
        ldy #SoundInt.deltaPulse
        lda (.zpSnd),y
        jsr ExportNextByte
        ldy #SoundInt.deltaPulse+1
        lda (.zpSnd),y
        jsr ExportNextByte
    }
    pla
    lsr
    {   ; LOOP POINT
        bcc %
        jsr ExportDCB
        jsr ExportCatchUp

        ldy #SoundInt.loop
        lda (.zpSnd),y
        tax
        lda ExportBytes
        sec
        sbc ExportSoundEventsLo,x
        eor #$ff
        clc
        adc #1
        jsr ExportByte
    }
    clc
    rts
}

ExportNextByte:
ExportByte:
{
    {
        ldx ExportByteInLine
        beq %
        pha
        lda #$2c ; ','
        ldy #0
        sta (.zpDst),y
        iny
        lda #$20 ; ' '
        sta (.zpDst),y
        iny
        jsr ExportCatchUp
        pla
    } ; fallthrough
    inc ExportByteInLine
    tax
    lda #$24
    ldy #0
    sta (.zpDst),y
    iny
    txa
    lsr
    lsr
    lsr
    lsr
    jsr ExportNibToChar
    sta (.zpDst),y
    iny
    txa
    jsr ExportNibToChar
    sta (.zpDst),y
    iny
    inc ExportBytes
    jmp ExportCatchUp
}

ExportNibToChar:
{
    and #$f
    {
        cmp #$a
        bcs %
        adc #$30 ; '0'
        rts
    }
    adc #$61-1-10 ; 'a' - carry - 10
    rts
}
ExportLinebreak:
    {
        lda #$0d
        sta (.zpDst),y
        iny
        lda #$0a
        sta (.zpDst),y
        iny
    } ; fallthrough
ExportCatchUp:
    {
        tya
        clc
        adc .zpDst
        sta .zpDst
        {
            bcc %
            inc .zpDst+1
        }
        ldy #0 ; reset relative
        rts
    }

MakeNTSCEvent:
    {
        ldy #SoundInt.bytes-1
        {
            lda (.zpSnd),y
            sta ExportNTSCEvent,y
            dey
            bpl !
        }
        ldx ExportNTSCEvent + SoundInt.frames
        lda #0
        jsr CalcNTSCFrames
        stx ExportNTSCEvent + SoundInt.frames

        ldx ExportNTSCEvent + SoundInt.freq
        lda ExportNTSCEvent + SoundInt.freq+1
        jsr CalcNTSCFreq
        stx ExportNTSCEvent + SoundInt.freq
        sta ExportNTSCEvent + SoundInt.freq+1
        
        ldx ExportNTSCEvent + SoundInt.deltaFreq
        lda ExportNTSCEvent + SoundInt.deltaFreq+1
        jsr CalcNTSCFreqSlide
        stx ExportNTSCEvent + SoundInt.deltaFreq
        sta ExportNTSCEvent + SoundInt.deltaFreq+1

        ldx ExportNTSCEvent + SoundInt.deltaPulse
        lda ExportNTSCEvent + SoundInt.deltaPulse+1
        jsr CalcNTSCPulseSlide
        stx ExportNTSCEvent + SoundInt.deltaPulse
        sta ExportNTSCEvent + SoundInt.deltaPulse+1
        rts
    }


ExportSaveFile:
    ldx #0
    {
        lda Filename,x
        beq %
        cmp #$2e,x
        beq %
        inx
        cpx #16
        bcc !
    }
    lda Filename,x
    pha
    lda #$2e
    sta Filename,x
    inx
    lda Filename,x
    pha
    lda #$53
    sta Filename,x
    inx
    txa
    pha

    jsr ScratchFile
    ldx #<Filename
    ldy #>Filename
    cli

    jsr SETNAM     ; call SETNAM
    lda #0
    ldx $ba       ; last used device number
    bne .skip2
    ldx #8      ; default to device 8
.skip2
    ldy #$00
    jsr SETLFS     ; call SETLFS

    lda #<ExportStart
    sta $c1
    lda #>ExportStart
    sta $c2

    ldx .zpDst
    ldy .zpDst+1
    lda #$c1

    jsr SAVE     ; call SAVE

    sei

    pla
    tax
    dex
    pla
    sta FilenameScratch,x
    dex
    pla
    sta FilenameScratch,x

    lda #14
    sta $d020

    rts
}

ExportDataPrefix:
    dc.b 13,10,9 ; linebreak, tab
    TEXT "dc.b "
ExportDataPrefixLen = *-ExportDataPrefix

ExportLabelSuffix:
    TEXT "_SND:"
ExportLabelSuffixLen = *-ExportLabelSuffix

; y lo / a hi sound address
; returns next sound address
; x unchanged
NextSoundStartAddr:
{
    zpLocal .zpTmp
    sta .zpTmp
    txa
    pha
    lda .zpTmp
    pha
    tya
    clc
    adc #SoundNameLen
    tay
    pla
    adc #0
    jsr GetEventCountAt
    sta .zpTmp
    pla
    tax
    lda .zpTmp
    rts
}

; a = sound index to work on
GetSoundStartAddr:
{
    sta CurrentSoundIndex
    ldx #0
    ldy #<FirstLoadedSound
    lda #>FirstLoadedSound
    {
        cpx CurrentSoundIndex
        beq %
        jsr NextSoundStartAddr
        inx
        jmp !
    }
    rts
}

; a = sound index to use
WorkSoundByIndex:
{
    jsr GetSoundStartAddr
    ; y = sound lo, a = sound hi
    sty CurrentSoundStart ; store the current starting point
    sta CurrentSoundStart+1

    pha
    tax
    tya
    pha
    clc
    adc #SoundNameLen
    tay
    txa
    adc #0
    jsr GetEventCountAt
    zpLocal .zpStart.w
    tax
    pla
    sta .zpStart
    pla
    sta .zpStart+1
    sec
    tya
    sbc .zpStart ; size lo
    pha
    txa
    sbc .zpStart+1 ; size hi
    pha
    ldx #<WorkStart
    lda #>WorkStart
    ldy .zpStart
    jsr MemCpySetDest
    pla
    tay
    pla
    ldx .zpStart+1
    sta CurrentSoundSize ; store the current sound size
    sty CurrentSoundSize+1
    jmp MemCpy
}

; src/trg already set
; 
MemCpyBwd:
{
    pha
    {
        tya
        beq %
        ldx #0
        {
            dec MemCpyBwdSrc+1
            dec MemCpyBwdTrg+1
            jsr MemCpyBwdLoop
            dey
            bne !
        }
    }
    {
        pla
        bne %
        rts
    }
    tax
    eor #$ff
    pha
    sec ; inverted sbc
    adc MemCpyBwdSrc
    sta MemCpyBwdSrc
    {
        bcs %
        dec MemCpyBwdSrc+1
    }
    pla
    sec
    adc MemCpyBwdTrg
    sta MemCpyBwdTrg
    {
        bcs %
        dec MemCpyBwdTrg+1
    }
} ; falltrough
MemCpyBwdLoop:
{
    {
        dex
const MemCpyBwdSrc = *+1
        lda $1234,x
const MemCpyBwdTrg = *+1
        sta $2345,x
        cpx #0
        bne !
    }
    rts
}

MemCpyFwd:
{
    pha
    ldx #0
    {
        tya
        beq %
        stx MemCpyFwdLeft
        {
            jsr .docopy
            dey
            bne !
        }
    }
    {
        pla
        beq %
        sta MemCpyFwdLeft
.docopy
        {
const MemCpyFwdSrc = *+1
            lda $1234,x
const MemCpyFwdTrg = *+1
            sta $1234,x
            inx
const MemCpyFwdLeft = *+1
            cpx #0
            bne !
            inc MemCpyFwdSrc+1
            inc MemCpyFwdTrg+1
        }
    }
    rts
}


; calculate how much space is after this sound in the bacnk
; return size in a/lo y/hi
WriteBackSoundSize:
{
    sec
    lda BankEndAddress
    sbc CurrentSoundStart
    pha
    lda BankEndAddress+1
    sbc CurrentSoundStart+1
    tay
    pla
    sec
    sbc CurrentSoundSize
    pha
    tya
    sbc CurrentSoundSize+1
    tay
    pla
    rts
}

WriteBackSound:
{
    ; get current size
    ; compare with prior size
    ; if equal, copy in
    ; if lesser contract
    ; if greater expand

    jsr GetEventCount
    pha
    sec ; size is end - WorkStart
    tya
    sbc #<WorkStart
    tay
    pla
    sbc #>WorkStart
    sty CurrentWorkSize
    sta CurrentWorkSize+1

    sec
    lda CurrentWorkSize
    sbc CurrentSoundSize
    tay
    lda CurrentWorkSize+1
    sbc CurrentSoundSize+1
    bcs .expand
.contract
    pha
    tya
    pha
    clc
    lda CurrentSoundStart
    adc CurrentSoundSize
    sta MemCpyFwdSrc
    lda CurrentSoundStart+1
    adc CurrentSoundSize+1
    sta MemCpyFwdSrc+1
    clc
    pla
    adc MemCpyFwdSrc
    sta MemCpyFwdTrg
    pla
    adc MemCpyFwdSrc+1
    sta MemCpyFwdTrg+1
    jsr WriteBackSoundSize
    jsr MemCpyFwd
    jmp .copy

.expand
    pha
    tya
    clc
    adc BankEndAddress
    sta MemCpyBwdTrg
    pla
    adc BankEndAddress+1
    sta MemCpyBwdTrg+1
    lda BankEndAddress
    sta MemCpyBwdSrc
    lda BankEndAddress+1
    sta MemCpyBwdSrc+1
    jsr WriteBackSoundSize
    jsr MemCpyBwd
.copy
    ldx CurrentSoundStart
    lda CurrentSoundStart+1
    ldy #<WorkStart
    jsr MemCpySetDest
    ldx #>WorkStart
    lda CurrentWorkSize
    ldy CurrentWorkSize+1
    jsr MemCpy

    ; finally update the bank size
    sec
    lda CurrentWorkSize ; new size
    pha
    sbc CurrentSoundSize ; old size
    tay
    lda CurrentWorkSize+1
    pha
    sbc CurrentSoundSize+1
    tax
    clc
    tya
    adc BankEndAddress
    sta BankEndAddress
    txa
    adc BankEndAddress+1
    sta BankEndAddress+1
    pla
    sta CurrentSoundSize+1
    pla
    sta CurrentSoundSize

    rts
}

FixSizeOnLoad:
{
    ldy #<FirstLoadedSound
    lda #>FirstLoadedSound
    sty BankEndAddress
    sta BankEndAddress+1
    ldx #0
    {
        cpx LoadedSoundCount
        bcs %
        lda BankEndAddress
        sta LoadedSoundsLo,x
        lda BankEndAddress+1
        sta LoadedSoundsHi,x
        txa
        pha
        clc
        lda BankEndAddress
        adc #SoundNameLen
        sta BankEndAddress
        {
            bcc %
            inc BankEndAddress+1
        }
        ldy BankEndAddress
        lda BankEndAddress+1
        jsr GetEventCountAt
        sty BankEndAddress
        sta BankEndAddress+1
        pla
        tax
        inx
        bne !
    }
    rts
}


; where on screen to put sound menu
const SoundBankMenuTop = $400+40
const SoundBankListScreen = SoundBankMenuTop + 2

const SoundBankMenuTitle = $400+23*40
const SoundBankReturnInfo = $400+24*40

                  ;0123456789012345678901234567890123456789
SoundBankMenuInfo1:
    TEXT [petsci] "Test:A-W     End Loop:1-3    Nav:Up/Down"
    dc.b $ff
SoundBankMenuInfo2:
    TEXT [petsci] "Edit:Return    New: =    File Menu: C=+*"
    dc.b $ff


NewSoundMenuTitleStr:
                  ;0123456789012345678901234567890123456789
    TEXT [petsci] "Enter a new sound name and press return"
    dc.b $ff

        ; a, b, c, d, e, f, ..
SoundBankSoundKeyIdxs:
    dc.b $01, $03, $02, $02, $01, $02, $03, $03, $04, $04, $04, $05, $04

SoundBankSoundKeyMasks:
    dc.b $04, $10, $10, $04, $40, $20, $03, $20, $02, $04, $20, $04, $10

        ; 1, 2, 3
ChannelSoundKeyIdxs:
    dc.b $07, $07, $01

ChannelSoundKeyMasks:
    dc.b $01, $08, $01


; show a list of all the sounds which can be tested or edited
SoundBank:
{
    lda #13
    sta $d020
    jsr FixSizeOnLoad

    lda #<SoundBankListScreen
    sta SoundBankNameWrite+1
    lda #>SoundBankListScreen
    sta SoundBankNameWrite+2

    lda #0
    sta CurrentSoundIndex

    jsr ClearScreen
    ldx #0
    {
        cpx LoadedSoundCount
        bcs %
        lda LoadedSoundsLo,x
        sta SoundBankNameRead+1
        lda LoadedSoundsHi,x
        sta SoundBankNameRead+2

        txa
        pha

        ; print name on screen
        ldx #0
        {
SoundBankNameRead:
            lda FirstLoadedSound,x
            beq %
SoundBankNameWrite:
            sta SoundBankListScreen,x
            inx
            bne !
        }
        clc
        lda SoundBankNameWrite+1
        adc #40
        sta SoundBankNameWrite+1   
        {
            bcc %
            inc SoundBankNameWrite+2
        }
        pla
        ldy #14
        jsr MarkFileMenuLine
        tax
        inx
        bne !
    }

    ; draw sound keys
    lda #<SoundBankMenuTop
    sta SoundKeyTrg
    sta SoundKeyCol
    lda #>SoundBankMenuTop
    sta SoundKeyTrg+1
    lda #>(SoundBankMenuTop + $d400)
    sta SoundKeyCol+1
    ldx #0
    {
        cpx LoadedSoundCount
        bcs %
        txa
        adc #$41
const SoundKeyTrg = *+1
        sta SoundBankMenuTop
        lda #10
const SoundKeyCol = *+1
        sta SoundBankMenuTop+$d400
        clc
        lda SoundKeyTrg
        adc #40
        sta SoundKeyTrg
        sta SoundKeyCol
        lda SoundKeyTrg+1
        adc #0
        sta SoundKeyTrg+1
        adc #$d4
        sta SoundKeyCol+1
        inx
        bne !
    }

    ldx #<$400
    lda #>$400
    jsr SetDrawStringTrg
    ldx #<TitleText
    lda #>TitleText
    ldy #1
    jsr DrawString

    ldx #<SoundBankMenuTitle
    lda #>SoundBankMenuTitle
    jsr SetDrawStringTrg
    ldx #<SoundBankMenuInfo1
    lda #>SoundBankMenuInfo1
    ldy #7
    jsr DrawString

    ldx #<SoundBankReturnInfo
    lda #>SoundBankReturnInfo
    jsr SetDrawStringTrg
    ldx #<SoundBankMenuInfo2
    lda #>SoundBankMenuInfo2
    ldy #13
    jsr DrawString

;    lda #14
;    sta $d020
    ; a = line (screen top + 2)
    ; y = color #

    lda #1
    sta InputUpper

    lda #0
    sta CurrOption
    jsr UpdateFileOption

    lda LoadedSoundCount
    sta NumOptions

    lda #14
    sta $d020
    {
        lda #$80
        {
            cmp $d012
            bne !
        }
        jsr UpdateKeyboard

        ldx #2
        {
            txa
            pha
            jsr UpdateBankSound
            pla
            tax
            {
                lda SoundPlaying,x
                beq %
                clc
                txa
                adc #$11
                pha
                {
                    ldy ChannelSoundKeyIdxs,x
                    lda KeyboardBitsChange,y
                    and ChannelSoundKeyMasks,x
                    beq %
                    lda #1
                    sta SoundPlayStopLoop,x
                }
                pla
            }
            clc
            adc #$20
            sta $400+37,x
            dex
            bpl !
        }

        ldy #0
        {
            cpy LoadedSoundCount
            bcs %
            ldx SoundBankSoundKeyIdxs,y
            lda KeyboardBitsChange,x
            {
                and SoundBankSoundKeyMasks,y
                beq %
                tya
                pha
                ldx #0
                {
                    lda SoundPlaying,x
                    beq %
                    inx
                    cpx #3
                    bcc !
                    bcs .full
                }
                lda LoadedSoundsLo,y
                clc
                adc #$20
                pha
                lda LoadedSoundsHi,y
                adc #0
                tay
                pla
                jsr TestSoundBank
                pla
                tay
            }
            iny
            bne !
        }
.full
        ldx #1
        jsr MenuUpDown

        {
            jsr HitEnter
            bne EditCurrOptionSound
        }

        {
            lda KeyboardBits+7
            and #$20
            beq %
            lda KeyboardBitsChange+6
            and #$02
            beq %
            jsr ClearScreen
            lda #13
            sta $d020
            jmp StartFileMenu
        }

        ; '=' for new
; 6 |   /  |   ^  |   =  |R-SHFT| HOME |   ;  |   *  |   £  |
        lda KeyboardBitsChange + 6
        and #$20
        bne NewSoundNameBank
        jmp !
    }
   jmp *
}

EditCurrOptionSound:
{
    lda #13
    sta $d020
    lda CurrOption
    jsr WorkSoundByIndex
    jmp ToolStart
}

NewSoundNameBank:
{
    lda #13
    sta $d020

    ldx #<$400
    lda #>$400
    jsr SetDrawStringTrg
    ldx #<TitleText
    lda #>TitleText
    ldy #1
    jsr DrawString

    ldx #<FileMenuTitle
    lda #>FileMenuTitle
    jsr SetDrawStringTrg
    ldx #<NewSoundMenuTitleStr
    lda #>NewSoundMenuTitleStr
    ldy #10
    jsr DrawString

    lda #0
    sta InputUpper

    lda #14
    sta $d020

    jsr InputNewOptionLine

    lda #13
    sta $d020

;    jsr NewSound

    inc LoadedSoundCount

    // set the destination for the new sound
    clc
    lda BankEndAddress
    sta NewSoundNameTrg
    sta CurrentSoundStart
    adc #SoundNameLen
    sta NewSoundTrg
    lda BankEndAddress+1
    sta NewSoundNameTrg+1
    sta CurrentSoundStart+1
    adc #0
    sta NewSoundTrg+1
    clc
    lda #<(SoundNameLen + DefaultSoundLen)
    sta CurrentSoundSize
    adc BankEndAddress
    sta BankEndAddress
    lda #>(SoundNameLen + DefaultSoundLen)
    sta CurrentSoundSize+1
    adc BankEndAddress+1
    sta BankEndAddress+1

    ldy #SoundNameLen-1
    {
        lda #0
        {
            cpy Cursor
            bcs %
            jsr GetInputChar
        }
const NewSoundNameTrg = *+1
        sta WorkStart,y
        dey
        bpl !
    }

    ldy #DefaultSoundLen-1
    {
        lda DefaultSound,y
const NewSoundTrg = *+1
        sta WorkSound,y
        dey
        bpl !
    }

    ldy LoadedSoundCount
    dey
    sty CurrOption
    jmp EditCurrOptionSound
}

; x = screen lo
; a = screen hi
ScreenToDecByte:
{
    stx ScreenToDecSrc
    sta ScreenToDecSrc+1
    ldy #0
    ldx #0
    {
const ScreenToDecSrc = *+1
        lda $0400,x
        {
            cmp #$20
            beq %
            sec
            sbc #$30
            bcc .exit
            cmp #10
            bcs .exit
            cpy #26
            bcs .overflow
            adc Mul10,y
            bcc .ok
.overflow   ldy #$ff
            sec
            rts
.ok         tay
        }
        inx
        cpx #3
        bcc !
    }
.exit
    tya
    clc
    rts
}

Mul10:
    rept 26 { dc.b rept*10 }

; http://codebase64.org/doku.php?id=base:how_to_calculate_your_own_sid_frequency_table
const PAL2NTSC_Freq = $f69e ; 65536 * 985248 / 1022727
const PAL2NTSC_FreqSlide = $cd84 ; 65536 * 985248 * 50 / ( 1022727 * 60 )
const PAL2NTSC_PulseSlide = $d555 ; 65536 * 50 / 60
const PAL2NTSC_Frames = $13333 ; 65536 * 60 / 50

CalcSetMulShift:
{
    stx MathShift
    sta MathShift+1
    lda #0
    sta MathShift+2
    sta MathShift+3
    rts
}

AbsXA:
{
    cmp #$80
    bcs %
    rts
} ; fallthrough
NegXA:
{
    pha
    txa
    sec
    eor #$ff
    adc #0
    tax
    pla
    adc #1
    rts
}

; in/out:
; x = freq lo
; a = freq hi
CalcNTSCFreq:
{
    jsr CalcSetMulShift
    lda #<PAL2NTSC_Freq
    sta MathProduct
    lda #>PAL2NTSC_Freq
    sta MathProduct+1
    jsr Mul16x16
    ldx MathNumber+2
    lda MathNumber+3
    rts
}

; in/out:
; x = freq lo
; a = freq hi
CalcNTSCFreqSlide:
{
    pha
    jsr AbsXA
    jsr CalcSetMulShift
    lda #<PAL2NTSC_FreqSlide
    sta MathProduct
    lda #>PAL2NTSC_FreqSlide
    sta MathProduct+1
    jsr Mul16x16
    ldx MathNumber+2
    lda MathNumber+3
    {
        pla
        bpl %
        jsr NegXA
    }
    rts
}

; in/out:
; x = freq lo
; a = freq hi
CalcNTSCPulseSlide:
{
    pha
    jsr AbsXA
    jsr CalcSetMulShift
    lda #<PAL2NTSC_PulseSlide
    sta MathProduct
    lda #>PAL2NTSC_PulseSlide
    sta MathProduct+1
    jsr Mul16x16
    ldx MathNumber+2
    lda MathNumber+3
    {
        pla
        bpl %
        jsr NegXA
    }
    rts
}

CalcNTSCFrames:
{
    stx MathProduct
    sta MathProduct+1
    ldx #<PAL2NTSC_Frames
    lda #>PAL2NTSC_Frames
    jsr CalcSetMulShift
    lda #PAL2NTSC_Frames>>16
    sta MathShift+2
    jsr Mul16x16
    ldx MathNumber+2
    lda MathNumber+3
    rts
}

