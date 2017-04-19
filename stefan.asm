;-------------------------------
;            StefaN
;     (c) Tomasz Slanina
;       tomasz@slanina.pl
;    1k 4way breakout clone 
;-------------------------------

; Local variables

oldRandomVal	equ $ff8a
vset   			equ $ff8b
keyInput   		equ $ff8c

ballDx 			equ $ff8d
ballDy 			equ $ff8e
ballDelay		equ $ff8f
brickCnt		equ $ff90
frame			equ $ff91
delayEnd		equ $ff92
killedFlag		equ $ff93

; Hardware registers

rJOYP			equ $ff00
rDIV			equ $ff04
rIF				equ $ff0f
rNR10			equ $ff10
rNR50			equ $ff24
rNR51			equ $ff25
rNR52			equ $ff26
rLCDC			equ $ff40
rSTAT 			equ $ff41
rLY				equ $ff44
rDMA			equ $ff46
rVBK			equ $ff4f
rBCPS			equ $ff68
rBCPD			equ $ff69
rIE 			equ $ffff

WORKRAM			equ $c000
HiRAM 			equ $ff80

; Constants

MOVE_DELTA		equ 3

MIN_PLAYER_Y 	equ 16
MAX_PLAYER_Y 	equ 128+8
MIN_PLAYER_X 	equ 8
MAX_PLAYER_X 	equ 160-16

BALL_SX 		equ 4
BALL_SY 		equ 4

BALL_MINX 		equ 8+6
BALL_MAXX 		equ 160-4+8
BALL_MINY 		equ 1+6
BALL_MAXY 		equ 144-4+16

SPLUS 			equ 1
SMINUS 			equ -1

SECTION "start",HOME[0]
 ld a,32     ;keypad read
 ld hl,rJOYP
 ld de,WORKRAM+24
 ld [hl],a
 ld a,[hl]
 ld a,[hl]
 and $0f
 swap a
 ld b,a
 ld a,16
 ld [hl],a
 ld a,[hl]
 ld a,[hl]
 ld a,[hl]
 ld a,[hl]  ; Stable i/o data after ~4 reads
 and $0f
 or b
 cpl
 ld [keyInput],a
 bit 6,a  ;Up
 jr z,down
 ld a,[de] ;y
 cp MIN_PLAYER_Y
 jr c,skip_vertical
 sub MOVE_DELTA   ;4 = offset

set_y:       
 ld [de],a
 ld [WORKRAM+36],a
 add 8
 ld [WORKRAM+28],a
 ld [WORKRAM+40],a
 add 8
 ld [WORKRAM+32],a
 ld [WORKRAM+44],a
 jr skip_vertical

 nop
 nop

 push af
 xor a
 ld [vset],a
 jp HiRAM ;40
 nop
 jp lcdc

down:
 bit 7,a ;down
 jr z,skip_vertical
 ld a,[de]; y
 cp MAX_PLAYER_Y
 jr nc,skip_vertical
 add MOVE_DELTA
 jp set_y

skip_vertical:
 ld de,WORKRAM+1
 ld a,[keyInput]
 bit 5,a
 jr z,.skip_left
 ld a,[de]
 cp MIN_PLAYER_X
 ret c
 sub MOVE_DELTA
 jr set_x

.skip_left:
 bit 4,a
 ret z
 ld a,[de]
 cp MAX_PLAYER_X
 ret nc
 add MOVE_DELTA

set_x:       
 ld [de],a
 ld [WORKRAM+13],a
 add 8
 ld [WORKRAM+5],a
 ld [WORKRAM+17],a
 add 8
 ld [WORKRAM+9],a
 ld [WORKRAM+21],a
 ld a,[ballDelay]
 or a
 ret z
 ld a,[de]
 add 8
 ld [WORKRAM+49],a 	       
 ret

lcdc:
 push af
 push hl
 ld a,[rLY]  ; Current scanline 
 ld l,a
 ld h,$68  ;$d0/2
 add hl,hl
 ld a,128
 ld [rBCPS],a
 ld a,[hl+]
 ld [rBCPD],a
 ld a,[hl]
 ld [rBCPD],a
 pop hl
 pop af
 reti

startpos:
 db 16,9*8,4,64
 db 16,10*8,5,64
 db 16,11*8,4,64+32

 db 17*8+16,9*8,4,0
 db 17*8+16,10*8,5,0
 db 17*8+16,11*8,4,32

 db 16+7*8,8, 2,0
 db 16+8*8,8, 3,0
 db 16+9*8,8, 2,64

 db 16+7*8,8+19*8, 2,32
 db 16+8*8,8+19*8, 3,32
 db 16+9*8,8+19*8, 2,32+64

 db 16+16*8,8+9*8, 6,0

 db 255,255,16,0,31,0,255,61,255,3,0,64
 db 0,124,239,125,255,3,0,2,128,3,239,63

oamdma:
 ld a,$c0    ; DMA Shadow OAM (WORKRAM) -> OAM
 ld [rDMA],a
.wait:
 dec a
 jr nz,.wait  ; wait for DMA completion
 pop af
 reti

