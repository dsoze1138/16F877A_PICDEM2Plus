; -------------------------
; LCD functions
; -------------------------
;
#define LCD_ASM
#include "main.inc"
#include "lcd.inc"
;
; This code assumes a oscillator of 4MHz
;
; The the fastest oscillator a PIC16F877A can use is 20MHz.
;
; When USE_FAST_CLOCK is defined the delays are adjusted
; for a 20MHz oscillator.
;
;#define USE_FAST_CLOCK
#ifdef USE_FAST_CLOCK
#define DELAY_FOR_FAST_CLOCK  call DelayFor18TCY
#else
#define DELAY_FOR_FAST_CLOCK
#endif
;
; This RAM is used by the LCD interface routines.
;
LCD_DATA    UDATA_SHR
LCD_byte    res     1       ; byte sent to or read from LCD
LCD_BusyBit res     1       ; Mask of where the BUSY bit is located
pszLCD_RomStr res   2       ; pointer to ASCIIZ string in ROM

LCD_CODE code

; DelayFor18TCY() provides a 18 Tcy delay
DelayFor18TCY:
    goto    DelayFor16TCY

; DelayXLCD() provides at least 5ms delay
DelayXLCD:
;
; If we are using a fast clock make
; the delays work for a 20MHz clock.
;
#ifdef USE_FAST_CLOCK
    call    DXLCD0
    call    DXLCD0
    call    DXLCD0
    call    DXLCD0
#endif

DXLCD0:
    goto    $+1
    goto    $+1
    movlw   d'249'
DXLCD1:
    call    DelayFor16TCY
    addlw   -1
    bnz     DXLCD1
DelayFor16TCY:
    goto    $+1
    goto    $+1
    goto    $+1
    goto    $+1
    goto    $+1
    goto    $+1
    return

; DelayPORXLCD() provides at least 15ms delay
DelayPORXLCD:
    call    DelayXLCD
    call    DelayXLCD
    goto    DelayXLCD
;
; Function Name:  BusyXLCD
; Return Value:   W = Not zero when status of LCD controller is busy
; Parameters:     void
; Description:    This routine reads the busy status of the
;                 Hitachi HD44780 LCD controller.
; Notes:
;  The busy bit is not reported in the same nibble
;  on all HD44780 "compatible" controllers.
;  If you have a Novatek 7605 type controller some
;  versions report these nibbles in reverse order.
;
;  This code has been tested with a Novatek 7605
;  and the real Hitachi HD44780.
;
BusyXLCD:
    movf    LCD_BusyBit,F   ; Check if busy bit avaliable.
    bz      DelayPORXLCD    ; Use a 15ms delay when busy not available.

    bcf     RS_PIN
    bsf     RW_PIN

    bcf     E_PIN
    DELAY_FOR_FAST_CLOCK
    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK

    btfsc   LCD_BusyBit,7
    movf    LCD_PORT,W      ; The standard LCD returns the BUSY flag first

    bcf     E_PIN
    DELAY_FOR_FAST_CLOCK
    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK

    btfsc   LCD_BusyBit,3
    movf    LCD_PORT,W      ; A Non standard LCD returns the BUSY flag second

    bcf     E_PIN
    andlw   (LCD_DATA_BITS&(~LCD_DATA_BITS>>1))
    bnz     BusyXLCD
    return
;
; Send a byte to LCD using 4-bit mode
BytePutLCD:
    banksel BANK1
    movlw   ~LCD_DATA_BITS
    andwf   LCD_PORT,F      ; Make LCD port bits outputs
    banksel BANK0
    andwf   LCD_PORT,F      ; Make LCD port bits zero

#ifdef LCD_DATA_ON_HIGH_4_BITS
    swapf   LCD_byte,F
#endif

    bcf     RW_PIN
;
; send first 4-bits
    swapf   LCD_byte,W
    andlw   LCD_DATA_BITS
    iorwf   LCD_PORT,F
    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK
    bcf     E_PIN
;
; send second 4-bits
    xorwf   LCD_byte,W
    andlw   LCD_DATA_BITS
    xorwf   LCD_PORT,F
    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK
    bcf     E_PIN

; set data bits for input
    banksel BANK1
    movlw   LCD_DATA_BITS
    iorwf   LCD_PORT,F
    banksel BANK0
    movf    LCD_byte,W
    return
