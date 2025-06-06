; IBM 5100 Sidescroller - for IBM 5100 using Alfred Arnold Macro Assembler AS
; (will also work for IBM 5110/5120, only difference is deciding which font symbols to use)
; -----------------------------------------------------------------------------
; by Xiphod of voidstar tech - May 2025  (contact.steve.usa@gmail.com) [Steve Lewis]
;
; The registers are designated R0 to R15.  R0 is the Program Counter.
; R1 is reserved for psuedo instructions and other internal uses.  
; R2 is reserved as the return address of calls.
;
; Each register has a "HI" (high) and "LO" (low) portion (16-bit total).
; Rx = HILO (HI is upper 8-bits, LO is lower 8-bits)
; Lo Rx = Lower portion only of REG Rx
; Hi Rx = Upper (high) portion only of REG Rx
;
; -----------------------------------------------------------------------------
  cpu         IBM5100            ; PALM processor

  include     "cp5100.inc"       ; or use ebcdic.inc
  intsyntax	  +$hex,-x'hex'      ; support $-style hex (not IBM 0x style)
  codepage    cp5100             ; activate a string mapping of chars

;--- CONSTANTS ----------------------------------------------------------------
SCREENSIZE                             equ 16*64   ; static computed
COL_PER_ROW                            equ 64
ROW_PER_COL                            equ 16
ADDR_SCREEN                            equ $0200   ; Address of CRT display
BG_SYMBOL_W                            equ $0000   ; $3838 squares (used in initial clrscr) [$0000 for blank]
BG_SYMBOL                              equ $00     ; $38
NULL_TERM_W                            equ $FFFF   ; used at end of strings (W for "wide")
NULL_TERM_HI                           equ $FF
NULL_TERM_LO                           equ $FF
NULL_TERM                              equ $FF
BANNER_TARGET                          equ $1000   ; Starting address of expanded banner text
FIRST_BANNER_ROW                       equ $0280   ; Use this to set which screen row the banner starts on
UL                                     equ 128     ; underline (for IBM 5100, MSB of characters decides underline or not)
DELAY_COUNT                            equ $01C0

; The following code should be "relocatable" due to using relative
; branching (not absolute-fixed addresses).  This first ORG decides
; where it is expected that this code will be loaded into.  Specifying
; this helps establish where any "db" "dw" reserved-data regions
; will be located.
  ORG    $06F0   ; Wouldn't go lower than $0600 (system first 512 bytes, then screen 64x16 is 1KB)
  NOP
  NOP
  NOP
  LWI    R2, DELAY_COUNT
  ; NOP
  LWI    R3, $2CFF
  ; NOP
  MOVE   (R2), R3

; -----------------------------------------------------------------------------
  CALL   ClrScr, R2 

CALCULATE:  

  ; TASK: Given number of characters in the banner, calculate the storage necessary per row of the "banner-ized" version.
  ; Since we know each character is 8 "columns" wide, this becomes N * 8.
  ; For example, if we have 6 characters then 6*8 = 48 "bytes" (each byte becomes a column)
  LWI    R9, BANNER_LEN              ; R9 = address of BANNER_LEN (user specified length of the input string)
  LDBI   R9, R9                      ; Lo R9 = MEM[R9]  (get length of string to "bannerize")

  ; Set entire content of R10 to be 0, since we're going to use R10 to be the accumulated row length.
  ; Two bytes is necessary since this full length may be >255 columns.  Worse case is 255*8 = 2040 (per row!)
  LBI    R10, 0                      ; Lo R10 = 0
  LTH    R10, R10                    ; Hi R10 = Lo R10 = 0									 

  ; The following is basically doing R10 = R10 + (8 * R9)   [ 8 is the chosen bannerized columns-per-character ]
  ; But we have no native multiply, so we have to accumulate ourselves 
  ; (and we need to use ADDI to handle rollover for values >255).
FIND_LEN_NEXT:  
  SZ     R9                          ; Skip if R9 is 0.
                                     ; R9 starts as the number of characters in the input string.
                                     ; We start decrementing this, to know we are done when this reaches 0.

  BRA    FIND_LEN_BYTES              ; Accumulate the length of one "bannerized" character.
  BRA    CALCULATE_NEXT_SETUP        ; If R9 was 0, we skipped to here: We reached 0, go to the NEXT_STEP.

FIND_LEN_BYTES:
  ADDI   R10, #8                     ; R10 = R10 + 8  : Increment R10 by the column size of each "bannerized" character.
                                     ; ADDI handles rollover past 255.

  DEC    R9                          ; R9 = R9 - 1    : Account for crediting one character.
  BRA    FIND_LEN_NEXT               ; Repeat for next input string character.

  ; Register Usage Notes... (xxx means not yet used)
  ; R0 = Program Counter                R8  = xxx
  ; R1 = Reserved for internal          R9  = 0 (was bytes per row, but decremented back to 0 to indicate done calculating)
  ; R2 = Reserved for CALL Return       R10 = Length of a row in the "bannerized" output string
  ; R3 = xxx                            R11 = xxx
  ; R4 = xxx                            R12 = xxx
  ; R5 = xxx                            R13 = xxx
  ; R6 = xxx                            R14 = xxx
  ; R7 = xxx                            R15 = xxx

CALCULATE_NEXT_SETUP:
  HTL    R9, R10              ; High To Low: Lo R9 = Hi R10
                              ; R9 becomes the HIGH value of the LEN, R10 is the LOW value of the LEN
							  ; The full LEN (row length) could be >255.  Separating out this 16-bit value
							  ; to two registers makes it easier to "walk the rows" when we setup the
							  ; addresses-per-row in the code below.                              

  LWI    R11, BANNER_TARGET   ; R11 = address of BANNER_TARGET (starting BANNER output target address)
  LWI    R12, WORKING_ADDRESS ; R12 = address of memory for WORKING_ADDRESS (starts at initial BANNER_TARGET)
  LWI    R13, WORKING_ADDRESSI; R13 = address of memory for WORKING_ADDRESSI (redundant copy of initial WORKING_ADDRESS)

  MOVE   (R12)+, R11          ; MEM[R12] = R11, R12 = R12+2  (row 1)
                              ; This copies the initial BANNER_TARGET to the initial WORKING_ADDRESS
							  ; Each address after WORKING_ADDRESS corresponds to the subsequent row
							  ; of the "bannerized" string.    BANNER_TARGET remains as a fixed constant
							  ; throughout the program, but the WORKING_ADDRESSes get "walked" as needed.
  MOVE   (R13)+, R11

  CALL   IncreaseR11_by_Len, R2
  MOVE   (R12)+, R11          ; (row 2)
  MOVE   (R13)+, R11
  
  CALL   IncreaseR11_by_Len, R2
  MOVE   (R12)+, R11          ; (row 3)
  MOVE   (R13)+, R11
  
  CALL   IncreaseR11_by_Len, R2
  MOVE   (R12)+, R11          ; (row 4)
  MOVE   (R13)+, R11
  
  CALL   IncreaseR11_by_Len, R2
  MOVE   (R12)+, R11          ; (row 5)
  MOVE   (R13)+, R11

  CALL   IncreaseR11_by_Len, R2
  MOVE   (R12)+, R11          ; (row 6)
  MOVE   (R13)+, R11
  
  CALL   IncreaseR11_by_Len, R2
  MOVE   (R12)+, R11          ; (row 7)
  MOVE   (R13)+, R11
  
  CALL   IncreaseR11_by_Len, R2
  MOVE   (R12)+, R11          ; (row 8)
  MOVE   (R13)+, R11
  
  CALL   IncreaseR11_by_Len, R2
  MOVE   (R12)+, R11          ; (row 9)
  MOVE   (R13)+, R11
  
  CALL   IncreaseR11_by_Len, R2
  MOVE   (R12)+, R11          ; (row 10)
  MOVE   (R13)+, R11
  
  LWI    R3, BANNER_STRING   ; Load Word Immediate, R3 = address of BANNER_STRING  (full word load)                             
                             ; R3 will be used to "walk" the user input string that we are "bannerizing."
  
