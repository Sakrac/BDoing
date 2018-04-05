//
BDoing_SND:
	dc.b $03, $1f, $00, $0a, $f8, $07, $12, $c1, $21
	dc.b $03, $10, $20
	dc.b $0b, $7f, $00, $0c, $00, $08, $23, $89, $41, $00, $02, $a0, $ff
	dc.b $0b, $30, $40, $00, $02
	dc.b $00

Falling_SND:
	dc.b $19, $3d, $00, $20, $78, $8a, $11, $f0, $ff
	dc.b $02, $00
	dc.b $fe
	dc.b $19, $10, $10
	dc.b $00

Chopper_SND:
Chopper1_DUR:
	dc.b $07, $3d, $f5, $0b, $12, $83, $81, $c0, $ff
	dc.b $03, $10, $80
	dc.b $f4
	dc.b $05, $10, $80
	dc.b $00

Scanner_SND:
	dc.b $02, $1f, $00, $05, $00, $0f, $88, $8f, $41
	dc.b $32, $60, $ff, $ff, $c0, $ff
	dc.b $32, $60, $01, $00, $40, $00
	dc.b $f4
	dc.b $19, $10, $40
	dc.b $00

Whomp_SND:
	dc.b $08, $3f
Whomp1_FRQ:
	dc.b $fe, $09, $10, $00, $32, $83, $21, $20, $ff
	dc.b $0a, $10, $20
	dc.b $00