;
; Read a byte to LCD using 4-bit mode
ByteGetLCD:
    bsf     RW_PIN
;
; read first 4-bits
    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK
    movf    LCD_PORT,W
    bcf     E_PIN
    andlw   LCD_DATA_BITS
    movwf   LCD_byte
;
; read second 4-bits
    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK
    movf    LCD_PORT,W
    bcf     E_PIN
    andlw   LCD_DATA_BITS
    swapf   LCD_byte,F
    iorwf   LCD_byte,F
    movf    LCD_byte,W
#ifdef LCD_DATA_ON_HIGH_4_BITS
    swapf   LCD_byte,F
#endif
    return
;
; Function Name:  SetCGRamAddr
; Return Value:   void
; Parameters:     W = character generator ram address
; Description:    This routine sets the character generator
;                 address of the Hitachi HD44780 LCD
;                 controller.
;
SetCGRamAddr:
    iorlw   0x40            ; Write cmd and address to port
    movwf   LCD_byte        ; save byte going to LCD

    call    BusyXLCD

    bcf     RS_PIN
    goto    BytePutLCD

;
; Function Name:  SetDDRamAddr
; Return Value:   void
; Parameters:     W = display data address
; Description:    This routine sets the display data address
;                 of the Hitachi HD44780 LCD controller.
;
SetDDRamAddr:
    iorlw   0x80            ; Write cmd and address to port
    movwf   LCD_byte        ; save byte going to LCD

    call    BusyXLCD

    bcf     RS_PIN
    goto    BytePutLCD
;
; Function Name:  WriteCmdXLCD
; Return Value:   void
; Parameters:     W = command to send to LCD
; Description:    This routine writes a command to the Hitachi
;                 HD44780 LCD controller.
;
WriteCmdXLCD:
    movwf   LCD_byte        ; save byte going to LCD

    call    BusyXLCD

    bcf     RS_PIN
    goto    BytePutLCD
;
; Function Name:  WriteDataXLCD
; Return Value:   void
; Parameters:     W = data byte to be written to LCD
; Description:    This routine writes a data byte to the
;                 Hitachi HD44780 LCD controller. The data
;                 is written to the character generator RAM or
;                 the display data RAM depending on what the
;                 previous SetxxRamAddr routine was called.
;
WriteDataXLCD:
    movwf   LCD_byte        ; save byte going to LCD

    call    BusyXLCD

    bsf     RS_PIN
    call    BytePutLCD
    bcf     RS_PIN
    return
;
; Function Name:  OpenXLCD
; Return Value:   void
; Parameters:     none
; Description:    This routine configures the LCD. Based on
;                 the Hitachi HD44780 LCD controller. The
;                 routine will configure the I/O pins of the
;                 microcontroller, setup the LCD for 4-bit
;                 mode and clear the display.
;
OpenXLCD:
    clrf    LCD_BusyBit
    banksel BANK1
    movlw   ~LCD_DATA_BITS
    andwf   LCD_PORT,F      ; Make LCD data bus an output
    bcf     E_PIN           ; Make LCD data enable strobe an output
    bcf     RW_PIN          ; Make LCD Read/Write select an output
    bcf     RS_PIN          ; Make LCD Register select an output
    bcf     LCD_POWER_EN    ; Make LCD power enable an output
    banksel BANK0
    andwf   LCD_PORT,F      ; Drive all LCD pins low
    bcf     E_PIN
    bcf     RW_PIN
    bcf     RS_PIN
    bsf     LCD_POWER_EN    ; Turn on LCD power

    call    DelayPORXLCD    ; Wait for LCD to complete power on reset

    movlw   b'00000011'     ; force LCD into 8-bit mode
    iorwf   LCD_PORT,F
    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK
    bcf     E_PIN
    call    DelayXLCD       ; Required 5ms delay

    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK
    bcf     E_PIN
    call    DelayXLCD       ; minimum 100us delay but use 5ms

    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK
    bcf     E_PIN
    call    DelayXLCD       ; minimum 100us delay but use 5ms

    movlw   b'00000010'     ; set LCD into 4-bit mode
    xorwf   LCD_PORT,W
    andlw   LCD_DATA_BITS
    xorwf   LCD_PORT,F
    bsf     E_PIN
    DELAY_FOR_FAST_CLOCK
    bcf     E_PIN
    call    DelayXLCD

    banksel BANK1
    movlw   LCD_DATA_BITS   ; Make LCD data pins inputs
    iorwf   LCD_PORT,F
    banksel BANK0

    movlw   (FOUR_BIT&LINES_5X7)
    call    WriteCmdXLCD

    movlw   (DOFF & CURSOR_OFF & BLINK_OFF)
    call    WriteCmdXLCD

    movlw   (DON & CURSOR_OFF & BLINK_OFF)
    call    WriteCmdXLCD

    movlw   (0x01)          ; Clear display
    call    WriteCmdXLCD

    movlw   (SHIFT_CUR_LEFT)
    call    WriteCmdXLCD