CALCULATE_NEXT: 
  MOVE   R5, (R3)+           ; R5 = MEM[R3]       R5 == Lo portion of the BANNER_STRING content
  HTL    R4, R5              ; Lo R4 = Hi R5      R4 == Hi portion of the BANNER_STRING content
  
  ; We are done when we reached the END OF STRING marker in the user input.  This is marked by the
  ; value of NULL_TERM_W (which is separated out for convenience as NULL_TERM_HI and NULL_TERM_LO).
  LBI    R6, NULL_TERM_HI    ; Lo R6 = value of equate NULL_TERM_HI  (Load Byte Immediate)
  SE     R6, R4              ; Skip if Lo R6 = Lo R4 ...
  BRA    CALCULATE_LARGE     ; Since not equal, no need to evaluate the Lo portion - proceed with calculating this character
  ; Now Check Lo - if we got here, then we know R6 == R4
  LBI    R6, NULL_TERM_LO    ; Lo R6 = value of equate NULL_TERM_LO  (the Lo portion of NULL_TERM_W)
  SE     R6, R5              ; Skip if Lo R6 == Lo R5 (indicating both Hi and Lo portions matched corresponding end of string marker values)
  BRA    CALCULATE_LARGE     ; (not equal, so continue calculating this character)  
  CALL   MAINLOOP_INIT, R2   ; Both HI and LO content at MEM[R3] is equal to the END OF STRING marker.
                             ; This means all the characters have been processed, so proceed with the main loop program
							 ; of scrolling the "bannerized" version of the string.
  
CALCULATE_LARGE:  
  ; TASK: Find the address offset corresponding to this user specified letter
  ; R4 and R5 correspond to the index into the BIG_LETTERS table to start converting
  ; Starting at BIG_LETTERS address, increment Hi * $FF + Lo
  ; TAKE THE OFFSET NOW STORED IN R4
  LWI    R6, BIG_LETTERS     ; R6 = address of BIG_LETTERS (start of data-table for large banner fonts)
  
  ; As done earlier (in IncreaseR11_by_Len), we will be "walking" (incrementing) some values that may be
  ; larger than 255 (over 8-bit).   We will walk the "high portion" (R4) first (steps of $FF) then walk the
  ; remaining "low portion" (R5). 
  ; Basically this is doing R6 = R6 + MEM[R3] --> R6 = address of BIG_LETTERS + current BANNER_STRING content (byte offset)
AGAIN_HI:
  SZ     R4                  ; Skip if R4 == 0   (i.e. does R4 == 0 yet?)
  BRA    EXHAUST_HI          ; R4 is not yet 0, perform an intermediate calculation...
  BRA    HANDLE_LO           ; Yes, R4 == 0, so now check LO portion...
EXHAUST_HI:
  ADDI   R6, #$FF            ; R6 = R6 + $FF  (increment R6 offset-index by one whole byte length)
  ADDI   R6, #1
  DEC    R4                  ; R4 = R4 - 1  (account for having performed one increment)
  BRA    AGAIN_HI            ; Check the HI portion again (as stored in R4)  
  
HANDLE_LO:                   ; Check if the LO portion is also 0, otherwise accumulate R6 until it is
  SZ     R5                  ; Skip if R5 == 0   (low portion of byte offset)
  BRA    MORE_LO             ; R5 is not yet 0, perform an intermediate calculation...
  BRA    PROCESS_ROWS        ; Yes, R5 == 0, reached the index for this character - so now processing this entire "bannerized" row (for this character)
MORE_LO:  
  ADDI   R6, 1               ; Increment R6 by 1 (ADDI handles rollover) [one increment of low-order]
  DEC    R5                  ; Account for one increment having been performed
  BRA    HANDLE_LO           ; Check again if we are finished yet
 
PROCESS_ROWS: 
  MOVE   R7, (R6)+           ; R7 = MEM[R6], R6 = R6+2   :  R7 is the symbol to use for this font expansion
                             ; MOVE copies the full word, we want the symbol value to be in both HI and LO portions
  HTL    R7, R7              ; Lo R7 = Hi R7  : move the loaded symbol value into the LO portion of R7
  LWI    R12, WORKING_ADDRESS; R12 = address of WORKING_ADDRESS (start of the per-row address tables)

  LBI    R9, #$05            ; We have 10 rows to process, but we process 2 rows at a time (so set a counter value of 5)
PROCESS_ROWS_NEXT:

  ; START ROW n
  MOVE   R11, (R12)          ; R11 = MEM[R12] - get address of the current working row
                             ; Output for current row will be written to the address stored in R11

  MOVE   R8, (R6)+           ; R8 = MEM[R6], R6 = R6+2
                             ; R8 now holds the next two rows of data (HI is first row, LO is second row)
							 ; R6 is are "working index" into the BIG_LETTERS table of data

; -------------------------------------- COL 1/2
  ; Handle Hi and Lo portion of R8
  ; Hi R8 is first row, Lo R8 is second row  
  HTL    R4, R8              ; High-to-Low R8 to R4: Lo R4 = Hi R8
  LBI    R14, #128           ; 
  SNBS   R4, R14             ; Skip if Not Bit Set
  BRA    SET_COL1
  LBI    R5, BG_SYMBOL       ; clear
  LTH    R5, R5
  BRA    DO_COL2
SET_COL1:
  LTH    R5, R7  
  
DO_COL2:  
  HTL    R4, R8
  LBI    R14, #64
  SNBS   R4, R14
  BRA    SET_COL2
  LBI    R5, BG_SYMBOL
  MOVE   (R11)+, R5  
  BRA    DO_COL3
SET_COL2:
  HTL    R5, R7
  MOVE   (R11)+, R5  
; --------------------------------------  
  
; -------------------------------------- COL 3/4
DO_COL3:  
  HTL    R4, R8              ; High-to-Low R8 to R4: Lo R4 = Hi R8
  LBI    R14, #32            ; R4 = R4 AND 128
  SNBS   R4, R14
  BRA    SET_COL3
  LBI    R5, BG_SYMBOL       ; clear
  LTH    R5, R5
  BRA    DO_COL4
SET_COL3:
  LTH    R5, R7  
  
DO_COL4:  
  HTL    R4, R8
  LBI    R14, #16
  SNBS   R4, R14
  BRA    SET_COL4
  LBI    R5, BG_SYMBOL
  MOVE   (R11)+, R5  
  BRA    DO_COL5
SET_COL4:
  HTL    R5, R7
  MOVE   (R11)+, R5  
; --------------------------------------  
  
; -------------------------------------- COL 5/6
DO_COL5:  
  HTL    R4, R8              ; High-to-Low R8 to R4: Lo R4 = Hi R8
  LBI    R14, #8             ; R4 = R4 AND 128
  SNBS   R4, R14
  BRA    SET_COL5
  LBI    R5, BG_SYMBOL       ; clear
  LTH    R5, R5
  BRA    DO_COL6
