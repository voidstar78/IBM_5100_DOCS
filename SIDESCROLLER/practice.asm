; Sample assembly code for IBM 5110 using Alfred Arnold Macro Assembler AS
; -----------------------------------------------------------------------------
; Xiphod/voidstar - 2025  (contact.steve.usa@gmail.com)
;
; The following example is intended as a "capability demonstration" of the
; PALM instruction set and IBM 5100/5110/5120 systems.
;
; The registers are designated R0 to R15.  R0 is the Program Counter.
; R1 is adjusted as the return address of SKIP/JUMP instructions.
;
; NOTE: R10 = RA, R11 = RB, R12 = RC, R13 = RD, R14 = RE, R15 = RF
; Each register has a "HI" (high) and "LO" (low) portion.
; Rx = HILO (HI is upper 8-bits, LO is lower 8-bits)
;
; NOTE: Example $xxFF is used where "xx" portion is unchanged or not-impacted.
; -----------------------------------------------------------------------------
		cpu         IBM5100

        intsyntax	+$hex,-x'hex'      ; support $-style hex (not IBM 0x style)

;--- CONSTANTS ----------------------------------------------------------------
SCREENSIZE                             equ 16*64       ; static computed
COL_PER_ROW                            equ 64
ROW_PER_COL                            equ 16


        ; The following code should be "relocatable" due to using relative
		; branching (not absolute-fixed addresses).  The first ORG decides
		; where it is expected that this code will be loaded into.  Specifying
		; this helps establish where any "db" "dw" reserved-data regions
		; will be located.
        ORG   $2000
		
		NOP         ; $2000: 0004
		NOP         ; $2002: 0004
		BRA start   ; $2004: A003 -> ADDI+1, this adds 4 to REG[R0] program counter (implicitly this is +1)
		NOP         ; $2006: 0004
		NOP         ; $2008: 0004
		
