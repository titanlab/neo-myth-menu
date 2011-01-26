|TODO : word versions
        .text
        .align 2

|int mem_cmp (const void* dst, const void* src, int cnt)
        .global mem_cmp
mem_cmp:
		movem.l 4(sp),a0-a1
		move.l  12(sp),d1
		moveq   #0,d0
0:
		dbra d1,1f
		bra 2f
1:
		move.b  (a0)+,d0
		sub.b   (a1)+,d0
        beq.b   0b
2:
        ext.w   d0
        ext.l   d0
		rts

| int chk_chr (const char* str, int chr)
        .global chk_chr
chk_chr:
		movea.l 4(sp),a0
		move.l  8(sp),d1
		move.l  d1,d0
1:
		tst.b   (a0)
        beq.b   2f

		cmp.b   (a0)+,d0
		bne.b   1b
2:
		move.b  (a0),d0
		rts

| void mem_set(void* dst, int val, int cnt)
        .global mem_set
mem_set:
		movea.l 4(sp),a0
		movem.l 8(sp),d0-d1
		bra.b   2f
1:
		move.b  d0,(a0)+
2:
		dbra    d1,1b
		rts

| void mem_cpy(void* dst, const void* src, int cnt)
        .global mem_cpy
mem_cpy:
		movem.l 4(sp),a0-a1
		move.l  12(sp),d0
		bra.b   2f
1:
		move.b  (a1)+,(a0)+
2:
		dbra    d0,1b
		rts