SET_COL5:
  LTH    R5, R7  
  
DO_COL6:  
  HTL    R4, R8
  LBI    R14, #4
  SNBS   R4, R14
  BRA    SET_COL6
  LBI    R5, BG_SYMBOL
  MOVE   (R11)+, R5  
  BRA    DO_COL7
SET_COL6:
  HTL    R5, R7
  MOVE   (R11)+, R5  
; --------------------------------------  
  
; -------------------------------------- COL 7/8
DO_COL7:  
  HTL    R4, R8              ; High-to-Low R8 to R4: Lo R4 = Hi R8
  LBI    R14, #2             ; R4 = R4 AND 128
  SNBS   R4, R14
  BRA    SET_COL7
  LBI    R5, BG_SYMBOL       ; clear
  LTH    R5, R5
  BRA    DO_COL8
SET_COL7:
  LTH    R5, R7  
  
DO_COL8:  
  HTL    R4, R8
  LBI    R14, #1
  SNBS   R4, R14
  BRA    SET_COL8
  LBI    R5, BG_SYMBOL
  MOVE   (R11)+, R5  
  BRA    DONE_COLUMNS_FIRST_ROW
SET_COL8:
  HTL    R5, R7
  MOVE   (R11)+, R5  
; --------------------------------------  

DONE_COLUMNS_FIRST_ROW:
  ; Store R11 update address into the WORKING_ADDRESS for this row
  ; MEM[working_address] = R11
  MOVE   (R12)+, R11
  MOVE   R11, (R12)
  
  ; =======================================================
  ; SECOND row of the current set...
; -------------------------------------- COL 1/2
  ; Handle Hi and Lo portion of R8
  ; Hi R8 is first row, Lo R8 is second row  
  MOVE   R4, R8              
  LBI    R15, #128           ; R4 = R4 AND 128
  SNBS   R4, R15
  BRA    SET_COL1_R2
  LBI    R5, BG_SYMBOL       ; clear
  LTH    R5, R5
  BRA    DO_COL2_R2
SET_COL1_R2:
  LTH    R5, R7  
  
DO_COL2_R2:
  MOVE   R4, R8
  LBI    R15, #64
  SNBS   R4, R15
  BRA    SET_COL2_R2
  LBI    R5, BG_SYMBOL       ; clear
  MOVE   (R11)+, R5  
  BRA    DO_COL3_R2
SET_COL2_R2:
  HTL    R5, R7
  MOVE   (R11)+, R5  
; --------------------------------------  
  
; -------------------------------------- COL 3/4
DO_COL3_R2:
  MOVE   R4, R8
  LBI    R15, #32            ; R4 = R4 AND 128
  SNBS   R4, R15
  BRA    SET_COL3_R2
  LBI    R5,BG_SYMBOL        ; clear
  LTH    R5, R5
  BRA    DO_COL4_R2
SET_COL3_R2:
  LTH    R5, R7  
  
DO_COL4_R2:
  MOVE   R4, R8
  LBI    R15, #16
  SNBS   R4, R15
  BRA    SET_COL4_R2
  LBI    R5, BG_SYMBOL       ; clear
  MOVE   (R11)+, R5  
  BRA    DO_COL5_R2
SET_COL4_R2:
  HTL    R5, R7
  MOVE   (R11)+, R5  
; --------------------------------------  
  
; -------------------------------------- COL 5/6
DO_COL5_R2:  
  MOVE   R4, R8
  LBI    R15, #8             ; R4 = R4 AND 128
  SNBS   R4, R15
  BRA    SET_COL5_R2
  LBI    R5, BG_SYMBOL       ; clear
  LTH    R5, R5
  BRA    DO_COL6_R2
SET_COL5_R2:
  LTH    R5, R7  
  
DO_COL6_R2:
  MOVE   R4, R8
  LBI    R15, #4
  SNBS   R4, R15
  BRA    SET_COL6_R2
  LBI    R5, BG_SYMBOL       ; clear
  MOVE   (R11)+, R5  
  BRA    DO_COL7_R2
SET_COL6_R2:
  HTL    R5, R7
  MOVE   (R11)+, R5  
; --------------------------------------  
  
; -------------------------------------- COL 7/8
DO_COL7_R2:
  MOVE   R4, R8
  LBI    R15, #2             ; R4 = R4 AND 128
  SNBS   R4, R15
  BRA    SET_COL7_R2
  LBI    R5, BG_SYMBOL       ; clear
  LTH    R5, R5
  BRA    DO_COL8_R2
SET_COL7_R2:
  LTH    R5, R7  
  
DO_COL8_R2:  
  MOVE   R4, R8
  LBI    R15, #1
  SNBS   R4, R15
  BRA    SET_COL8_R2
  LBI    R5, BG_SYMBOL       ; clear
  MOVE   (R11)+, R5  
  BRA    DONE_COLUMNS_NEXT_ROW
SET_COL8_R2:
  HTL    R5, R7
  MOVE   (R11)+, R5  
; --------------------------------------  
DONE_COLUMNS_NEXT_ROW:
  MOVE   (R12)+, R11
  ; =======================================================
  
  DEC    R9
  SZ     R9
  BRA    PROCESS_ROWS_BIGJUMP  ; Can't BRA directly to PROCESS_ROWS_NEXT (too far), and can't JMP either 
                               ; because JMP is a multiword psuedo instruction that we can't skip over.
							   ; So we do a short branch to then do the long JMP that is desired.
				
  CALL   CALCULATE_NEXT, R2    ; Finished all the rows, proceed to the next banner string entry.
  
PROCESS_ROWS_BIGJUMP:
  CALL   PROCESS_ROWS_NEXT, R2 ; More rows to process for the current symbol in the banner string.

MAINLOOP_INIT:

  ; REMINDER: R10 is the count of the total width of the banner in bytes (NumChars * 8)
  ; Since we will be scrolling by column increments of 2, the total number of times we can 
  ; scroll is (R10-64)/2 times.
  ; Example: 9 characters, 9*8 = 72 columns (bytes)  -->  (72-64)/2 = 4 times
  ; Example: 255 characters, 255*8 = 2040 columns (bytes) --> (2040-64)/2 = 988 times
  MOVE   R9, R10               ; R9 = R10  (full word copy, preserve R10 to keep original column width count)
  SUBI   R9, #64               ; R9 = R9 - 64    (SUBI will handle roll over)
  
  ; Now divide by 2 by shifting Hi-portion(Lo R9) and Lo-portion(Lo R8) right by 1
  LBI    R8, 0                 ; lo R8 = 0
  LTH    R8, R8                ; Copy Lo portion of R8 to Hi R8, to ensure entire register is 0000
  HTL    R8, R9                ; Lo R8 = Hi R9   (copy Hi/Upper portion of full word in R9 to an easier to use Lo portion)
  SHR    R8                    ; R8 = R8 >> 1
  SHR    R9                    ; R9 = R9 >> 1  (will carry over from Hi to Lo)
  
  ; We end up out of available registers, so we have to store the TITLE_STRING offset into
  ; memory via TITLE_STRING_TEMP.
  LWI    R4, TITLE_STRING      ; R4 = address of string to write onto screen
  LWI    R5, TITLE_STRING_TEMP ; R5 = addressing of the temporary address index into the TITLE_STRING
  MOVE   (R5), R4              ; MEM[R5] = R4  (initialize TITLE_STRING_TEMP to match the address of TITLE_STRING)