SECTION "boot",HOME[$100]
 nop
 jp main

SECTION "header",HOME[$134]
 db "STEFAN         ",$c0
 db 0,0,0,0,0,0,0,0,0,0,0,0

main:
 di
 ld a,$8b  ;sound init
 ld [rNR52],a
 ld a,$ff
 ld [rNR51],a
 ld a,$17
 ld [rNR50],a
      
 xor a
 ld [rLCDC],a ;LCD off
 ld sp,$cfff

 ld [rVBK],a  
 ld h,$80
 ld l,a
 ld de,brick

 ld c,16

.empty_copy:
 ld [hl+],a
 dec c
 jr nz,.empty_copy

 ld c,16*6 ; 6 tiles, 16 bytes each (8x8 2bpp)
.tiles_copy:
 ld a,[de]
 inc de
 ld [hl+],a
 dec c
 jr nz,.tiles_copy

 ld h,$98 ; BG tilemap address
 ld l,c ;c=0
 ld d,0
.loop_y:
 ld e,0	
.loop_x:       
 ld a,e
 cp 3
 jr c,.empty
 cp 17
 jr nc,.empty
 ld a,d
 cp 3
 jr c,.empty
 cp 15
 jr nc,.empty
 ld c,1
.inner_loop:			 
 ld a,[rDIV] 
 ld b,a
 ld a,[oldRandomVal]
 xor b
 ld [oldRandomVal],a
 cpl
 and $3
 cp 3
 jr z,.inner_loop
 ld b,a  ; random(?) palette 
 jr .put_tile

.empty:
 ld bc,0

.put_tile:			 
 xor a
 ld [rVBK],a
 ld [hl],c
 inc a
 ld [rVBK],a
 ld [hl],b
 inc hl

 inc e
 ld a,e
 cp 32
 jr c,.loop_x
 inc d
 ld a,d
 cp 18
 jr c,.loop_y

 ld hl,oamdma 
 ld de,HiRAM
 ld c,a
 inc c

.copy1:
 ld a,[hl+]
 ld [de],a
 inc de
 dec c
 jr nz,.copy1

 ld hl,WORKRAM ; shadow OAM clear
 ld a,-16
 ld c,a

.clearOAM:
 ld [hl+],a
 dec c
 jr nz,.clearOAM

 ld hl,startpos
 ld de,WORKRAM
 ld c,3*4*4+4

.setOAM:
 ld a,[hl+]
 ld [de],a
 inc de
 dec c
 jr nz,.setOAM

 ld de,rBCPS ; BG palette
 ld a,128
 ld [de],a
 inc de
 ld c,8*3

.pal:
 ld a,[hl+]
 ld [de],a
 dec c
 jr nz, .pal	
 inc de
 ld a,128+2
 ld [de],a
 inc de
 xor a
 ld [de],a
 ld [de],a

 cpl
 ld [de],a
 ld [de],a

 ld [ballDy],a
 xor 254 
 ld [ballDx],a
 ld de,$d000+144*2-2  ; color table generator
 ld hl,$d000
 ld c,72

.localloop:
 ld a,72-8
 ld [ballDelay],a
 sub c
 jr nc,.skipclear
 xor a

.skipclear:	
 srl a
 ld [hl+],a
 ld [de],a
 inc de
 ld a,255
 ld [hl+],a
 ld [de],a
 dec de
 dec de
 dec de
 dec c
 jr nz,.localloop

 ld a,128+16+2   ; LCD Enable + BG tiledata @8000-8FFF + Obj enable
 ld [rLCDC],a
 ld a,8   		; Mode 0 H-blan int enabled (shot on each scanline)
 ld [rSTAT],a   
 xor a
 ld [delayEnd],a
 ld [frame],a
	 
 ld [rIF],a  
 ld a,3			; VBL + HBL interrupts enable
 ld [rIE],a  

 ld a,12*14
 ld [brickCnt],a
  
 ei ; Enable interrupts

.mainloop: 
 ld a,[vset]
 or a
 jr nz,.mainloop
 inc a
 ld [vset],a

 ld a,[delayEnd]
 or a
 jr nz,.endWait

 ld a,[frame]
 xor 1
 ld [frame],a
 call z, moveball
 rst 0
 jr .mainloop

.endWait:
 dec a
 ld [delayEnd],a
 or a
 jr nz,.mainloop
 jp $100  ;restart

moveball:
 ld a,[ballDelay]
 or a
 jr z,.continue
 dec a
 ld [ballDelay],a
 ret

.continue:		
 xor a
 ld [rVBK],a
 ld [killedFlag],a

ld c,0 ;bounce
 
 ld a,[WORKRAM+48]
 add BALL_SY
 ld d,a
 ld a,[WORKRAM+49]
 add BALL_SX
 ld e,a  ;de = yx  of ball center
 ld a,[ballDx]
 add e
 ld b,a

 ;check borders
 cp BALL_MINX
 jr nc,.not_left

