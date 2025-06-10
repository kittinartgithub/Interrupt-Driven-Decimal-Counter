.include "m328pdef.inc"
.device ATMEGA328P  
.cseg
.def TMP = R17         ; ตัวแปรชั่วคราว
.def COUNT = R19     ; ตัวนับค่า
.def INPUTC = R20     ; เก็บค่าอินพุตจาก PORTC
.def DELAYS = R29     ; ตัวแปรสำหรับดีเลย์
.def ZERO = R28        ; ค่าศูนย์
.def ADD_COUNT = R15  ; ค่าที่ใช้เพิ่มตัวนับ

.org 0x0000
    rjmp START        ; เริ่มต้นโปรแกรม
.org 0x0008
    rjmp PinChangeInt1 ; จัมพ์ไปยัง Interrupt handler

START:
    ; กำหนดค่า Pin Change Interrupt PCINT1
    ldi TMP, 0x02         ; เปิดใช้งาน PCINT1
    ldi ZL, low(PCICR)    ; โหลดแอดเดรสล่างของ PCICR
    ldi ZH, high(PCICR)   ; โหลดแอดเดรสสูงของ PCICR
    st Z, TMP             ; เก็บค่าใน PCICR
    ldi TMP, 0x0F         ; เปิดใช้งานทุกพินใน PCINT1
    ldi ZL, low(PCMSK1)   ; โหลดแอดเดรสล่างของ PCMSK1
    ldi ZH, high(PCMSK1)  ; โหลดแอดเดรสสูงของ PCMSK1
    st Z, TMP             ; เก็บค่าใน PCMSK1
    
    ; กำหนดทิศทางพอร์ต
    ldi TMP, 0b01110000   ; กำหนด PORTC บิต 4-6 เป็น output
    out DDRC, TMP         ; ตั้งค่า DDRC (PC0-PC3 เป็น input)
    ldi TMP, 0b11111000   ; กำหนด PORTD บิต 3-7 เป็น output
    out DDRD, TMP         ; ตั้งค่า DDRD (PD0-PD2 เป็น input)
    ldi TMP, 0b00111111   ; กำหนด PORTB บิต 0-5 เป็น output
    out DDRB, TMP         ; ตั้งค่า DDRB (PB0-PB5 เป็น output)
    sei                   ; เปิดใช้งาน global interrupt
    
    ; เริ่มต้นค่าพอร์ต
    ldi TMP, 0b11000000   ; ค่าเริ่มต้นสำหรับ PORTD
    out PORTD, TMP        ; ตั้งค่า PORTD
    ldi TMP, 0b00000000   ; ค่าเริ่มต้นสำหรับ PORTB
    out PORTB, TMP        ; ตั้งค่า PORTB
    
    ; เริ่มต้นตัวแปร
    clr R25               ; ล้างค่า R25
    clr COUNT             ; ตั้งค่า COUNT เป็น 0
    rcall RESET_DELAY     ; รีเซ็ตค่าดีเลย์
    ldi TMP, 1            ; โหลดค่า 1
    mov ADD_COUNT, TMP    ; ตั้งค่า ADD_COUNT = 1 

MAIN_LOOP:  
    ; อ่านค่าจาก PORT C
    in INPUTC, PINC       ; อ่านค่า PINC
    andi INPUTC, 0x0F     ; เก็บเฉพาะ 4 บิตล่าง
    cpse INPUTC, ZERO     ; ถ้า INPUTC ไม่เท่ากับศูนย์ ข้ามคำสั่งถัดไป
    dec INPUTC            ; ลดค่า INPUTC ลง 1
    inc INPUTC            ; เพิ่มค่า INPUTC ขึ้น 1

    ; แสดงผลบน 7-Segment
    mov R16, COUNT        ; เตรียมค่าสำหรับแปลงเป็น BCD
    rcall BINARY2BCD      ; แปลงเป็น BCD
    mov R18, R26          ; เตรียมค่าสำหรับแยกหลัก
    rcall UNPACK_BCD      ; แยกหลัก (R27=หลักร้อย, R26=หลักสิบและหน่วย)
    rcall PREPARE_DISPLAY ; เตรียมข้อมูลสำหรับแสดงผล
    rcall DISP_7SEG       ; แสดงผลบน 7-Segment

    ; เพิ่มค่าตัวนับ
    add COUNT, ADD_COUNT  ; เพิ่มค่า COUNT
    cpi COUNT, 0x29       ; เปรียบเทียบกับ 41 (0x29)
    brcs MAIN_LOOP        ; ถ้า COUNT < 41 กลับไป MAIN_LOOP
    ldi COUNT, 0          ; รีเซ็ต COUNT เป็น 0
    rjmp MAIN_LOOP        ; กลับไป MAIN_LOOP