MAINLOOP_INIT2:
  LBI    R3, #0                ; Clear out R3  (set Hi and Lo portions to 0)
  LTH    R3, R3                ; R3 will be used to count number of times we have shifted the banner view
  
  ; Reset WORKING_ADDRESS back to original values for each row (so we start banner from the beginning)
  ; Basically this is a "memcpy" of the 10 addresses from WORKING_ADDRESSI over to WORKING_ADDRESS
  LWI    R4, WORKING_ADDRESS   ; R4 = address of WORKING_ADDRESS
  LWI    R5, WORKING_ADDRESSI  ; R5 = address of WORKING_ADDRESSI
  LBI    R7, #10               ; Banner is across 10 rows, so prepare a counter of that amount
REPEAT_RESET:  
  MOVE   R6, (R5)+             ; R6 = MEM[R5],  R5 = R5 + 2
                               ; Let R6 be a copy of the content at MEM[R5], and increment R5 (by 2)
							   ; so that the next time through it is already at the next table entry to be copied.
  MOVE   (R4)+, R6             ; MEM[R4] = R6,  R4 = R4 + 2
                               ; Store the original table entry value from R6 back into corresponding entry
							   ; pointed at by R4.
  DEC    R7                    ; Decrement that one iteration of the loop has completed.
  SZ     R7                    ; Skip if R7 is Zero: Have we reached 0 yet?
  BRA    REPEAT_RESET          ; Not yet, repeat for the remaining rows
   
  ; Register Usage Notes... (xxx means not yet used)
  ; R0 = Program Counter                R8  = How many steps till reset Banner [Hi]
  ; R1 = Reserved for internal          R9  = How many steps till reset Banner [Lo]
  ; R2 = Reserved for CALL Return       R10 = (was used, now available)
  ; R3 = Counter for reach end yet      R11 = value at WORKING_ADDRESS
  ; R4 = (was used, now available)      R12 = value of WORKING_ADDRESS (pointer)
  ; R5 = (was used, now available)      R13 = (mainloop: WORKING_ADDRESS address)
  ; R6 = (used in MAINLOOP)             R14 = (mainloop: FIRST_BANNER_ROW address)
  ; R7 = (used in MAINLOOP_A)           R15 = (mainloop_B: used to compare HI of R3 with R8)
  LWI    R4, TITLE_STRING_TEMP ; R4  address of string to write onto screen
  MOVE   R4, (R4)              ; R4 = MEM[R4], set the register to the content at the memory pointed to by this same register 
                               ; Because R4 was used up above for temporary work, we have to re-initialize it back
							   ; to the last TITLE_STRING working index (as stored in the memory pointed to by the _TEMP version).
  LBI    R10, #128             ; R10 = 128 ($80), counter for number of "scroll steps" for single string 
  ; R4 is a "scratch" register that we used temporarily and is now free to be used again below.
  
MAINLOOP:

  ; Copy each WORKING_ADDRESS table content to the screen address, incrementing each WORKING_ADDRESS as we go.  
  ; Within each row, we copy a full screen width of content.

  LBI    R6, #10               ; Lo R6 = 10   (Load Byte Immediate), counter for number of rows we will be drawing
  LWI    R14, FIRST_BANNER_ROW ; R14 = address of first row on CRT to draw the banner at
  LWI    R13, WORKING_ADDRESS  ; R13 = address of first WORKING_ADDRESS table entry
                               ; R13 will be used to walk the remaining table entries.
MAINLOOP_A:
  LBI    R7, #32               ; R7 = 32  (we "draw" in pairs of two characters; screen width is 64, so we'll only draw 32-times per scene)
  MOVE   R12, (R13)            ; R12 = MEM[R13], get the actual working_address from array table
MAINLOOP_B:
  MOVE   R11, (R12)+           ; R11 = MEM[R12],  R12 = R12 + 2
                               ; The above gets the actual expanded "big font" content from the working-address
							   ; (R12 is "auto incremented" so that next time around it is already pointing 
							   ; to the next banner entry)
  MOVE   (R14)+, R11           ; MEM[R14] = R11, apply the "big font" content to the corresponding CRT screen
                               ; R14 = R14+2, move to the next screen entry in preparation for next call
							   
  DEC    R7                    ; R7 = R7 - 1   (used to count how many character-pairs have we drawn)
  SZ     R7                    ; Skip if R7 is Zero
  BRA    MAINLOOP_B            ; Not yet 0, complete the current row...
  ; Skip to here when R7=0: Indicates row completed, now preparing for the next row (if any)
  
  ; Before going to next row, a little maintenance on this row...
  MOVE   R12, (R13)            ; R12 = MEM[R13], slide R12 back to the original working address for this row
  INC2   R12                   ; R12 = R12 + 2, increment this by 2 so that next time through it is "stepped" or "scrolled" for this row
  MOVE   (R13)+, R12           ; MEM[R13] = R12, R13 = R13+2
                               ; The above writes the incremented working address back to the table in RAM,
							   ; this is key to giving the appearance of "scrolling" the banner

  DEC    R6                    ; R6 = R6 - 1, decrement counter on number of rows processed
  SZ     R6                    ; Skip if R6 is Zero: have we finished all the rows during this cycle?
  BRA    MAINLOOP_A            ; R6 is not yet zero, we have more rows to process...
  ; R6 has reached zero: means we have completed all the rows for this scrolling cycle/session.
  
  CALL   SmallDelay, R2
  ; ------------------------------
  ; Registers available: R15*, R12*, R11*, R10, R5  
  
; *************************
  LWI    R12, ADDR_SCREEN+(14*64)      ; R12 = $0200 (start of the screen CRT address)
  LBI    R11, #64        ; R11 = how many characters of the string to print (assume 64 screen row width)
  MOVE   R5, R4          ; R5 = R4  (copy current/initial value of R4, since we are going to "walk" R4 below)

PrintStringNextChar: 
  MOVB   R15,  (R4)+    ; R15 = MEM[R4], R4 = R4+1
  SNS    R15            ; Skip if Not All Set (i.e. 0xFF)   NULL_TERM
  BRA    RESET_STRING   ; (R15 did equal 0xFF, we finished early)
  MOVB   (R12)+, R15    ; MEM[R12] = R15, R12 = R12+1
  
  DEC    R11             ; R11 = R11 - 1  (R11 is column counter for current row)
  SZ     R11             ; Has R11 reached zero yet?
  BRA    PrintStringNextChar   ; No, print the next character for this row...
RESET_STRING:
  MOVE   R4, R5          ; R4 = R5  (restore R4 back to its starting address value)
  ADDI   R4, #1          ; R4 = R4+1  (increment to next value, so next pass through loop we print the next 64 characters in the string)
  LWI    R5, TITLE_STRING_TEMP
  MOVE   (R5), R4
	
  DEC    R10             ; R10 = R10 - 1  (limits to how many "64 column cycles" we print)
  SZ     R10             ; Has R10 reached zero yet?
  BRA    NextDelay       ; No, more string content to be printed - just proceed with the next delay and banner update  
  ; Yes, R10 has reached 0... Reinitialize R4 back to the start of the string to be printed
  ; R4 was used temporarily up above, but it is now free to be used again.  For here, we have to first re-initialize
  ; TITLE_STRING_TEMP back to the original TITLE_STRING address.
  LWI    R4, TITLE_STRING       ; R4  initial address of string to write onto screen
  LWI    R5, TITLE_STRING_TEMP  ; R5  address of the temporary working index TITLE_STRING_TEMP
  MOVE   (R5), R4               ; MEM[R5] = R4, store the initial string position back into the _TEMP index storage  
  LWI    R4, TITLE_STRING_TEMP
  MOVE   R4, (R4)               ; R4 = MEMR4]
  LBI    R10, #128       ; R10 = 128 ($80), counter for number of "scroll steps" for single string 
	
