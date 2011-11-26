; VGM (SN76489) player for the SPC-700
; Extended version used in "The 700 Club" musicdisk
; /Mic, 2010
; 
; Assemble with wla-dx


.MEMORYMAP                     
  SLOTSIZE $10000             
  DEFAULTSLOT 0                
  SLOT 0 $0                
.ENDME         

.ROMBANKSIZE $10000              
.ROMBANKS 1    


.INCLUDE "dsp.inc"

.DEFINE TONE_GAIN 100
.DEFINE NOISE_GAIN 50


; DP variables
.DEFINE VGM_PTR 	$10
.DEFINE TONE0_LATCH $12
.DEFINE TONE1_LATCH $14
.DEFINE TONE2_LATCH $16
.DEFINE NOISE_LATCH $18
.DEFINE VOL0_LATCH 	$1A
.DEFINE VOL1_LATCH 	$1C
.DEFINE VOL2_LATCH 	$1E
.DEFINE VOL3_LATCH 	$20
.DEFINE LATCHED_REG $22
.DEFINE TEMP 		$23
.DEFINE TEMP2 		$24
.DEFINE REG_BIT 	$25
.DEFINE FREQ_PTR 	$26
.DEFINE DELAY 		$28
.DEFINE BLOCK_SIZE	$30
.DEFINE FLAGS		$32
.DEFINE NUM_FLAGS	$33
.DEFINE PVAL		$34
.DEFINE SAMPLE		$36
.DEFINE MVOL		$38
.DEFINE LAST_BYTE	$39
.DEFINE PLAYING		$3A
.DEFINE OLDNGAIN	$3B
.DEFINE SENDLOOPS	$3C
.DEFINE CHN0TOGGLE	$40
.DEFINE CHN1TOGGLE	$41
.DEFINE CHN2TOGGLE	$42
.DEFINE CHN3TOGGLE	$43
.DEFINE USECHO		$44
.DEFINE NSAMPLES_LATE	$45


; Commands sent by the S-CPU
.DEFINE CMD_PLAY		$21
.DEFINE CMD_PAUSE		$22
.DEFINE	CMD_STOP		$23
.DEFINE CMD_SEND_LOOP_MSGS	$24
.DEFINE CMD_RESTART_SONG	$25
.DEFINE	CMD_SET_MVOL 		$30
.DEFINE CMD_TOGGLE_CHN		$40
.DEFINE CMD_TOGGLE_ECHO		$50


.BANK 0
.ORGA 0
nop

.ORGA $0100

; Pause/unpause playback
pause:
	cmp		PLAYING,#0
	bne		+
	; We were in a paused state; key on all channels
	mov		SPC_DSP_ADDR,#DSP_KOF
	mov		SPC_DSP_DATA,#$00
	mov		PLAYING,#1
	nop
	nop
	nop	
	mov		SPC_DSP_ADDR,#DSP_KON
	mov		SPC_DSP_DATA,#$F
	ret
+:
	; We were in a playing state; key off all channels
	mov		SPC_DSP_ADDR,#DSP_KOF
	mov		SPC_DSP_DATA,#$FF
	mov		PLAYING,#0
	nop
	nop
	nop	
	mov		SPC_DSP_ADDR,#DSP_KON
	mov		SPC_DSP_DATA,#$0
	ret
	
	