PREPARE_DISPLAY:  
    mov R25, R30          ; เตรียมหลักหน่วย
    rcall BIN_TO_7SEG     ; แปลงเป็นรหัส 7-Segment
    mov R30, R25          ; เก็บรหัส 7-Segment ของหลักหน่วย
    mov R25, R31          ; เตรียมหลักสิบ
    rcall BIN_TO_7SEG     ; แปลงเป็นรหัส 7-Segment
    mov R31, R25          ; เก็บรหัส 7-Segment ของหลักสิบ
    mov R25, R27          ; เตรียมหลักร้อย
    rcall BIN_TO_7SEG     ; แปลงเป็นรหัส 7-Segment
    mov R27, R25          ; เก็บรหัส 7-Segment ของหลักร้อย
    ret

DISP_DIGI001:  
    mov OUTPUT7SEG, R30           ; โหลดรหัส 7-Segment หลักหน่วย
    out PORTB, OUTPUT7SEG         ; ส่งข้อมูลส่วน a-f ไปที่ PORTB
    andi OUTPUT7SEG, 0b11000000   ; เก็บเฉพาะบิต 6-7
    ori OUTPUT7SEG, 0b00100000    ; ตั้งค่า PD5 เป็น 1 เพื่อเลือกหลักหน่วย
    out PORTD, OUTPUT7SEG         ; ส่งข้อมูลส่วน g,dp ไปที่ PORTD
    ret

DISP_DIGI010:  
    mov OUTPUT7SEG, R31           ; โหลดรหัส 7-Segment หลักสิบ
    out PORTB, OUTPUT7SEG         ; ส่งข้อมูลส่วน a-f ไปที่ PORTB
    andi OUTPUT7SEG, 0b11000000   ; เก็บเฉพาะบิต 6-7
    ori OUTPUT7SEG, 0b00010000    ; ตั้งค่า PD4 เป็น 1 เพื่อเลือกหลักสิบ
    out PORTD, OUTPUT7SEG         ; ส่งข้อมูลส่วน g,dp ไปที่ PORTD
    ret

DISP_7SEG:  
    ; แสดงผลด้วยการมัลติเพล็กซ์
START_LOOP:
    rcall DISP            ; แสดงผลทั้งหลักหน่วยและหลักสิบ
    cpi DELAYS, 34        ; ตรวจสอบค่าดีเลย์
    breq END_LOOP         ; ถ้าครบแล้วจบลูป
    inc DELAYS            ; เพิ่มค่าดีเลย์
    rjmp START_LOOP       ; วนลูปต่อ
END_LOOP:
    rcall RESET_DELAY     ; รีเซ็ตค่าดีเลย์
    ret

DISP:
    rcall DISP_DIGI001    ; แสดงผลหลักหน่วย
    rcall DELAY10MS       ; หน่วงเวลา
    rcall DISP_DIGI010    ; แสดงผลหลักสิบ
    rcall DELAY10MS       ; หน่วงเวลา
    ret

RESET_DELAY:
    ldi DELAYS, 0         ; รีเซ็ตค่าดีเลย์
    ret
; ฟังก์ชันหารเลข 8 บิต
.def DIVISOR = R21        ; ตัวหาร
.def DIVIDEND = R22       ; ตัวตั้ง
.def QUOTIENT = R23       ; ผลหาร
.def REMAINDER = R24      ; เศษ
DIVIDE8BIT:
    sub QUOTIENT, QUOTIENT    ; ล้างค่า QUOTIENT
D_LOOP:
    sub DIVIDEND, DIVISOR     ; ตัวตั้ง = ตัวตั้ง - ตัวหาร
    brcc INC_QUO              ; ถ้าไม่มี Carry ไปที่ INC_QUO
    add DIVIDEND, DIVISOR     ; เพิ่มตัวหารกลับไป (แก้ไขค่า)
    rjmp END_DIV              ; ไปที่ END_DIV
INC_QUO:
    inc QUOTIENT              ; เพิ่มค่า QUOTIENT
    rjmp D_LOOP               ; วนลูปต่อ