NextDelay:	
  ; ------------------------------
  CALL   SmallDelay, R2
  
  ; Have we stepped the max number of times suitable for this banner?  
  ADDI   R3, #1                ; R3 = R3 + 1 (account for one scroll session)  [ i.e. does R3 == R9 ]
                               ; We can't directly compare full word values of R3 and R9.  So instead,
							   ;    split R9 into R8(Hi-portion) and R9(Lo-portion) 
							   ;    split R3 into R15(Hi-portion) and R3(Lo-portion)
  HTL    R15, R3               ; Lo R15 = Hi R3
  SE     R15,R8                ; Skip if Lo R15 == Lo R8...
  BRA    MAINLOOP              ; Not equal (no need to compare Lo portion if Hi portion not equal), keep scrolling
  SE     R3,R9                 ; Skip if Lo R3 == Lo R9...
  BRA    MAINLOOP              ; Not equal, keep scrolling
  BRA    MAINLOOP_INIT2        ; Full banner has been scrolled, reset back to the beginning
  
  BRA    MAINLOOP              ; These are not really necessary, just added protection (separating
  HALT                         ; the code from the supporting call functions and data values)
  NOP
  NOP
  
; -----------------------------------------------------------------------------

; *****************************
; *****************************
SmallDelay: 
  LWI    R12, DELAY_COUNT  
  MOVE   R12,(R12)  
; delay_1 used to be here
  LWI    R11, DELAY_COUNT   ; [ was NOP  1 ]
                            ; [ was NOP  2 ]
delay_1:
  LWI    R15, $0064         ; [ was NOP  3 ]     $0064 on 5100, $0069 on 5110
                            ; [ was NOP  4 ]
  MOVE   R15, (R15)         ; [ was NOP  5 ]     R15 = MEM[R15]
  LBI    R5, #$04           ; [ was NOP  6 ]     Lo R5 = $04   : $04 == up arrow on 5100,  $0B == "A" on 5110, $DF is up arrow on 5110
  SE     R15, R5            ; [ was NOP  7 ]     Skip if Equal R15 == R5  : Check Up Arrow      
  BRA    CheckDown          ; [ was NOP  8 ]     NOT equal, UpKey not pressed - so now check the DownKey
                            ;                    Else, Yes, equal, meaning UpKey was pressed. 
  MOVE   R15, (R11)         ; [ was NOP  9 ]     R15 = MEM[R11]  (full word copy) get last value of DELAY_COUNT
  ADDI   R15, #$FF          ; [ was NOP 10 ]     R15 = R15 + 255
  MOVE   (R11), R15         ; [ was NOP 11 ]     MEM[R11] = R15  (store the adjusted value)
  BRA    clear_last_key     ; [ was NOP 12 ]     Clear out that this key was pressed
CheckDown:               
  LBI    R5, #$0D           ; [ was NOP 13 ]     Lo R5 = $0D   : $0D == down arrow on 5100,  $09 == "Z" on 5110, $4F is down arrow on 5110
  SE     R15, R5            ; [ was NOP 14 ]     Skip if Equal R15 == R5
  BRA    clear_last_key     ; [ was NOP 15 ]     No key we are interested in was detected, clear out the last key register
                            ;                    Else, Yes, scan code matched (DownKey was pressed)
  MOVE   R15, (R11)         ; [ was NOP 16 ]     R15 = MEM[R11]  (full word copy) get last value of DELAY_COUNT
  SUBI   R15, #$FF          ; [ was NOP 17 ]     R15 = R15 - 255
  MOVE   (R11), R15         ; [ was NOP 18 ]     MEM[R11] = R15  (store the adjusted value)
clear_last_key:
  LWI    R15, $0064         ; [ was NOP 19 ]     R15 = $0064    :  $0064 in 5100, $0069 on 5110  offset of last key press
                            ; [ was NOP 20 ]
  LWI    R5, $00FF          ; [ was NOP 21 ]     R5 = $00FF  (full word set)
                            ; [ was NOP 22 ]
  MOVE   (R15), R5          ; [ was NOP 23 ]     MEM[R15] = R5   clear out scan code of last pressed key
NoKey:
  NOP                       ;          #24
  
  ; -------------- Decrement R12 until both HI and LO are zero.
  DEC    R12                 ; Lo R12 = R12 - 1
  SZ     R12                 ; Is Lo R12 == 0 ?
  BRA    delay_1             ; Nope, not yet, repeat the loop delay and then decrement again.
  HTL    R12, R12            ; Lo R12 = Hi R12    Yes Lo was 0, now check Hi portion.
  DEC    R12                 ; Lo R12 = R12 - 1
  SNZ    R12                 ; Skip if NOT Zero R12
  RET    R2                  ; R12 was 0, delay is done so return to the calling code.
  LTH    R12,R12             ; Hi R12 = Lo R12   Set Hi portion back, and Lo portion to roll over to FF next time through
  BRA    delay_1             ; Repeat the loop delay
	
; NOTE: This is only called once, so it shouldn't have been a CALL function and should have just
; been coded inline where it was called.  I thought at the end of a banner scroll, we might clear
; the screen, but I ended up needing the header/footer blank padding anyway.  Anyhow, this is a 
; good example of an efficient way to clear the screen content.
; NOTE: Non-scrolled rows (like at the very top and bottom of screen) will keep whatever
; background character is chosen to be used in BG_SYMBOL_W.
ClrScr:
  LWI    R14, ADDR_SCREEN    ; R14 used as the screen offset
  LWI    R9,  BG_SYMBOL_W    ; R9 full word is used as screen code that is  "  " "**"
                             ;   to be written (e.g. double space: "  ")
  LBI    R3,  $06            ; LO[R3] = $06 (checking to see if our address
                             ;   pointer has reached $0600 yet)
cs_1:   
  MOVE   (R14)+, R9          ; RWS[R14] = R9, then R14 = R14 + 2 (next addr)
                             ;   (^ this does the actual drawing)
  SBSH   R14, R3             ; Have we reached $0600 yet? 
                             ;   (one past end of screen)
                             ; Skip if all set bits in R3 are also set 
                             ;   in HI(R14)
                             ; (note the above SBSH will set R1 = R0+4 -- this
                             ; is in case the code after the jump goes to a
                             ; subroutine -- as documented in IBM 5100 
                             ; MIM Appendix C-16)
  BRA    cs_1
  RET    R2 

IncreaseR11_by_Len:
  MOVE   R4, R9              ; R4 = R9   (scratch copy)  [ this copies full word, Hi and Lo ]
  MOVE   R5, R10             ; R5 = R10  (scratch copy)  [ this copies full word, Hi and Lo ]
                             ; We use R9 and R10 as "quick access memory" to the already-calculated full
							 ; length per row of the "bannerized" string, so we don't have to re-calculate
							 ; it again.  R4/R5 and used as copies of these values, and we'll decrement these
							 ; registers as we "walk" each row to find the starting address of the next row.
RepeatR11IncHi:  
  SZ     R4                  ; Skip if R4 is 0... (skip the next instruction)
  BRA    ContinueR11IncHi    ; R4 is not yet 0, so branch to perform an intermediate computation.
  BRA    IncreaseR11ChkLo    ; R4 == 0, so we are done accumulating the Hi portion, now do the Lo portion.
