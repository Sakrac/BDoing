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

const zpSoundEvent = $fe ; 2 bytes temp zero page
const zpSoundChannel = $fd ; 1 byte temp zero page

XDEF BDoing_Init
XDEF BDoing_Play
XDEF BDoing_Update
XDEF BDoing_ExitLoop
XDEF BDoing_Playing
XDEF BDoing_AvailChannel

const SIDBase = $d400
enum SoundReg {
	freq = 0,
	pulse = 2,
	control = 4,
	attackDecay = 5,
	sustainRelease = 6
}
const SIDVol = 24
const SIDChannels = 3

enum BDoingStatus {
	off = 0,
	on = 1,
	deltaFreq = 2,
	deltaPulse = 4,
	loopExit = 8,
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

SECTION BSS, bss

BDoing_Channels:
	ds SIDChannels ; 1 status per channel
BDoing_Wait:
	ds SIDChannels ; 1 # frames to wait for next event
BDoing_Curr:
	ds.w SIDChannels ; 1 ptr to events / channel
BDoing_Freq:
	ds 2 * SIDChannels
BDoing_DeltaFreq:
	ds 2 * SIDChannels
BDoing_Pulse:
	ds 2 * SIDChannels
BDoing_DeltaPulse:
	ds 2 * SIDChannels

SECTION Code, code

BDoing_Init:
{
	lda #BDoingStatus.off
	ldx #SIDChannels
	{
		dex
		sta BDoing_Channels,x
		sta $d415,x
		bne !
	}

	lda #15
	sta SIDBase + SIDVol
	rts
}

; x = channel, will only set loop end if sound is playing
BDoing_ExitLoop:
{
	{
		lda BDoing_Channels,x
		beq %
		ora #BDoingStatus.loopExit
		sta BDoing_Channels,x
	}
	rts
}

; x = channel
; Z => not playing
BDoing_Playing:
{
	lda BDoing_Channels,x
	rts
}

BDoing_AvailChannel:
{
	ldx #2
	{
		lda BDoing_Channels,x
		beq %
		dex
		bpl !
	}
	txa
	rts
}

BDoing_x7:
	dc.b 0, 7, 14

; a channel, x lo/y hi
{
BDoing_Play:
	stx zpSoundEvent
	sty zpSoundEvent+1
	tax

	lda #BDoingStatus.on
	sta BDoing_Channels,x

; fallthrough to first event
; read from and increment zpSoundEvent
BDoing_Event:
	{
		stx zpSoundChannel

		ldy #0
.loop   lda (zpSoundEvent),y ; time
		{
			bne % ; exit if frames == 0
			ldy BDoing_x7,x
			lda #SoundCtrl.Disable
			sta SIDBase + SoundReg.control,y
			lda #BDoingStatus.off
			sta BDoing_Channels,x
			rts
		}
		{
			bpl % ; not a loop if frames > 0
			pha
			lda BDoing_Channels,x
			and #BDoingStatus.loopExit
			beq .rewind
			pla
			iny ; when loop should exit, get next byte and continue
			bne .loop
.rewind	 clc
			pla
			adc zpSoundEvent
			sta zpSoundEvent
			bcs .loop
			dec zpSoundEvent+1
			bne .loop
		}
		sta BDoing_Wait,x
		lda BDoing_x7,x
		tax ; SID channel offset
		iny
		lda (zpSoundEvent),y ; register mask
		{
			lsr
			bcc %
			pha
			iny
			lda (zpSoundEvent),y
			sta SIDBase + SoundReg.freq,x
			pha
			iny
			lda (zpSoundEvent),y
			sta SIDBase + SoundReg.freq+1,x
			ldx zpSoundChannel
			sta BDoing_Freq,x
			pla
			sta BDoing_Freq+SIDChannels,x
			lda BDoing_Channels,x
			and #$ff ^ BDoingStatus.deltaFreq
			sta BDoing_Channels,x
			lda BDoing_x7,x
			tax
			pla
		}
		{
			lsr
			bcc %
			pha
			iny
			lda (zpSoundEvent),y
			sta SIDBase + SoundReg.pulse,x
			pha
			iny
			lda (zpSoundEvent),y
			sta SIDBase + SoundReg.pulse+1,x
			ldx zpSoundChannel
			sta BDoing_Pulse,x
			pla
			sta BDoing_Pulse+SIDChannels,x
			lda BDoing_Channels,x
			and #$ff ^ BDoingStatus.deltaPulse
			sta BDoing_Channels,x
			lda BDoing_x7,x
			tax
			pla
		}
		{
			lsr
			bcc %
			pha
			iny
			lda (zpSoundEvent),y
			sta SIDBase + SoundReg.attackDecay,x
			pla
		}
		{
			lsr
			bcc %
			pha
			iny
			lda (zpSoundEvent),y
			sta SIDBase + SoundReg.sustainRelease,x
			pla
		}
		{
			lsr
			bcc %
			pha
			iny
			lda (zpSoundEvent),y
			sta SIDBase + SoundReg.control,x
			pla
		}
		ldx zpSoundChannel
		{
			lsr
			bcc %
			pha
			lda BDoing_Channels,x
			ora #BDoingStatus.deltaFreq
			sta BDoing_Channels,x
			iny
			lda (zpSoundEvent),y
			sta BDoing_DeltaFreq+SIDChannels,x
			iny
			lda (zpSoundEvent),y
			sta BDoing_DeltaFreq,x
			pla
		}
		{
			lsr
			bcc %
			pha
			lda BDoing_Channels,x
			ora #BDoingStatus.deltaPulse
			sta BDoing_Channels,x
			iny
			lda (zpSoundEvent),y
			sta BDoing_DeltaPulse+SIDChannels,x
			iny
			lda (zpSoundEvent),y
			sta BDoing_DeltaPulse,x
			pla
		}
		sec
		tya
		adc zpSoundEvent
		sta BDoing_Curr,x
		lda zpSoundEvent+1
		adc #0
		sta BDoing_Curr+SIDChannels,x
	}
	rts

BDoing_Update:
	{
		ldx #2
		{
			{
				lda BDoing_Channels,x
				beq %
				ldy BDoing_x7,x
				pha
				{
					and #BDoingStatus.deltaFreq
					beq %
					clc
					lda BDoing_Freq+SIDChannels,x
					adc BDoing_DeltaFreq+SIDChannels,x
					sta BDoing_Freq+SIDChannels,x
					sta SIDBase + SoundReg.freq,y
					lda BDoing_Freq,x
					adc BDoing_DeltaFreq,x
					sta BDoing_Freq,x
					sta SIDBase + SoundReg.freq+1,y
				}
				pla
				{
					and #BDoingStatus.deltaPulse
					beq %
					clc
					lda BDoing_Pulse+SIDChannels,x
					adc BDoing_DeltaPulse+SIDChannels,x
					sta BDoing_Pulse+SIDChannels,x
					sta SIDBase + SoundReg.pulse,y
					lda BDoing_Pulse,x
					adc BDoing_DeltaPulse,x
					sta BDoing_Pulse,x
					sta SIDBase + SoundReg.pulse+1,y
				}
				dec BDoing_Wait,x
				bne %
				txa
				pha
				lda BDoing_Curr,x
				sta zpSoundEvent
				lda BDoing_Curr+SIDChannels,x
				sta zpSoundEvent+1
				jsr BDoing_Event

				pla
				tax
			}
			dex
			bpl !
		}
		rts

		}
	}
}