END_DIV:
    mov REMAINDER, DIVIDEND   ; เก็บเศษไว้ใน REMAINDER
    ret

; แปลงเลขฐานสองเป็น BCD
.def IN_BINARY = R16          ; ค่าไบนารีที่ต้องการแปลง
.def OP_LOW = R26             ; ผลลัพธ์ BCD หลักหน่วยและสิบ
.def OP_HI = R27              ; ผลลัพธ์ BCD หลักร้อย
BINARY2BCD:
    push R21                  ; เก็บค่า R21 ไว้ในสแต็ก
    push R22                  ; เก็บค่า R22 ไว้ในสแต็ก
    push R23                  ; เก็บค่า R23 ไว้ในสแต็ก
    push R24                  ; เก็บค่า R24 ไว้ในสแต็ก
    ldi OP_LOW, 0x00          ; ล้างค่า OP_LOW
    ldi OP_HI, 0x00           ; ล้างค่า OP_HI
    ; หารด้วย 100
    ldi DIVISOR, 100          ; ตั้งค่าตัวหาร = 100
    mov DIVIDEND, IN_BINARY   ; ตั้งค่าตัวตั้ง = ค่าไบนารี
    call DIVIDE8BIT           ; เรียกฟังก์ชันหาร
    mov OP_HI, QUOTIENT       ; เก็บผลหารเป็นหลักร้อย
    
    ; หารด้วย 10
    ldi DIVISOR, 10           ; ตั้งค่าตัวหาร = 10
    mov DIVIDEND, REMAINDER   ; ตั้งค่าตัวตั้ง = เศษจากการหารด้วย 100
    call DIVIDE8BIT           ; เรียกฟังก์ชันหาร
    
    ; เลื่อนบิตผลหารไป 4 บิต
    lsl QUOTIENT              ; เลื่อนซ้าย 1 บิต
    lsl QUOTIENT              ; เลื่อนซ้าย 2 บิต
    lsl QUOTIENT              ; เลื่อนซ้าย 3 บิต
    lsl QUOTIENT              ; เลื่อนซ้าย 4 บิต
    
    mov OP_LOW, REMAINDER     ; เก็บเศษเป็นหลักหน่วย
    or OP_LOW, QUOTIENT       ; รวมหลักสิบและหลักหน่วย
    
    pop R24                   ; ดึงค่า R24 กลับ
    pop R23                   ; ดึงค่า R23 กลับ
    pop R22                   ; ดึงค่า R22 กลับ
    pop R21                   ; ดึงค่า R21 กลับ
    ret

; แยกหลัก BCD
.def IN_BCD = R18             ; ค่า BCD ที่ต้องการแยก
.def OP_LOW2 = R30            ; ผลลัพธ์หลักหน่วย
.def OP_HIGH2 = R31           ; ผลลัพธ์หลักสิบ
UNPACK_BCD:
    ldi OP_LOW2, 0X0F         ; โหลด 0x0F สำหรับ AND
    and OP_LOW2, IN_BCD       ; แยกหลักหน่วยด้วย AND
    mov OP_HIGH2, IN_BCD      ; โหลดค่า BCD
    lsr OP_HIGH2              ; เลื่อนขวา 1 บิต
    lsr OP_HIGH2              ; เลื่อนขวา 2 บิต
    lsr OP_HIGH2              ; เลื่อนขวา 3 บิต
    lsr OP_HIGH2              ; เลื่อนขวา 4 บิต
    ret

; แปลง BCD เป็นรหัส 7-Segment
.def INPUT_BCD = R25          ; ค่า BCD ที่ต้องการแปลง
.def OUTPUT7SEG = R25         ; รหัส 7-Segment ที่แปลงได้
BIN_TO_7SEG:
    push ZL                   ; เก็บค่า ZL
    push ZH                   ; เก็บค่า ZH
    push R0                   ; เก็บค่า R0
    sub R0, R0                ; ล้างค่า R0
    rjmp LOOK_TABLE           ; ไปที่ LOOK_TABLE

; ตารางรหัส 7-Segment
TB_7SEG:
    .DB 0b00111111, 0b00000110    ; 0, 1
    .DB 0b01011011, 0b01001111    ; 2, 3
    .DB 0b01100110, 0b01101101    ; 4, 5
    .DB 0b01111101, 0b00000111    ; 6, 7
    .DB 0b01111111, 0b01101111    ; 8, 9