;check collision with paddle
.coll_chk:		
 ld a,[WORKRAM+24]
 cp d
 jp nc,.kill_me
 add 3*8
 cp d
 jp c,.kill_me

 ld a,[rDIV]
 bit 3,a
 jr z,.skip_set
 set 0,c

.skip_set:		
 set 1,c
 jr .h_done

.not_left:		
 cp BALL_MAXX
 jr nc,.coll_chk
 jr .brick_collide

.kill_me:
 push af
 ld a,1
 ld [killedFlag],a
 pop af
 jr .h_done

.brick_collide:	;brick coll
 ld a,b ;x
 sub 8
 srl a
 srl a
 srl a 
 ld b,a
 ld a,d  ;y
 sub 16
 and %11111000
 ld h,$26
 sla a
 rl h
 sla a
 rl h
 or b
 ld l,a

 ld a,[hl]
 or a
 jr z,.h_done
 set 1,c
 set 7,c
 push hl  

.h_done:  ;H done
 ld a,[ballDy]
 add d
 ld b,a

 cp BALL_MINY
 jr nc,.not_over
 ;paddle

.coll_chk_y:		
 ld a,[WORKRAM+1]
 cp e
 jp nc,.skip_chk_test
 add 3*8
 cp e
 jp c,.skip_chk_test
 xor a
 ld [killedFlag],a

 ld a,[rDIV]
 bit 4,a
 jr nz,.skip_fl_set
 set 1,c

.skip_fl_set:		
 set 0,c
 jr .v_done

.not_over:		
 cp BALL_MAXY
 jr nc,.coll_chk_y
 jr .checks_ok

.skip_chk_test:
 bit 1,c 
 jr nz, .v_done
 jp .ded

.checks_ok:	
 ld a,e ;x
 sub 8
 srl a
 srl a
 srl a ;/8
 ld e,a
 ld a,b  ;y
 sub 16
 and %11111000
 ld h,$26

 sla a
 rl h
 sla a
 rl h
 or e
 ld l,a

 ld a,[hl]
 or a
 jr z,.v_done
 set 0,c
 set 6,c
 push hl 

.v_done:		
 ld a,[killedFlag]
 or a
 jr nz, .ded

 ld a,c
 or a
 jr z,.skip_sfx

 ld hl,rNR10 ; play sfx
 ld a,$2d
 ld [hl+],a
 ld a,$80
 ld [hl+],a
 ld a,$f1
 ld [hl+],a
 ld a,$e1
 ld [hl+],a
 ld a,$8e
 ld [hl],a

.skip_sfx:		
 bit 6,c
 jr z,.skip_brick
 pop hl
 call check_brick

.skip_brick:		
 bit 7,c
 jr z,.skip_brick_2
 pop hl
 call check_brick

.skip_brick_2:
 bit 1,c
 jr z,.skip_x_toggle
 ld a,[ballDx]
 xor 254		; toggle ball x
 ld [ballDx],a

.skip_x_toggle:		
 ld a,[ballDx]
 ld e,a
 ld a,[WORKRAM+49]
 add e
 ld [WORKRAM+49],a
 bit 0,c
 jr z,.skip_y_toggle	
 ld a,[ballDy]
 xor 254		; toggle ball y
 ld [ballDy],a

.skip_y_toggle:
 ld a,[ballDy]
 ld e,a
 ld a,[WORKRAM+48]
 add e
 ld [WORKRAM+48],a
 ret

.ded:		
 bit 7,c
 jr z,.skip_hl_pop
 pop hl

.skip_hl_pop:
 bit 6,c
 jr z,skip_hl_2nd_pop
 pop hl
skip_hl_2nd_pop:
 ld a,100
 ld [delayEnd],a
ret

check_brick:
 ld a,1
 ld [rVBK],a  ; atributes bg map
 ld a,[hl]
 or a
 jr nz,.decrease
 xor a
 ld [rVBK],a
 ld [hl],a
 ld a,[brickCnt]
 dec a
 ld [brickCnt],a
 or a
 jp z, skip_hl_2nd_pop
 ret
 
.decrease:  ;G->B->R->remove
 dec a
 ld [hl],a
 ret	

brick:
 db %11111111, %00000000
 db %10000001, %01111111
 db %10000001, %01111111
 db %10000001, %01111111
 db %10000001, %01111111
 db %10000001, %01111111
 db %10000001, %01111111
 db %11111111, %01111111

 db %01111000, %00000000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000

 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000
 db %01001000, %00110000

 db %00000000, %00000000
 db %00000000, %00000000
 db %00000000, %00000000
 db %11111111, %00000000
 db %10000000, %01111111
 db %10000000, %01111111
 db %11111111, %00000000
 db %00000000, %00000000

 db %00000000, %00000000
 db %00000000, %00000000
 db %00000000, %00000000
 db %11111111, %00000000
 db %00000000, %11111111
 db %00000000, %11111111
 db %11111111, %00000000
 db %00000000, %00000000

 db %00000000, %00000000
 db %00000000, %00000000
 db %00111100, %00000000
 db %00100100, %00011000
 db %00100100, %00011000
 db %00111100, %00000000
 db %00000000, %00000000
 db %00000000, %00000000