prepare:
	mov		SPC_DSP_ADDR,#DSP_KOF
	mov		SPC_DSP_DATA,#$00

	call	!set_coefs
	
	mov		SPC_DSP_ADDR,#DSP_SRCN3
	mov		SPC_DSP_DATA,#1
	
	; No frequency modulation	
	mov		SPC_DSP_ADDR,#DSP_PMON
	mov		SPC_DSP_DATA,#0

	; Sample pointers are located at $0200
	mov		SPC_DSP_ADDR,#DSP_DIR
	mov		SPC_DSP_DATA,#2
		
	; Enable noise for channel 3	
	mov		SPC_DSP_ADDR,#DSP_NON
	mov		SPC_DSP_DATA,#8
	
	; Key on channels 0-3	
	mov		SPC_DSP_ADDR,#DSP_KON
	mov		SPC_DSP_DATA,#$F
	
	mov		TONE0_LATCH,#0
	mov		TONE1_LATCH,#0
	mov		TONE2_LATCH,#0
	mov		NOISE_LATCH,#0
	mov		VOL0_LATCH,#0
	mov		VOL1_LATCH,#0
	mov		VOL2_LATCH,#0
	mov		VOL3_LATCH,#0
	mov		LATCHED_REG,#0
	mov		NUM_FLAGS,#0
	
	mov		FREQ_PTR,#0

	; The VGM file starts with the standard 64-byte VGM header. Immediately
	; following that is a data block containing containing wait periods for
	; compressed long waits (0x9n) that have been generated by the packer.
	; The data block is 32 bytes, plus the 7-byte data block header, for
	; a total of 39 bytes.
	mov		VGM_PTR,#<(vgm_file+64+0)
	mov		VGM_PTR+1,#>(vgm_file+64+0)
	
	mov		PLAYING,#1
	ret


; Store the current volumes in ports 2 and 3 (read by the S-CPU)
update_vol:
	mov		a,VOL1_LATCH
	xcn		a
	mov		TEMP,a
	mov		a,VOL0_LATCH
	or		a,TEMP
	mov		SPC_PORT2,a
	
	mov		a,VOL3_LATCH
	xcn		a
	mov		TEMP,a
	mov		a,VOL2_LATCH
	or		a,TEMP
	mov		SPC_PORT3,a
	ret


; Restart from the song's loop point	
loop_song:
	cmp		SENDLOOPS,#0
	beq		+
	mov		a,LAST_BYTE
	clrc
	adc		a,#1
	mov		SPC_PORT0,a
+:
	mov		a,#<(vgm_file+28)
	mov		y,#>(vgm_file+28)
	movw	VGM_PTR,ya
	mov		a,!vgm_file+28
	mov		y,!vgm_file+29
	addw	ya,VGM_PTR
	movw	VGM_PTR,ya			; VGM_PTR = &vgm_file[0x1C] + vgm_file[0x1C];  // The word at 0x1C holds the loop offset
	mov		NUM_FLAGS,#0		; Reset the decompression flags
	jmp		!play	


.ORGA $0200

; Sample pointers
.DW sample0,sample0, sample1,sample1, sample2,sample2, sample3,sample3, sample4,sample4

sample0:
; 50% duty square wave sample. Taken from Memblers' nsf player.
.DB $b3,$88,$88,$88,$88,$77,$77,$77,$77

sample1:
; 12.5% duty cycle square wave. Used for "perodic noise"
.DB $b3, $88,$77,$77,$77,$77,$77,$77,$77

; 12.5% (approx) duty cycle square wave at 1/4 frequency
sample2: 
.DB $b2,$88,$88,$88,$87,$77,$77,$77,$77,$b2,$77,$77,$77,$77,$77,$77,$77,$77,$b2,$77,$77,$77,$77,$77,$77,$77,$77,$b3,$77,$77,$77,$77,$77,$77,$77,$77

; 50% duty cycle square wave at 1/4 frequency
sample3:
.DB $b2,$88,$88,$88,$88,$88,$88,$88,$88,$b2,$88,$88,$88,$88,$88,$88,$88,$88,$b2,$77,$77,$77,$77,$77,$77,$77,$77,$b3,$77,$77,$77,$77,$77,$77,$77,$77

; 12.5% duty cycle square wave at 1/8 frequency
sample4: 
.DB $b2,$88,$88,$88,$88,$88,$88,$88,$77,$b2,$77,$77,$77,$77,$77,$77,$77,$77,$b2,$77,$77,$77,$77,$77,$77,$77,$77,$b2,$77,$77,$77,$77,$77,$77,$77,$77
.DB $b2,$77,$77,$77,$77,$77,$77,$77,$77,$b2,$77,$77,$77,$77,$77,$77,$77,$77,$b2,$77,$77,$77,$77,$77,$77,$77,$77,$b3,$77,$77,$77,$77,$77,$77,$77,$77