ContinueR11IncHi:
  ADDI   R11,#$FF            ; Each count of R4 represents a full $FF (255) step, so increment R11 by that much.
                             ; ADDI handles roll over for >255.
  ADDI   R11,#1
  DEC    R4                  ; Decrement R4 (which was initialized as a copy of R9), to account for this
                             ; increment being applied.   (note, this is basically doing a multiply)
  BRA    RepeatR11IncHi      ; Repeat again until R4 reaches 0 to indicate that we are done.
  
IncreaseR11ChkLo:
  SZ     R5                  ; Skip if R5 is 0... (skip the next instruction)
  BRA    ContinueR11IncLo    ; R5 is not yet 0, so branch to perform an intermediate computation.
  RET    R2                  ; R5 == 0, we are done with this function so RETURN to the call via address stored in R2
ContinueR11IncLo:
  ADDI   R11,#1              ; Each count of R5 represents a single step, so increment R11 by that much.
                             ; NOTE: We can't just do ADD R11,R5 because ADD doesn't handle rollover.
  DEC    R5
  BRA    IncreaseR11ChkLo

;  ORG $1000       ; for testing, easier to know where in RWS(memory) this table is at
BIG_LETTERS:
	db $01  ; $5C  ; $01         ; $2000  index 0   "A" / 0  (0 index is the on-system symbol to use)
	db $00         ;     1 (settings - for use, also keeps the data "even" count)
	db $0C         ;     2 (font row  1)
	db $1E         ;     3 (font row  2)
	db $33         ;     4 (font row  3)
	db $33         ;     5 (font row  4)
	db $3F         ;     6 (font row  5)
	db $3F         ;     7 (font row  6)
	db $33         ;     8 (font row  7)
	db $33         ;     9 (font row  8)
	db $33         ;     A (font row  9)
	db $33         ;     B (font row 10)
	; -----------------------------------------
	db $02  ; $5C  ; $02         ; $200C  index 1   "B" / 12
	db $00         ; setting
	db $3E         ; row1
	db $3E         ; row2
	db $33         ; row3
	db $33         ; row4
	db $3E         ; row5
	db $3E         ; row6
	db $33         ; row7
	db $33         ; row8
	db $3E         ; row9
	db $3E         ; row10
	; -----------------------------------------
	db $03  ; $5C  ; $03         ; $2018  index 2   "C" / 24
	db $00         ; setting
	db $0E
	db $1F
	db $3B
	db $30
	db $30
	db $30
	db $30
	db $3B
	db $1F
	db $0E
	; -----------------------------------------
	db $04  ; $5C  ; $04         ; $2024  index 3   "D"
	db $00         ; setting
	db $3E         ; 1
	db $3E
	db $37         ; 3
	db $33
	db $33         ; 5
	db $33
	db $33         ; 7
	db $37
	db $3E         ; 9
	db $3C
	; -----------------------------------------
	db $05  ; $5C  ; $05         ; $2030  index 4   "E"
	db $00         ; setting
	db $3F
	db $3F         ; 2
	db $30
	db $30         ; 4
	db $3C
	db $3C         ; 6
	db $30
	db $30         ; 8
	db $3F
	db $3F         ; 10
	; -----------------------------------------
	db $06  ; $5C  ; $06         ; $203C  index 5   "F"
	db $00         ; setting
	db $3F  ; 1
	db $3F  ; 2
	db $30  ; 3
	db $30  ; 4
	db $3C  ; 5
	db $3C  ; 6
	db $30  ; 7
	db $30  ; 8
	db $30  ; 9
	db $30  ; 10
	; -----------------------------------------
	db $07  ; $5C  ; $07         ; $2048  index 6   "G"
	db $00  ; setting
	db $1F
	db $3F
	db $30
	db $30
	db $37
	db $37
	db $33
	db $33
	db $3F
	db $1E
	; -----------------------------------------
	db $08  ; $5C  ; $08         ; $2054  index 7   "H"
	db $00  ; setting
	db $33
	db $33
	db $33
	db $33
	db $3F
	db $3F
	db $33
	db $33
	db $33
	db $33
	; -----------------------------------------
	db $09  ; $5C  ; $09         ; $2060  index 8   "I"
	db $00  ; setting
	db $3F
	db $3F
	db $0C
	db $0C
	db $0C
	db $0C
	db $0C
	db $0C
	db $3F
	db $3F
	; -----------------------------------------
	db 56   ; $5C  ; $0A         ; $206C  index 9   "J"  --> m in "PALm"
	db $00  ; setting
	db $FE
	db $FE
	db $06
	db $56
	db $56
	db $76
	db $76
	db $FE
	db $FE
	db $00
	; -----------------------------------------
	db 92   ; $5C  ; $0B         ; $2078  index 10  "K"  --> tail
	db $00  ; setting
	db $FF
	db $FF
	db $DF
	db $DF
	db $EF
	db $EF
	db $F3
	db $FC
	db $FF
	db $FF
	; -----------------------------------------
	db $0C  ; $5C  ; $0C         ; $2084  index 11  "L"
	db $00  ; setting
	db $30
	db $30
	db $30
	db $30
	db $30
	db $30
	db $30
	db $30
	db $3F
	db $3F
	; -----------------------------------------
	db $0D ; $5C  ; $0D         ; $2090  index 12  "M"
	db $00  ; setting
	db $21
	db $33
	db $3F
	db $3F
	db $33
	db $33
	db $33
	db $33
	db $33
	db $33
	; -----------------------------------------
	db $0E  ; $5C  ; $0E         ; $209C  index 13  "N"
	db $00  ; setting
	db $33
	db $33
	db $3B
	db $3B
	db $3F
	db $3F
	db $37
	db $37
	db $33
	db $33
	; -----------------------------------------
	db $0F  ; $5C  ; $0F         ; $20A8  index 14  "O"
	db $00  ; setting
	db $1E
	db $3F
	db $33
	db $33
	db $33
	db $33
	db $33
	db $33
	db $3F
	db $1E
	; -----------------------------------------
	db $10  ; $5C  ; $10         ; $20B4  index 15  "P"
	db $00  ; setting
	db $3E
	db $3F
	db $33
	db $33
	db $3F
	db $3E
	db $30
	db $30
	db $30
	db $30
	; -----------------------------------------
	db 61  ; $5C  ; $11         ; $20C0  index 16  "Q"  --> "?"
	db $00  ; setting
	db $0C
	db $1E
	db $33
	db $33
	db $07
	db $0E
	db $0C
	db $00
	db $0C
	db $0C
	; -----------------------------------------
	db $12  ; $5C  ; $12         ; $20CC  index 17  "R"
	db $00  ; setting
	db $3E
	db $3F
	db $33
	db $33
	db $3E
	db $3F
	db $33
	db $33
	db $33
	db $33
	; -----------------------------------------
	db $13  ; $5C  ; $13         ; $20D8  index 18  "S"
	db $00  ; setting
	db $1E
	db $3F
	db $33
	db $30
	db $3E
	db $1F
	db $03
	db $33
	db $3F
	db $1E
	; -----------------------------------------
	db $14  ; $5C  ; $14         ; $20E4  index 19  "T"
	db $00  ; setting
	db $3F
	db $3F
	db $0C
	db $0C
	db $0C
	db $0C
	db $0C
	db $0C
	db $0C
	db $0C
	; -----------------------------------------
	db $15  ; $5C  ; $15         ; $20F0  index 20  "U"
	db $00  ; setting
	db $33
	db $33
	db $33
	db $33
	db $33
	db $33
	db $33
	db $3F
	db $3F
	db $1E
	; -----------------------------------------
	db 56  ; $5C  ; $16         ; $20FC  index 21  "V"  -->  "m" in (PALm)  [ this is possibly overwriten by DCP, so using "J" index instead ]
	db $00  ; setting  FD
	db $FE
	db $FE
	db $06
	db $56
	db $56
	db $76
	db $76
	db $FE
	db $FE
	db $00
	; -----------------------------------------
	db $17  ; $5C  ; $17         ; $2108  index 22  "W"
	db $00  ; setting
	db $33
	db $33
	db $33
	db $33
	db $33
	db $33
	db $3F
	db $3F
	db $33
	db $21
	; -----------------------------------------
	db $18  ; $5C  ; $18         ; $2114  index 23  "X"
	db $00  ; setting
	db $33
	db $33
	db $1E
	db $1E
	db $0C
	db $0C
	db $1E
	db $1E
	db $33
	db $33
	; -----------------------------------------
	db $19  ; $5C  ; $19         ; $2120  index 24  "Y"
	db $00  ; setting
	db $33
	db $33
	db $33
	db $33
	db $1F
	db $0E
	db $0C
	db $0C
	db $0C
	db $0C
	; -----------------------------------------
	db 92   ; $5C  ; $1A         ; $212C  index 25  "Z"   300
	db $00  ; setting
	db $E0
	db $F0
	db $FC
	db $FE
	db $FF
	db $FC
	db $F3
	db $0E
	db $FC
	db $F0
	; -----------------------------------------
	db 100  ; $5C  ; $52         ; $2138  index 26  "-"  312
	db $00  ; setting
	db $00
	db $00
	db $00
	db $00
	db $3F
	db $3F
	db $00
	db $00
	db $00
	db $00
	; -----------------------------------------
	db $1C  ; $5C  ; $1C         ; $2144  index 27  "1"
	db $00  ; setting
	db $0C
	db $1C
	db $3C
	db $3C
	db $0C
	db $0C
	db $0C
	db $0C
	db $3F
	db $3F
	; -----------------------------------------
	db $1D  ; $5C  ; $1D         ; $2150  index 28  "2"
	db $00  ; setting
	db $1E
	db $3F
	db $33
	db $33
	db $07
	db $0E
	db $1C
	db $38
	db $3F
	db $3F
	; -----------------------------------------
	db $1E  ; $5C  ; $1E         ; $215C  index 29  "3"
	db $00  ; setting
	db $1E
	db $3F
	db $33
	db $03
	db $0E
	db $0E
	db $03
	db $33
	db $3F
	db $1E
	; -----------------------------------------
	db $1F ; $5C  ; $1F         ; $2168  index 30  "4"
	db $00  ; setting
	db $33
	db $33
	db $33
	db $33
	db $3F
	db $3F
	db $03
	db $03
	db $03
	db $03
	; -----------------------------------------
	db $20 ; $5C  ; $20         ; $2174  index 31  "5"
	db $00  ; setting
	db $3F
	db $3F
	db $30
	db $30
	db $3E
	db $3F
	db $03
	db $03
	db $3F
	db $3E
	; -----------------------------------------
	db $21 ; $5C  ; $21         ; $2180  index 32  "6"
	db $00  ; setting
	db $1E
	db $3F
	db $33
	db $30
	db $3E
	db $3F
	db $33
	db $33
	db $3F
	db $1E
	; -----------------------------------------
	db $22  ; $5C  ; $22         ; $218C  index 33  "7"
	db $00  ; setting
	db $3F
	db $3F
	db $03
	db $07
	db $0E
	db $0C
	db $18
	db $18
	db $30
	db $30
	; -----------------------------------------
	db $23  ; $5C  ; $23         ; $2198  index 34  "8"
	db $00  ; setting
	db $1E
	db $3F
	db $33
	db $33
	db $1E
	db $1E
	db $33
	db $33
	db $3F
	db $1E
	; -----------------------------------------
	db $24  ; $5C  ; $24         ; $21A4  index 35  "9"
	db $00  ; setting
	db $1E
	db $3F
	db $33
	db $33
	db $3F
	db $1F
	db $03
	db $03
	db $03
	db $03
	; -----------------------------------------
	db $1B  ; $5C  ; $1B         ; $21B0  index 36  "0"
	db $00  ; setting
	db $1E
	db $3F
	db $33
	db $37
	db $3F
	db $3F
	db $3B
	db $33
	db $3F
	db $1E
	; -----------------------------------------               444
	db $00  ; $5C  ; $00         ; $21BC  index 37  " "
	db $00  ; setting
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
	db $00
  ; 37 options * 12 bytes = 444 bytes              456
	db 92,$00
	db $FF
	db $FF
	db $FF
	db $FF
	db $FF
	db $FE
	db $F1
	db $0F
	db $FF
	db $FF
	db 92,$00          ; 468
	db $FF
	db $FF
	db $C3
	db $BD
	db $7E
	db $FF
	db $FF
	db $FF
	db $FF
	db $FF
	db 92,$00     ; 480
	db $FF
	db $FF
	db $FF
	db $FF
	db $FF
	db $7F
	db $8F
	db $F0
	db $FF
	db $FF
	db 92,$00     ; 492
	db $FF
	db $FF
	db $FC
	db $FB
	db $F7
	db $EF
	db $1F
	db $FF
	db $FF
	db $FF
	db 92,$00     ; 504
	db $FF
	db $FF
	db $3F
	db $DF
	db $EF
	db $F7
	db $F8
	db $FF
	db $FF
	db $FF
	db 45,$00      ; 516
	db $00
	db $00
	db $3C
	db $42
	db $81
	db $00
	db $00
	db $00
	db $00
	db $00
	db 45,$00       ; 528
	db $00
	db $00
	db $00
	db $00
	db $00
	db $80
	db $70
	db $0F
	db $00
	db $00
	db 45,$00        ; 540
	db $00
	db $00
	db $03
	db $04
	db $08
	db $10
	db $E0
	db $00
	db $00
	db $00
	db 45,$00        ; 552
	db $00
	db $00
	db $C0
	db $20
	db $10
	db $08
	db $07
	db $00
	db $00
	db $00
	db 45,$00       ; 564
	db $00
	db $00
	db $00
	db $00
	db $00
	db $01
	db $0E
	db $F0
	db $00
	db $00
	db 56,$00       ; 576   P
	db $3F
	db $3F
	db $31
	db $35
	db $31
	db $37
	db $37
	db $3F
	db $3F
	db $00
	db 56,$00       ; 588  AL
	db $FF
	db $FF
	db $17
	db $57
	db $17
	db $57
	db $51
	db $FF
	db $FF
	db $00
	db 100,$00  ; 600   ::  $36  or 56 (square)
	db $00
	db $1B  ; 0001 1011
	db $1B
	db $00
	db $00
	db $00
	db $00
	db $1B
	db $1B
	db $00
	; backup X since earlier X offset seems to get corrupted by using DCP BR command   612
	db $18  ; $5C  ; $18         ; $2114  index 23  "X"
	db $00  ; setting
	db $33
	db $33
	db $1E
	db $1E
	db $0C
	db $0C
	db $1E
	db $1E
	db $33
	db $33
	