;
; Find position of busy bit
; Required when using 4-bit mode.
;
    movlw   LINE_ONE+1
    call    SetDDRamAddr

    call    BusyXLCD
    bcf     RS_PIN
    call    ByteGetLCD
    xorlw   0x01
    skpnz
    bsf     LCD_BusyBit,7
    xorlw   0x11
    skpnz
    bsf     LCD_BusyBit,3
;
; Initialize CGRAM
;
    clrw
    call    SetCGRamAddr
    banksel EEADR
    movlw   LOW(CGRAM_Table)
    movwf   EEADR
    movlw   HIGH(CGRAM_Table)
    movwf   EEADRH
    call    putrsXLCD_loop
;
; Put cursor on line one, left most position
;
    movlw   LINE_ONE
    call    SetDDRamAddr

    return
;
; Function Name:  PutHexXLCD
; Return Value:   void
; Parameters:     W = 8-bit value to send to LCD
; Description:    Writes two ASCII character of the
;                 hexadecimal value in thw W register.
;
PutHexXLCD:
        movwf   pszLCD_RomStr
        swapf   pszLCD_RomStr,W
        call    PutHexNibbleXLCD
        movf    pszLCD_RomStr,W
PutHexNibbleXLCD:
        andlw   0x0F
        addlw   0x06
        btfsc   STATUS,DC
        addlw   'A'-'0'-d'10'
        addlw   '0'-d'6'
        call    WriteDataXLCD
        movf    pszLCD_RomStr,W
        return
;
; Function Name:  PutDecXLCD
; Return Value:   void
; Parameters:     W = 8-bit value to send to LCD
; Description:    Writes three ASCII character of the
;                 decimal value in thw W register.
;
PutDecXLCD:
        clrf    pszLCD_RomStr+1

        addlw   d'256'-d'200'
        skpnc
        bsf     pszLCD_RomStr+1,1
        skpc
        addlw   d'200'

        addlw   d'256'-d'100'
        skpnc
        bsf     pszLCD_RomStr+1,0
        skpc
        addlw   d'100'

        movwf   pszLCD_RomStr       ; save output value less than 100

        movlw   0x1F
        andwf   pszLCD_RomStr+1,W
        bsf     pszLCD_RomStr+1,5
        skpz
        bsf     pszLCD_RomStr+1,4
        movf    pszLCD_RomStr+1,W
        btfsc   pszLCD_RomStr+1,4
        call    WriteDataXLCD       ; output 100's digit
        movlw   0x10
        andwf   pszLCD_RomStr+1,F

        movf    pszLCD_RomStr,W
        addlw   d'256'-d'80'
        skpnc
        bsf     pszLCD_RomStr+1,3
        skpc
        addlw   d'80'

        addlw   d'256'-d'40'
        skpnc
        bsf     pszLCD_RomStr+1,2
        skpc
        addlw   d'40'

        addlw   d'256'-d'20'
        skpnc
        bsf     pszLCD_RomStr+1,1
        skpc
        addlw   d'20'

        addlw   d'256'-d'10'
        skpnc
        bsf     pszLCD_RomStr+1,0
        skpc
        addlw   d'10'
        movwf   pszLCD_RomStr

        movlw   0x1F
        andwf   pszLCD_RomStr+1,W
        bsf     pszLCD_RomStr+1,5
        skpz
        bsf     pszLCD_RomStr+1,4
        movf    pszLCD_RomStr+1,W
        btfsc   pszLCD_RomStr+1,4
        call    WriteDataXLCD       ; output 10's digit
        movlw   '0'
        addwf   pszLCD_RomStr,W
        call    WriteDataXLCD       ; output 1's digit
        return