set_coefs:
	mov		SPC_DSP_ADDR,#DSP_COEF0
	mov		SPC_DSP_DATA,#127
	mov		SPC_DSP_ADDR,#DSP_COEF1
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_COEF2
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_COEF3
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_COEF4
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_COEF5
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_COEF6
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_COEF7
	mov		SPC_DSP_DATA,#0
	ret	
	

.ORGA $0300

start:
	clrp
	mov		x,#$F0
	mov 		sp,x
	
	mov		USECHO,#$20
	
	mov		SPC_DSP_ADDR,#DSP_EDL
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_FLG
	mov		SPC_DSP_DATA,#$20		; Disable echo
	;mov		SPC_DSP_ADDR,#DSP_EON
	;mov		SPC_DSP_DATA,#0

	mov		MVOL,#100
	
	mov		SENDLOOPS,#0
	
	mov		CHN0TOGGLE,#255
	mov		CHN1TOGGLE,#255
	mov		CHN2TOGGLE,#255
	mov		CHN3TOGGLE,#255

  mov NSAMPLES_LATE,#0
  mov NSAMPLES_LATE+1,#0
  
	mov		LAST_BYTE,#$CD
	
	call	!stop

	mov		SPC_PORT0,LAST_BYTE

play:
	; Has a new command arrived from the S-CPU?
	mov		a,LAST_BYTE
	cmp		a,SPC_PORT0
	bne		+
	jmp		!no_new_command			; Nope
+:
	mov		a,SPC_PORT1
	mov		LAST_BYTE,SPC_PORT0
	cmp		a,#CMD_PLAY				; Was it a Play command?
	bne		+
	call	!prepare
	;mov		SPC_PORT0,LAST_BYTE		; Echo back to the S-CPU
	bra		processed_command ;no_new_command
+:
	cmp		a,#CMD_PAUSE			; Was it a Pause command?
	bne		+
	call	!pause
	;mov		SPC_PORT0,LAST_BYTE
	bra		processed_command ;no_new_command
+:
	cmp		a,#CMD_TOGGLE_ECHO
	bne		+
	eor		USECHO,#$20
	call	!stop
	call	!prepare
	;mov		SPC_PORT0,LAST_BYTE		
	bra		processed_command ;no_new_command
+:	
	cmp		a,#CMD_STOP				; Was it a Stop command?
	bne		+	
	call	!stop
	jmp		!$FFC0
+:
	cmp		a,#CMD_SEND_LOOP_MSGS	; Was it a Send Loop Messages command?
	bne		+
	mov		a,SENDLOOPS
	eor		a,#1
	mov		SENDLOOPS,a
	;mov		SPC_PORT0,LAST_BYTE		
	bra		processed_command ;no_new_command
+:
	mov		TEMP,a
	and		a,#$F0
	cmp		a,#CMD_SET_MVOL			; Was it a Set Master Volume command?
	bne		+
	mov		a,TEMP
	and		a,#$F
	asl		a
	asl		a
	asl		a
	mov		MVOL,a					; MVOL = (command & 0xF) * 8; // Gives a range of 0-120
	mov		SPC_DSP_ADDR,#DSP_MVOLL
	mov		SPC_DSP_DATA,MVOL
	mov		SPC_DSP_ADDR,#DSP_MVOLR
	mov		SPC_DSP_DATA,MVOL	
	;mov		SPC_PORT0,LAST_BYTE
	bra		processed_command ;no_new_command
