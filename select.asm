;Copyright 2019 Jason Justian
;
;Author: Jason Justian (jjustian@gmail.com)
;
;Permission is hereby granted, free of charge, to any person obtaining a copy
;of this software and associated documentation files (the "Software"), to deal
;in the Software without restriction, including without limitation the rights
;to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;copies of the Software, and to permit persons to whom the Software is
;furnished to do so, subject to the following conditions:
;
;The above copyright notice and this permission notice shall be included in
;all copies or substantial portions of the Software.
;
;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
;THE SOFTWARE.
;
;See http://creativecommons.org/licenses/MIT/ for more information.
;
;-----------------------------------------------------------------------------
;
;BASIC program selector
;
;Divides BASIC RAM into six banks of configurable size. This version of the
;appliation is designed for a PC-1500A with the 16K expansion.
;

;System calls and pointers
write:ED4D              ;write one character and advance cursor
getkey:E243             ;wait for a key to be pressed
cursor:7875             ;cursor position
pstart:7865             ;pointer to start of BASIC program
phead:7869              ;pointer to start of BASIC editing
pend:7867               ;pointer to end of BASIC program

select:
8E 19                   BCH menu        ;Skip over the storage...

00          current                     ;Currently-selected bank

;Bank starting addresses
18 00       b1start                     ;2K bank, starting here to leave ~6K for ML
20 00       b2start                     ;2K
28 00       b3start                     ;2K
30 00       b4start                     ;2K
38 00       b5start                     ;2K
40 00       b6start                     ;About 4K

;Bank ending addresses (populated at each bank is left)
18 00       b1end
20 00       b2end
28 00       b3end
30 00       b4end
38 00       b5end
40 00       b6end

menu:
B5 00                   LDI A,00        ;Set cursor to the left edge
AE 78 75                STA cursor
B5 20                   LDI A,' '
BE ED 4D                SJP write       ;Write a space
4A 00                   LDI XL,00       ;Initialize XL as the program bank key

bank:
04                      LDA XL
FD 88                   PSH X           ;Because write does unspeakable things to XL
FD C8                   PSH A           ;So we can use it for drawing characters
48 20                   LDI XH,' '      ;Use a space...
A7 01 02                CPA,(current)   ;...unless we're at the current bank...
89 02                   BZR +2
48 2A                   LDI XH,'*'      ;...in which case, show an indicator
84                      LDA XH
BE ED 4D                SJP write       ;Write a space or indicator
FD 8A                   POP A
B3 31                   ADI A,31        ;Convert function key number to ASCII numeral
BE ED 4D                SJP write       ;Write the numeral
B5 20                   LDI A,' '
BE ED 4D                SJP write       ;Write a space
BE ED 4D                SJP write       ;Write a space
FD 0A                   POP X           ;Return XL's iterator status

next:
40                      INC XL          ;Move to the next program bank key
4E 06                   CPI XL,06       ;Are all six slots drawn?
99 28                   BZR item        ;If not, go back
        
input:
BE E2 43                SJP getkey      ;Scan keyboard until key is pressed
                                        ;Selection is in Accumulator:
                                        ;    Bank 1 = 11 (Fn1)
                                        ;    Bank 2 = 12 (Fn2)
                                        ;    Bank 3 = 13 (Fn3)
                                        ;    Bank 4 = 14 (Fn4)
                                        ;    Bank 5 = 15 (Fn5)
                                        ;    Bank 6 = 16 (Fn6)
B7 11                   CPI A,11
83 01                   BCS +1          ;Carry set means "not less," so go on
9A                      RTN             ;Exit if keypress is less than 11 (Fn1)
B7 17                   CPI A,17
81 01                   BCR switch      ;Carry clear means "less", which is good
9A                      RTN             ;Exit if keypress is greater than 16 (Fn6)

switch:
FB                      SEC             ;Set carry flag for substraction
B1 11                   SBI A,11        ;Subtract the first keycode to get the bank
F9                      REC             ;Reset carry flag for rotate
DB                      ROL             ;Double the accumulator by rotating left,
                                        ;so that we can deal with 16-bit addresses.

                                        ;Now we have the bank memory index in A, and need
                                        ;to perform the following tasks in order:
                                        ;
                                        ;(1) Store the end of the current program
                                        ;    (pend) at the current bank's 'bNend'
                                        ;    pointer
                                        ;(2) Copy the start location from the new
                                        ;    bank's 'bNstart' pointer to the
                                        ;    pstart pointer
                                        ;(3) Copy the end location from the new bank's
                                        ;    'bNend' pointer to the pend pointer
                                        ;(4) Set the current location to the new
                                        ;    bank number
                                        

;Store the end of the current program in the bank's bNend pointer
FD C8                   PSH A
A5 01 02                LDA (current)
F9                      REC             ;Reset carry flag for rotate
DB                      ROL             ;Set the memory index for the current bank
58 01                   LDI YH, 01      ;Y will be the destination for the bNend
5A 0F                   LDI YL, 0F
FD DA                   ADR Y           ;The LSB is low enough not to worry about carry
A5 78 67                LDA (pend)
1E                      STA (Y)
54                      INC Y
A5 78 68                LDA (pend+1)
1E                      STA (Y)
FD 8A                   POP A           ;A is the memory index again

;Copy the start location from the new bank's bNstart pointer to the pstart pointer
FD C8                   PSH A
58 01                   LDI YH, 01      ;Y will be the source for the pstart
5A 03                   LDI YL, 03
FD DA                   ADR Y
15                      LDA (Y)
AE 78 65                STA (pstart)
AE 78 69                STA (phead)
54                      INC Y
15                      LDA (Y)
AE 78 66                STA (pstart+1)
AE 78 6A                STA (phead+1)
FD 8A                   POP A

;Copy the end location from the new bank's bNend pointer to the pend pointer
FD C8                   PSH A
58 01                   LDI YH, 01      ;Y will be the source for the bNend
5A 0F                   LDI YL, 0F
FD DA                   ADR Y
15                      LDA (Y)
AE 78 67                STA (pend)
54                      INC Y
15                      LDA (Y)
AE 78 68                STA (pend+1)
FD 8A                   POP A

;Set the current location to the new bank number
F9                      REC             ;Reset carry flag for rotate
D1                      ROR
AE 01 02                STA (current)
9E 91                   BCH menu