;
; Function Name:  putrsXLCD
; Return Value:   void
; Parameters:     WREG - string selector, range 0 to 255
; Description:    This routine writes a string of bytes to the
;                 Hitachi HD44780 LCD controller. The data
;                 is written to the character generator RAM or
;                 the display data RAM depending on what the
;                 previous SetxxRamAddr routine was called.
;
putrsXLCD:
        banksel EEADR
        movwf   EEADR           ; Store offset to string pointer 
        movlw   LOW(TableOfStringPointers)
        addwf   EEADR,F         ; Add string table bas address to ofset
        movlw   HIGH(TableOfStringPointers)
        btfsc   STATUS,C        ; Check for carry to high 8-bits
        addlw   1
        movwf   EEADRH
        banksel EECON1
        bsf     EECON1,EEPGD    ; Read 14-bit pointer to string in CODE space
        bsf     EECON1,RD
        nop
        nop
        banksel EEDATA
        movf    EEDATA,W        ; Move low byte of pointer to EEROM address register
        movwf   EEADR
        movf    EEDATH,W        ; Move high byte of pointer to EEROM address register
        movwf   EEADRH

putrsXLCD_loop:
        banksel EECON1
        bsf     EECON1,EEPGD    ; Read 14-bit CODE space word of ASCII 128 string
        bsf     EECON1,RD
        nop
        nop
        banksel EEDATA
        movf    EEDATA,W
        movwf   pszLCD_RomStr   ; Store low 8-bits of word
        movf    EEDATH,W
        movwf   pszLCD_RomStr+1 ; Store high 6-bits of word
        incf    EEADR,F         ; Increment EEROM pointer
        skpnz
        incf    EEADRH,F
        banksel BANK0
        rlf     pszLCD_RomStr,W ; Set CARRY to MSB of low 8-bits
        iorwf   pszLCD_RomStr+1,W
        skpnz                   ; Skip if the 14-bit word is non-zero
        return
        movf    pszLCD_RomStr+1,W
        skpz                    ; Skip if high 6-bits are zero
        bcf     pszLCD_RomStr,7
        rlf     pszLCD_RomStr+1,F ; unpack first ASCII 128 character
        bcf     pszLCD_RomStr+1,7
        movf    pszLCD_RomStr+1,W
        skpz                    ; Skip if character is zero
        call    WriteDataXLCD   ; Send all non-zero characters to the display
        movf    pszLCD_RomStr,W
        skpz                    ; Skip if character is zero
        call    WriteDataXLCD   ; Send all non-zero characters to the display
        goto    putrsXLCD_loop

;
; This table is used to write
; default characters to the
; Character Generator RAM of
; the LCD module.
;
LCD_CONST   code
CGRAM_Table:
    dw      B'10000001001000' ; CGRAM character 1
    dw      B'10001001001110'
    dw      B'10001001001000'
    dw      B'10000001011111'

    dw      B'10011101010001' ; CGRAM character 2
    dw      B'10100001010000'
    dw      B'10100011001110'
    dw      B'10000001011111'

    dw      B'10011101010001' ; CGRAM character 3
    dw      B'10100001010011'
    dw      B'10100011001110'
    dw      B'10000001011111'

    dw      B'10000001001110' ; CGRAM character 4
    dw      B'10010101001010'
    dw      B'10011101000000'
    dw      B'10000001011111'

    dw      B'10111101010001' ; CGRAM character 5
    dw      B'10100011011110'
    dw      B'10100101010001'
    dw      B'10000001011111'

    dw      B'10011101010001' ; CGRAM character 6
    dw      B'10100011011111'
    dw      B'10100011010001'
    dw      B'10000001011111'

    dw      B'10100011011011' ; CGRAM character 7
    dw      B'10101011010101'
    dw      B'10100011010001'
    dw      B'10000001011111'

    dw      B'10000001000010' ; CGRAM character 8
    dw      B'10001001001110'
    dw      B'10001001000010'
    dw      B'10000001011111'

    dw      B'00000000000000' ; End of table marker

    end