not_used:
  dw  $2CFF

;  ORG $1200            ; for testing
WORKING_ADDRESS:
  dw  0              ; row 1
  dw  0              ; row 2
  dw  0              ; row 3
  dw  0              ; row 4
  dw  0              ; row 5
  dw  0              ; row 6
  dw  0              ; row 7
  dw  0              ; row 8
  dw  0              ; row 9
  dw  0              ; row 10
  ; ------------------------------
WORKING_ADDRESSI:      ; I for "Initial"
  ; Initial calculated WORKING_ADDRESS results are stored here as a redundant copy, 
  ; so we don't have to re-calculate again at the end of a banner display session.	
  dw  0              ; row 1
  dw  0              ; row 2
  dw  0              ; row 3
  dw  0              ; row 4
  dw  0              ; row 5
  dw  0              ; row 6
  dw  0              ; row 7
  dw  0              ; row 8
  dw  0              ; row 9
  dw  0              ; row 10
    
TITLE_STRING:
  ; NOTE: Support for this TITLE_STRING is what pushed the code to be over 2K.
  ; Was about 1800 bytes before this, then 192 bytes is needed for this data.
  ; Resulting in a 2080 byte code + data program size.
  
  ;    1234567890123456789012345678901234567890123456789012345678901234
  ;             1         2         3         4         5         6
  db  "                                                                "
  ;db  00, 00, 82, 82, 83, 83, 54, 54, 54, 59, 59, 59, 70, 74, 85, 41      ; 16
  db  82, 83, 54, 54, 59, 59, 59, 74, 85, 41, 57      ; 11
  
  ; VINTAGE COMPUTER FESTIVAL : SOUTHWEST 2025
  ;        v  i  n  t   a g  e
  db  0,51+UL,53+UL,47+UL,58+UL,102+UL,7+UL,49+UL        ;  8 " vintaGe"  8    v==80   alpha=45
  
  ;        c  o  m  p  u  t  e  r
  db  128,70+UL,59+UL,13+UL,62+UL,66+UL,58+UL,49+UL,18+UL   ; 9

  ;       f  e s  t  i  v  a    l
  ;db  " ",6,49,19,58,53,80,102,48
  db   128,6+UL,49+UL,19+UL,58+UL,53+UL,80+UL,102+UL,48+UL  ; 9
  ;     1234567890123456
  db   " SOUTHWEST 2025 "   ; 16
  ; 29+128,27+128,29+128,32+128,128         ; " 2025 " underscored
  
  ; db  " COMPUTER FESTIVAL 2025 "  ; 24
  ;db  " VINTAGE COMPUTER FESTIVAL 2025 "  ; 32
  ;db  42, 86, 78, 68, 59, 59, 59, 54, 54, 54, 83, 83, 82, 82, 00, 00      ; 16
  db  57, 42, 86, 78, 59, 59, 59, 54, 54, 83, 82      ; 11
  