+:	
	cmp		a,#CMD_TOGGLE_CHN		; Was it a Toggle Channel command?
	bne		+
	and		TEMP,#$F
	mov		a,TEMP
	xcn		a
	or		a,#DSP_GAIN0
	mov		TEMP2,a
	cmp		a,#DSP_GAIN3
	beq		toggle_noise
	mov		x,TEMP
	mov		a,CHN0TOGGLE+x
	eor		a,#255
	mov		CHN0TOGGLE+x,a
	and		a,#TONE_GAIN			; CHNxTOGGLE ^= 0xFF; DSP_GAINx = TONE_GAIN & CHNxTOGGLE;
	mov		SPC_DSP_ADDR,TEMP2
	mov		SPC_DSP_DATA,a
	;mov		SPC_PORT0,LAST_BYTE
	bra		processed_command ;+
toggle_noise:						; Channel 3 (noise) has its own gain, which is why it's handled separately
	eor		CHN3TOGGLE,#255
	mov		a,CHN3TOGGLE
	and		a,OLDNGAIN
	mov		SPC_DSP_ADDR,#DSP_GAIN3
	mov		SPC_DSP_DATA,a
processed_command:
	mov		SPC_PORT0,LAST_BYTE
+:
; There are no new commands from the S-CPU. Are we in Playing or Paused/Stopped state?
no_new_command:
	cmp		PLAYING,#0
	bne		+
	jmp		!play
+:	
	mov		x,#0

	; Perform decompression..
	
	mov		a,NUM_FLAGS		; any flags left?
	bne		+
	mov		NUM_FLAGS,#8
	mov		a,[VGM_PTR+x]	; load a new flags byte
	mov		FLAGS,a
	incw		VGM_PTR
+:
	dec		NUM_FLAGS
	ror		FLAGS			; put the next flag in C
	bcc		+
	call		!psg_param		; the flag was set; this is a PSG write command
	jmp		!play
	
+:
	mov		a,[VGM_PTR+x]	; the was flag clear; this is not a PSG write command
	incw		VGM_PTR

	mov		TEMP,a			; save the command byte
	and		a,#$F0
	cmp		a,#$70			; first check if it's a short wait command since we want the lowest latency in processing them
	beq		short_wait
	cmp		a,#$90
	beq		compressed_long_wait
	
	mov		a,TEMP	
	cmp		a,#$4E			; $4E is used a a NOP command to pad compression runs when needed
	bne		+
	jmp		!play
+:
	cmp		a,#$66			; loop
	bne		+
	jmp		!loop_song
+:
	cmp		a,#$4F			; set gamegear stereo parameter
	beq		gg_stereo_param
	cmp		a,#$62			; wait one ntsc frame (1/60 s)
	beq		wait_frame_ntsc
	cmp		a,#$63			; wait one pal frame (1/50 s)
	beq		wait_frame_pal
	cmp		a,#$61			; wait xxyy samples
	beq		long_wait
	cmp		a,#$67			; data block
	bne		+
	mov		x,#3
	mov		a,[VGM_PTR+x]
	mov		y,a
	dec		x
	mov		a,[VGM_PTR+x]
	clrc
	adc		a,#4
	addw	ya,VGM_PTR
	movw	VGM_PTR,ya
+:

	; All other commands are unhandled and assumed to be 3 bytes long
	incw	VGM_PTR
	incw	VGM_PTR
	jmp		!play


; Wait n/44100 s  (n = [1..16])
; TODO: Handle this more exactly (cycle-timed loops?)
short_wait:
	and		TEMP,#$F
	mov		x,TEMP
  inc x
short_wait_2:
  and a,!short_wait_timer_values+x ;5
  and a,!short_wait_timer_values+x ;5
  and a,!short_wait_timer_values+x ;5
  nop ; 2
  dec x  ;2 
  bne shor_wait_2  ;4/2
  jmp !play

;	mov		a,!short_wait_timer_values+x
;	mov		SPC_TIMER2,a
;	mov		SPC_CTRL,#$84		; enable timer 2
;-:
;	mov		a,SPC_COUNTER2
;	beq		-
;	mov 	SPC_CTRL,#$80		; disable timers
	jmp		!play