start:
		LWI   R2,  #$0002   ; $200A: D201  --> REG[R2] = 2      [  $200A: D301 --> LDHI r2,r0+2 ]
		                    ; $200C: 0002  (DATA)
		                    ; REG[R2] == MEM[R0+2], so the next word after this instruction
							; is the R0 (program counter) at the time the instruction is executed.
							; This means the 2 bytes after this instruction correspond to the 
							; full word of data that is to be stored into the target register (R2).
							; This means this instruction is really 4-bytes instead of normal 2.
							; The LDHI instruction then skips the data portion automatically,
							; giving the appearance of a regular load word immediate.
		
		LWI   R3,  #$0AAA   ; $200E: D301          We follow this same convention for the remaining registers, except
		                    ; $2010: 0003  (DATA)  avoid using R0 and R1.  R0 is the program counter, R1 is generally 
							; reserved for branch related instructions.  This register is intentionally set to >255
							; to test behavior later.
							
		LWI   R4,  #$0004   ; $2012: D401  Basically REG[R4] = MEM[R0+2] at the time of instruction execution
		                    ; $2014: 0004  (DATA)   (loops like NOOP, but it is not!)
							
		LWI   R5,  #$0005   ; $2016: D501  REG[R5] = MEM[R0+2]
		                    ; $2018: 0005  (DATA)
							
		LWI   R6,  #$0006
		LWI   R7,  #$0007
		LWI   R8,  #$1000   ; $2022: D801  REG[R8] = $1000, this is a large than 255 value to show it can be done using Load Word Immediate		
		                    ; $2024: 1000  (DATA)
							
		; At this point, Register values are...
		; R0 = CURPC = 2026
		; R1 = (0F40), might vary depending on emulator startup state
		; R2 = 0002
		; R3 = 0AAA
		; R4 = 0004
		; R5 = 0005
		; R6 = 0006
		; R7 = 0007
		; R8 = 1000
		; (remaining registers haven't been set yet)
							
		LWI   R9,  #$0009  ; $2026 ...
		LWI   R10, #$000A  ; $202A ...
		LWI   R11, #$000B  ; $202E ...
		LWI   R12, #$000C  ; $2032 ...
		LWI   R13, #$000D  ; $2036 ...
		                   ; $2038: 000D   (DATA)
		LWI   R14, #$000E  ; $203A
		LWI   R15, #$00FF  ; $203E: DF01   REG[R15] = 255, given a max byte value for later demonstration
		                   ; $2040: 00FF   (DATA)
		
		LTH   R10, R2      ; $2042: 0A2D   Hi of REG[R10] becomes Lo of REG[R2] ==> REG[10] == $020A
		LBI   R3,  #$03    ; $2044: 8303   Lo REG[R3] = $xx03  (Load Byte Immediate, applies only to immediate values 00 to FF)
		XOR   R10, R3      ; $2046: 0A37   Lo REG[R10] becomes $xx09 (only Lo of R10 is impacted, Hi portion remains unchanged)
		                   ; i.e. 0000 1010(0A) 
						   ;  xor 0000 0011(03) 
						   ;  -----------------
						   ;      0000 1001   --> REG[R10] == xx09
						   
		XOR   R10, R3      ; $2048: 0A37   Lo REG[R10] returns to $xx0A  (XOR'ing again with same value reverts back to original value)
        
		INC2  R13          ; $204A: 0DD3   reg[R13] = reg[R13] + 2   --> R13 $000D+2 which is $xx0F
		INC   R13          ; $204C: 0DD2   R13 becomes $xx10
		DEC2  R13          ; $204E: 0DD0   R13 becomes $xx0E
		
		INC   R15          ; $2050: 0FF2   R15 becomes $0100 (does rollover from $00FF)
		DEC   R15          ; $2052: 0FF1   R15 returns back to $00FF
		ADD   R15, R4      ; $2054: 0F48   REG[R15] = REG[R15] + REG[R4] = $00FF + $0004 = $0103

		; R2 = 0002  R09 = 0009
		; R3 = 0A03  R10 = 020A
		; R4 = 0004  R11 = 000B
		; R5 = 0005  R12 = 000C
		; R6 = 0006  R13 = 000E
		; R7 = 0007  R14 = 000E
		; R8 = 1000  R15 = 0103

        LWI   R15, #$FFFE  ; $2056: DF01   Assign REG[R15] to full word value of $FFFE
		                   ; $2058: FFFE   (DATA)
						   
		INC2  R15          ; $205A: 0FF3   REG[R15] = REG[R15]+2 = $0000
-		ADD   R15, R8      ; $205C: 0F88   REG[R15] = REG[R15] + Lo REG[R8] = $0000
		SZ    R15          ; $205E: CF03   is REG[R15] == 0?
		BRA   -            ; $2060: F005   if NO then (JMP to $205C)

skipOnZero:		
                           ; You can set breakpoint (bp) here at 2062 and set R15 to any value.
						   ; That value will then get stored into MEM @ address of R8.
						   ; Note, only the LO portion of R15 is stored (LSB's).
						   
		MOVB  (R8)+, R15   ; $2062: 7F80   MEM[R8] = Lo REG[R15], R8=R8+1  (STBI followed by increment)
		                   ; Byte addressable
						   
		MOVB  (R8), R15    ; $2064: 7F88   MEM[R8] = REG[R15]   (R8 is at addr 1001)
		MOVB  R10, (R8)    ; $2066: 6A88   Lo REG[R10] = MEM[R8]  (byte addressed)
		
        LBI   R3, #$FF     ; $2068: 83FF   REG[R3] = $xxFF  (immediate)
		                   ; Note Hi REG[R3] is not impacted, only the lower byte.
						   
		SLE   R10, R3      ; $206A: CA30   skip if R10 <= R3...
		JMP   start        ; $206C: F063   (this always gets skipped, due to how we've contrived register values earlier)
		
		MOVE  R10, R11     ; $206E: 0AB4   REG[R10] = REG[R11] = $000B
		MLH   R11, R11     ; $2070: 0BBD   REG[R11] becomes $0B0B  --> REG[R11] = $0B0B
		MHL   R10, R10     ; $2072: 0AAC   REG[R10] becomes $0000
		
		SETI  R6, #$EA     ; $2074: B6EA  --> (bin) 0000 0110 original REG[R6] = 6
		                   ;                  (bin) 1110 1010 $EA
						   ;                        1110 1110 new value of REG[R6] = $xxEE  (Lo portion only)
						   
		CLRI  R6, #$EA     ; $2076: 96EA  --> REG[R6] = 0004
		                   ;                        1110 1110 ($EE)
						   ;                        1110 1010 ($EA)
						   ;                        0000 0100 ($04)
						   
		SETI  R6, #$04     ; $2078: B604  (no change to value of R6)
		
		ADDI  R6, 2        ; $207A: A601  REG[R6] = 0004 + 2 --> REG[R6] = 0006
		SUBI  R6, 1        ; $207C: F600  REG[R6] = (bin) 0000 0101 (05 in binary)
		SUBI  R6, 3        ; $207E: F602  REG[R6] == 2
		SUBI  R6, 1        ; $2080: F600  REG[R6] == 1
		SUBI  R6, 1        ; $2080: F600  REG[R6] == 0
		SUBI  R6, 1        ; $2084: F600  REG[R6] == $FFFF (full word rollover)
		SUBI  R6, #$FF     ; $2086: F6FE  REG[R6] == $FF00
		
		LWI	  R6, #$FFFF   ; $2088: D601
		                   ; $208A: FFFF  (DATA)
		ADDI  R6, 1        ; $208C: A600
		LWI   R6, #$FFFF   ; $208E: D601  (LDHI R6,R0,+2)
		                   ; $2090: FFFF  (DATA)
		INC   R6           ; $2092: 0662  REG[R6] = REG[R6] + 1 = $0000 (rollover back to 0)
		
check_again:
		SZ    R6           ; $2094: C603  Skip if Zero REG[R6]
		BRA   shift_test   ; $2096: A001  (JMP $209A)
		JMP   part2        ; $2098: A003  (JMP $209E) Above was skipped when REG[R6] == 0, so now we go to PART 2
shift_test:
		ROR   R6           ; $209A: E06D
		BRA   check_again  ; $209C: F009  (JMP $2094)
		
part2:
        CALL  TestCall, R2 ; $209E: 0203  (MVP2 R2,R0) Example of doing a CALL, using R2 to store the return address
		                   ;              Current value of R0 (program counter) stored into target (R2)
						   ;              NOTE: REG[R2] = REG[R0]+2 (so we return to the next instruction)
						   ;              REG[R2] == 20A2
						   ; $20A0: D021  (LDHI R0,R2,+2) --> R0 = MEM[R0+2], REG[R2] == 20A4
						   ; $20A2: 20B4  (DATA)  (where to jump to for the CALL)
		DEC   R5           ; $20A4: 0551  REG[R5] = REG[R5] - 1 == 5
		ROR3  R5           ; $20A6: E05E  Lo REG[R5] >> 3 --> 0000 0101             (Hi/Upper portion not effected)
		                   ;                                  1000 0010  >> 1
						   ;                                  0100 0001  >> 1
						   ;                                  1010 0000  >> 1   ($A0)
		SWAP  R5           ; $20A8: E05F  Lo REG[R5] = $xx0A
		SHR   R5           ; $20AA: E05C  0000 1010 -> 0000 0101 (5)  (SHIFT RIGHT, no rotate)
		SHR   R5           ; $20AC: E05C  0000 0101 -> 0000 0010 (2)  (SHIFT RIGHT, no rotate)

		OR    R5, #$13     ; $20AE: B513  SETI R5,#$13 --> 0000 0010
		                   ;                           or  0001 0011 --> $13
						   
		AND   R5, #$A2     ; $20B0: 955D  CLRI R5,#$5D --> 0001 0011 
		                   ;                           and 1010 0010($A2) --> 0101 1101($5D)
		                   ;                               0000 0010
		
		HALT               ; $20B2: 0000  (once HALTed, there is no interrupt recovery - must reset)
		                   ; As an alternative, this could be a "BRA start" as long as within 255 bytes
						   ; otherwise assembler will report "jump distance to big".  In that case, you can
						   ; use "JMP start" instead (will be a 4-byte instruction instead of 2)

TestCall:
		LBI   R5, 6        ; $20B4: 8506  REG[R5] = xx06
		RET   R2           ; $20B6: 0024  (jump to the address stored in REG[R2] which is $20A4)