LOOK_TABLE:
    ldi ZL, low(TB_7SEG*2)    ; โหลดแอดเดรสล่างของตาราง
    ldi ZH, high(TB_7SEG*2)   ; โหลดแอดเดรสสูงของตาราง
    add ZL, INPUT_BCD         ; บวกค่า BCD เพื่อหาตำแหน่งในตาราง
    adc ZH, R0                ; บวก carry ถ้ามี
    lpm                       ; โหลดค่าจากหน่วยความจำโปรแกรม
    mov OUTPUT7SEG, R0        ; เก็บค่าใน OUTPUT7SEG
    pop R0                    ; ดึงค่า R0 กลับ
    pop ZH                    ; ดึงค่า ZH กลับ
    pop ZL                    ; ดึงค่า ZL กลับ
    ret

; หน่วงเวลา 10ms
DELAY10MS:
    push R16                  ; เก็บค่า R16
    push R17                  ; เก็บค่า R17
    ldi R16, 0x00             ; ล้างค่า R16
LOOP2:
    inc R16                   ; เพิ่มค่า R16
    ldi R17, 0x00             ; ล้างค่า R17
LOOP1:
    inc R17                   ; เพิ่มค่า R17
    cpi R17, 249              ; เปรียบเทียบกับ 249
    brlo LOOP1                ; ถ้าน้อยกว่า วนลูปต่อ
    nop                       ; ไม่ทำอะไร (1 คาบเวลา)
    cpi R16, 160              ; เปรียบเทียบกับ 160
    brlo LOOP2                ; ถ้าน้อยกว่า วนลูปต่อ
    pop R17                   ; ดึงค่า R17 กลับ
    pop R16                   ; ดึงค่า R16 กลับ
    ret
; จัดการ Interrupt จาก PCINT1
PinChangeInt1:
    push R20                  ; เก็บค่า R20
    ldi TMP, 0x0F             ; โหลดมาสก์บิต 0-3
    in INPUTC, PINC           ; อ่านค่า PINC
    and INPUTC, TMP           ; เก็บเฉพาะบิต 0-3
    rcall WAY_ADD             ; เรียกฟังก์ชัน WAY_ADD
    pop R20                   ; ดึงค่า R20 กลับ
    reti                      ; กลับจาก Interrupt

; กำหนดค่าที่ใช้บวกให้ตัวนับตามสถานะสวิตช์
WAY_ADD:
    cpi INPUTC, 0b00001110    ; เปรียบเทียบกับ 0b00001110 (ปุ่ม 1)
    breq ADD_TWO              ; ถ้าเท่ากัน ไปที่ ADD_TWO
    cpi INPUTC, 0b00001101    ; เปรียบเทียบกับ 0b00001101 (ปุ่ม 2)
    breq ADD_THREE            ; ถ้าเท่ากัน ไปที่ ADD_THREE
    cpi INPUTC, 0b00001011    ; เปรียบเทียบกับ 0b00001011 (ปุ่ม 3)
    breq ADD_FIVE             ; ถ้าเท่ากัน ไปที่ ADD_FIVE
    cpi INPUTC, 0b00000111    ; เปรียบเทียบกับ 0b00000111 (ปุ่ม 4)
    breq ADD_TEN              ; ถ้าเท่ากัน ไปที่ ADD_TEN
    ret

; ตั้งค่าการเพิ่มตัวนับเป็น 2
ADD_TWO:
    ldi TMP, 2                ; โหลดค่า 2
    mov ADD_COUNT, TMP        ; ตั้งค่า ADD_COUNT = 2
    ret



; ตั้งค่าการเพิ่มตัวนับเป็น 3
ADD_THREE:
    ldi TMP, 3                ; โหลดค่า 3
    mov ADD_COUNT, TMP        ; ตั้งค่า ADD_COUNT = 3
    ret

; ตั้งค่าการเพิ่มตัวนับเป็น 5
ADD_FIVE:
    ldi TMP, 5                ; โหลดค่า 5
    mov ADD_COUNT, TMP        ; ตั้งค่า ADD_COUNT = 5
    ret

; ตั้งค่าการเพิ่มตัวนับเป็น 10
ADD_TEN:
    ldi TMP, 10                      ; โหลดค่า 10
    mov ADD_COUNT, TMP     ; ตั้งค่า ADD_COUNT = 10
    ret