; TODO: Handle GG stereo settings
gg_stereo_param:
	incw	VGM_PTR
	jmp		!play


; Wait 1/60 s
wait_frame_ntsc:
  mov a,#133
  setc
  sbc a,NSAMPLES_LATE
	mov		SPC_TIMER1,a  ;#133		; 133 = floor(8000/60)
	mov		SPC_CTRL,#$02		; enable timer 1
wait_frame_2:
	call	!update_vol	
-: 
	mov		a,SPC_COUNTER1
	beq		-
	mov		SPC_CTRL,#$00		; disable timers
  mov NSAMPLES_LATE,#0
	jmp		!play


; The VGM packer converts some long waits (0x61 nn nn) to a short form 0x9m, where m
; is an index into a 32-byte table containing the corresponding "nn nn" pairs.
compressed_long_wait:
	mov		a,TEMP
	and		a,#$0F
	asl		a
	mov		x,a
	mov		a,!vgm_file+71+x	; the table starts at offset 71 in the packed VGM file
	mov		DELAY,a
	mov		a,!vgm_file+72+x
	mov		DELAY+1,a
	bra		long_wait2
	

; Wait 1/50 s
wait_frame_pal:
  mov a,#160
  setc
  sbc a,NSAMPLES_LATE
	mov		SPC_TIMER0,a  ;#160		; 160 = 8000 / 50
	mov		SPC_CTRL,#$81		; enable timer 0
	bra		wait_frame_2
;	call	!update_vol	
;-:
;	mov		a,SPC_COUNTER0
;	beq		-
;	mov		SPC_CTRL,#$80		; disable timers
;	jmp		!play
	

	
; TODO: Handle this more exactly. Currently relies on short_wait which already is pretty inexact.
long_wait:
 inc NSAMPLES_LATE
	mov		a,[VGM_PTR+x]
	mov		DELAY,a
	incw		VGM_PTR
	mov		a,[VGM_PTR+x]
	mov		DELAY+1,a
	incw		VGM_PTR
	call		!update_vol
long_wait2:
  movw ya,DELAY
  subw ya,NSAMPLES_LATE
  bmi long_wait_done
  movw DELAY.ya
	mov		TEMP,#$10
	mov		TEMP2,#0
long_wait_loop:
	movw		ya,DELAY
	cmpw		ya,TEMP
	bcs		+
	and		a,#$0F
	beq		long_wait_done
	dec		a
	mov		x,a
	bra		short_wait_2
+:
	subw		ya,TEMP
	movw		DELAY,ya
	mov		x,#$0F
	mov		a,!short_wait_timer_values+x
	mov		SPC_TIMER2,a
	mov		SPC_CTRL,#$84		; enable timer 2
-:
	mov		a,SPC_COUNTER2
	beq		-
	mov 		SPC_CTRL,#$80		; disable timers
	bra		long_wait_loop
long_wait_done:
  mov NSAMPLES_LATE,#0
	jmp		!play
	


; A value is being written to the PSG	
psg_param:
	mov		a,[VGM_PTR+x]		; read the parameter byte
	incw		VGM_PTR
	mov		TEMP,a
	bbs		TEMP .7,latch_data
	mov		a,LATCHED_REG
	cmp		a,#6
	bcs		+
	; Set high 6 bits of tone register
	mov		x,a
	mov		a,TEMP
	xcn		a
	and		a,#$F0
	mov		TEMP2,a
	mov		a,TONE0_LATCH+x
	and		a,#$F				; save bits 0-3
	or		a,TEMP2				; replace bits 4-7 of the tone period with bits 0-3 of the parameter byte
	mov		TONE0_LATCH+x,a
	inc		x
	mov		a,TEMP
	xcn		a
	and		a,#3
	mov		TONE0_LATCH+x,a		; set bits 8-9 of the tone period to bits 4-5 of the parameter byte
	jmp		!tone_reg_updated	; the tone register has been updated, so we should update the channels frequency on the S-DSP