;  -  -  d  d   o  o  o  O    O  O   u   < (   [    ]  )   >  u  O  O  O  o  o  o  d  d  -  -
;  82 82 83 83 54 54 54  59  59 59  70  74 85 41   42  86 78 68  59 59 59 54 54 54 83 83 82 82

  
  ; db  "  VCF SOUTHWEST - JUNE 20-22, 2025 - TEXAS - HOWDY YA'LL !!!    "
  db  "                                                                ", NULL_TERM, 0
  ; NOTE: The extra 0 above is to ensure the db aligns onto a word (even address)
TITLE_STRING_TEMP:
  dw  0   ; used to store working-address index into the TITLE_STRING 
  
  ORG $0E00   
; This data is set to a fixed address to make it easier to modify the .bin later in a hex editor,
; so users can custom define their own big_letter banner sequences.
; NOTE: We can add about 12 more big_letter bitmaps before we impact the $0E00 address.
; The assembler will fill this gap with 0xFF values.

BANNER_LEN:  ; Include any flanking spaces at beginning and end (but do not include the NULL_TERM).
  ; While we could programmatically find the end of the string, this is encoded as
  ; a constant for convenience (less code size and saves some runtime at startup).
  ; Memory used will be ThisValue * 8 * 10
  ; Example: Full 255 character  string would be 255*8*10  = 20400 byt (abou20KB)
  ;          An 80 character string would be 80*8*10 = 6400 bytes (about 6KB)
  ;db  9   ; initial test message
  db   141
  db   0   ; keep word alignment  

BANNER_STRING:  ; a short string to scroll
  ; Initial test message:
  ; _AB2VCFF_
  ;dw    $01BC,    0,   12, $150,  252,   24,   60,   60,$01BC,NULL_TERM_W
  ;            $0000,$000C,$0150,$00FC,$0018,$003C,$003C

  ;                                                                                                    1         1         1         1         1
  ;          1         2         3         4         5         6         7         8         9         0         1         2         3         4
  ; 1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
  ; ________VCF DALLAS 2025 - IBM 5100 SCROLLER BY XIPHOD }----------{ GREETS TO CORTI-STEPLETON-SNUCI-TITOR - PALM 1972 - EL PSY KONGROO________
  ; ________IBM 5100 SCROLLER BY XIPHOD 6789A6789ABCj1972 _1234512345z6789A GREETS 8BG:USAGI:LGR:?MARC:TRIXTER - HELLO DALLAS:FORT WORTH________
  ;                                                 J     K          Z                           Q             
  ;         ABCDEFGHI   M OP RSTU  XY
  ;                  jkl n  q    vw  z
  
  
  dw  $01BC,$01BC,$01BC,$01BC,$01BC,$01BC,$01BC,$01BC                                     ; 8 SPACES (8x8 = 64) HEADER
  ; ----
  dw  $0060,$000C,$0090,$01BC,$0174,$0144,$01B0,$01B0,$01BC  ; "IBM 5100 "                ; 9  
  dw  $00D8,$0018,$00CC,$00A8,$0084,$0084,$0030,$00CC,$01BC  ; "SCROLLER "                ; 9
  dw  $000C,$0120,$01BC,$0264,$0060,$00B4,$0054,$00A8,$0024,$01BC  ; "BY XIPHOD "         ; 10
  dw  516,528,540,552,564                                         ; 6789A                 ; 5
  dw  516,528,540,552,564                                         ; 6789A                 ; 5
  dw  576,588,108                                                 ; BCj                   ; 3  PALM
  dw  $0144,$01A4,$018C,$0150,$01BC                               ; "1972 "               ; 5  
  dw  120,456,468,480,492,504,456,468,480,492,504,300    ; K1234512345z                   ; 12
  dw  516,528,540,552,564,516,518                        ; "6789A67"                       ; 7
  dw  $0048,$00CC,$0030,$0030,$00E4,$00D8,$01BC          ; "GREETS "                      ; 7
  dw  408,12,72, 600                                     ; 8BG:                           ; 4
  dw  240,216,0,72,96,600                                ; USAGI:                         ; 6
  dw  132,72,204,600                                     ; LGR:                           ; 4
  dw  192,144,0,204,24,600                               ; ?MARC:                         ; 6
  dw  228,204,96,276,228,48,204                          ; TRIXTER                        ; 7
  dw  $01BC,312,$01BC                                    ; " - "                          ; 3
  dw  84,48,132,132,168,$01BC                            ; "HELLO "                       ; 6
  dw  36,0,132,132,0,216,600                             ; "DALLAS:"                      ; 7
  dw  60,168,204,228,$01BC,264,168,204,228,84            ; "FORT WORTH"                   ; 10    
  ; ----
  dw  $01BC,$01BC,$01BC,$01BC,$01BC,$01BC,$01BC,$01BC                                     ; 8 SPACES (8x8 = 64) FOOTER
  dw  NULL_TERM_W