+:
	mov		x,a
	mov		a,TEMP
	and		a,#$F
	mov		TONE0_LATCH+x,a
check_vol_noise:
	bbs		LATCHED_REG .3,volume_reg_updated
	jmp		!noise_reg_updated
latch_data:
	mov 	a,TEMP
	xcn		a
	and		a,#$7
	mov		TEMP2,a
	lsr		a
	and		TEMP2,#1
	asl		TEMP2
	asl		TEMP2
	or		a,TEMP2
	asl		a
	mov		LATCHED_REG,a
	mov		x,a
	and		TEMP,#$F
	mov		a,TONE0_LATCH+x
	and		a,#$F0
	or		a,TEMP
	mov		TONE0_LATCH+x,a
	cmp		LATCHED_REG,#6
	bcs		check_vol_noise
	bra		tone_reg_updated


volume_reg_updated:
  clrc
  adc NSAMPLES_LATE,#3
	mov		x,LATCHED_REG
	mov		a,TONE0_LATCH+x
	mov 		x,a
	mov 		a,!tone_vol+x
	mov		TEMP,a
	mov		a,LATCHED_REG
	lsr		a
	and		a,#3
	xcn		a					
	; A will now contain $00, $10, $20 or $30 - i.e. DSP_VOL0L, DSP_VOL1L, DSP_VOL2L or DSP_VOL3L
	mov		SPC_DSP_ADDR,a	
	mov		SPC_DSP_DATA,TEMP	; set left volume
	inc		SPC_DSP_ADDR		; move to the next register (VOLxR)
	mov		SPC_DSP_DATA,TEMP	; set right volume
	ret
	


; TODO: Handle constant output (psgPeriod <= 1)
tone_reg_updated:
  clrc
  adc NSAMPLES_LATE,#4
	mov		SAMPLE,#0
	mov		a,LATCHED_REG
	lsr		a
	and		a,#3
	clrc
	xcn		a
	adc		a,#DSP_P0L
	mov		TEMP,a				; TEMP = DSP_P0L, DSP_P1L or DSP_P2L
	mov		x,LATCHED_REG
	mov		a,TONE0_LATCH+x
	asl		a
	mov		y,a					; Y = psgPeriodLo << 1
	mov		a,TONE0_LATCH+1+x
	rol		a					; A = (psgPeriodHi << 1) | ((psgPeriodLo & 0x80) >> 7)
	and		a,#7				; the frequency table is $800 bytes long
	clrc
	adc		a,#8				; ..and it starts at $700 
	mov		FREQ_PTR+1,a
	mov		a,[FREQ_PTR]+y		; load low byte of S-DSP period
	mov		PVAL,a
	inc		y
	mov		a,[FREQ_PTR]+y		; load high byte of S-DSP period
	mov		PVAL+1,a
	; Bit 15 of PVAL is used as a flag. If it's set then a sample 4x as wide should be used.
	; P has already been quadrupled in the table for these values.
	bpl		+
	and		PVAL+1,#$3F
	mov		SAMPLE,#3
+:
	mov		SPC_DSP_ADDR,TEMP
	mov		SPC_DSP_DATA,PVAL		; write to DSP_PxL
	inc		SPC_DSP_ADDR
	mov		SPC_DSP_DATA,PVAL+1		; write to DSP_PxH
	inc		SPC_DSP_ADDR
	mov		SPC_DSP_DATA,SAMPLE		; write to DSP_SRCNx

	; If tone2 was updated and the noise channel is set to "periodic noise" with tone2 as the driving signal, then we
	; need to update channel 3 as well.
	cmp		LATCHED_REG,#4
	bne		+
	cmp		NOISE_LATCH,#3
	bne		+
	jmp		!periodic_noise
+:
	ret
	
	
noise_reg_updated:
  clrc
  adc NSAMPLES_LATE,#4
	;bbc		NOISE_LATCH .2,periodic_noise
	mov		a,NOISE_LATCH
	and		a,#4
	bne		+
	jmp		!periodic_noise
+:
	mov		SPC_DSP_ADDR,#DSP_NON
	mov		SPC_DSP_DATA,#8
	mov		SPC_DSP_ADDR,#DSP_GAIN3
	mov		a,#NOISE_GAIN
	and		a,CHN3TOGGLE
	mov		SPC_DSP_DATA,a
	mov		OLDNGAIN,#NOISE_GAIN
	mov		a,NOISE_LATCH
	and		a,#3
	cmp		a,#3
	beq		+
	mov		TEMP,a
	asl		a
	clrc
	adc		a,TEMP
	mov		TEMP,a
	; We want to set the noise clock to $1B - (param*3), i.e. 6400 Hz / (param+1). $20 is added to keep echo disabled
	;mov		a,#$3B
	mov		a,USECHO
	or		a,#$1B
	setc
	sbc		a,TEMP	
	mov		SPC_DSP_ADDR,#DSP_FLG
	mov		SPC_DSP_DATA,a		
	ret
	
+:
	mov		TEMP,TONE2_LATCH
	mov		a,TONE2_LATCH+1
	rol		TEMP
	rol		a
	rol		TEMP
	rol		a
	rol		TEMP
	rol		a
	and		a,#$1F
	mov		x,a
	mov		a,!noise2_table+x
	or		a,USECHO ;#$20
	mov		SPC_DSP_ADDR,#DSP_FLG
	mov		SPC_DSP_DATA,a		
	ret

; "Periodic noise" with tone2's period as the counter reload value
-:
	mov		a,TONE2_LATCH
	asl		a
	mov		y,a					; Y = psgPeriodLo << 1
	mov		a,TONE2_LATCH+1
	rol		a					; A = (psgPeriodHi << 1) | ((psgPeriodLo & 0x80) >> 7)
	and		a,#7				; the frequency table is $800 bytes long
	clrc
	adc		a,#$10				; ..and it starts at $F00 
	mov		FREQ_PTR+1,a

	mov		SAMPLE,#1
	mov		a,[FREQ_PTR]+y		; load low byte of S-DSP period
	mov		PVAL,a
	inc		y
	mov		a,[FREQ_PTR]+y		; load high byte of S-DSP period
	mov		PVAL+1,a
	; Bit 15 and 14 of PVAL are used as flags. If bit 15 set then a sample 4x as wide should be used.
	; If both bit 14 and 15 are set then a sample 8x as wide should be used.
	; P has already been prescaled in the table for these values.
	bpl		+
	mov		SAMPLE,#2
	bbc		PVAL+1 .6,+
	mov		SAMPLE,#4
+:
	and		PVAL+1,#$7F
	mov		SPC_DSP_ADDR,#DSP_P3L
	mov		SPC_DSP_DATA,PVAL		
	inc		SPC_DSP_ADDR
	mov		SPC_DSP_DATA,PVAL+1		
	inc		SPC_DSP_ADDR
	mov		SPC_DSP_DATA,SAMPLE		
	
	ret
periodic_noise:
	mov		SPC_DSP_ADDR,#DSP_NON
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_GAIN3
	mov		a,#NOISE_GAIN
	and		a,CHN3TOGGLE	
	mov		SPC_DSP_DATA,a
	mov		OLDNGAIN,#TONE_GAIN
	mov		a,NOISE_LATCH
	and		a,#3
	cmp		a,#3
	beq		-
	asl		a
	mov		x,a
	mov		a,!per_noise_table+x
	mov		SPC_DSP_ADDR,#DSP_P3L
	mov		SPC_DSP_DATA,a
	inc		SPC_DSP_ADDR
	mov		a,!per_noise_table+1+x
	mov		SPC_DSP_DATA,a
	ret
	


stop:
	mov		PLAYING,#0

	mov		SPC_DSP_ADDR,#DSP_FLG
	mov		SPC_DSP_DATA,#$20
	
	; Clear per-channel DSP registers (VOL, P, SRCN, ADSR, GAIN)
	mov		x,#0
	mov		y,#$80
clear_dsp:
	mov		a,x
	and		a,#$77
	mov		SPC_DSP_ADDR,a
	mov		SPC_DSP_DATA,#0	
	inc		x
	dbnz	y,clear_dsp

	; Key off all channels
	mov		SPC_DSP_ADDR,#DSP_KOF
	mov		SPC_DSP_DATA,#$FF

	; No echo feedback, echo volume 0, echo buffer at $FE00. 
	; These don't really matter since echo is disabled in FLG.
	mov		SPC_DSP_ADDR,#DSP_ESA
	mov		SPC_DSP_DATA,#$DF
	mov		SPC_DSP_ADDR,#DSP_EFB
	mov		SPC_DSP_DATA,#$64 ;0
	mov		SPC_DSP_ADDR,#DSP_EVOLL
	mov		SPC_DSP_DATA,#30
	mov		SPC_DSP_ADDR,#DSP_EVOLR
	mov		SPC_DSP_DATA,#30
	
	cmp		USECHO,#0
	bne		+
	mov		SPC_DSP_ADDR,#DSP_EON
	mov		SPC_DSP_DATA,#$F
	mov		SPC_DSP_ADDR,#DSP_EDL
	mov		SPC_DSP_DATA,#4
	mov		SPC_DSP_ADDR,#DSP_FLG
	mov		SPC_DSP_DATA,#0
	bra		++
	+:
	mov		SPC_DSP_ADDR,#DSP_EON
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_EDL
	mov		SPC_DSP_DATA,#4
	mov		SPC_DSP_ADDR,#DSP_EVOLL
	mov		SPC_DSP_DATA,#0
	mov		SPC_DSP_ADDR,#DSP_EVOLR
	mov		SPC_DSP_DATA,#0
	++:
	
	; Set master volume	
	mov		SPC_DSP_ADDR,#DSP_MVOLL
	mov		SPC_DSP_DATA,MVOL
	mov		SPC_DSP_ADDR,#DSP_MVOLR
	mov		SPC_DSP_DATA,MVOL

	; Set gain levels. The gain for the noise channel needs to be much lower than for
	; the tone channels.
	mov		SPC_DSP_ADDR,#DSP_GAIN0
	mov		SPC_DSP_DATA,#TONE_GAIN
	mov		SPC_DSP_ADDR,#DSP_GAIN1
	mov		SPC_DSP_DATA,#TONE_GAIN
	mov		SPC_DSP_ADDR,#DSP_GAIN2
	mov		SPC_DSP_DATA,#TONE_GAIN
	mov		SPC_DSP_ADDR,#DSP_GAIN3
	mov		SPC_DSP_DATA,#NOISE_GAIN
	mov		OLDNGAIN,#NOISE_GAIN

	mov		VOL0_LATCH,#0
	mov		VOL1_LATCH,#0
	mov		VOL2_LATCH,#0
	mov		VOL3_LATCH,#0
	
	call	!update_vol
	
	mov		SPC_CTRL,#$B0
	ret



	

tone_vol:
.DB 120,99,79,63,51,41,33,27,22,18,15,13,11,9,6,0


short_wait_timer_values:
.DB 0,1,2,5,7,8,10,11,13,14,15,17,18,20,21,19 ;23
;   1,2,4

per_noise_table:
.DW 1638, 819, 410

noise2_table:
.db $18,$18,$15,$13,$12,$11,$10,$10
.db $0F,$0F,$0E,$0E,$0D,$0D,$0D,$0C
.db $0C,$0C,$0C,$0B,$0B,$0B,$0B,$0A
.db $0A,$0A,$0A,$0A,$0A,$09,$09,$08


.ORGA $0800
freq_table:
.INCLUDE "freqtb.inc"

freq_table2:
.INCLUDE "freqtb2.inc"

vgm_file:





