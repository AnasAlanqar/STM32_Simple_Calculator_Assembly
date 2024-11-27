.syntax unified
.cpu cortex-m3
.thumb

.section .text
.global asm_main

@ Register definitions
.equ RCC_APB2ENR, 0x40021018
.equ GPIOA_CRL,   0x40010800
.equ GPIOA_CRH,   0x40010804
.equ GPIOA_ODR,   0x4001080C
.equ GPIOA_IDR,   0x40010808
.equ GPIOB_CRL,   0x40010C00
.equ GPIOB_CRH,   0x40010C04
.equ GPIOB_ODR,   0x40010C0C

asm_main:
    @ Enable clocks
    ldr     r0, =RCC_APB2ENR
    mov     r1, #0x0C            @ GPIOA and GPIOB
    str     r1, [r0]

    @ Configure PA0-PA7 as inputs with pull-up (CRL)
    ldr     r0, =GPIOA_CRL
    ldr     r1, =0x88888888      @ All pins input pull-up
    str     r1, [r0]

    @ Configure PA8 and PA9 as inputs (CRH)
    ldr     r0, =GPIOA_CRH
    mov     r1, #0x8             @ PA8 as input pull-up
    orr     r1, #(0x4 << 4)      @ PA9 as floating input
    str     r1, [r0]

    @ Enable pull-ups on PA0-PA8 (not PA9)
    ldr     r0, =GPIOA_ODR
    mov     r1, #0x1FF           @ Set bits 0-8 for pull-ups
    str     r1, [r0]

    @ Configure 7-segment outputs
    ldr     r0, =GPIOB_CRL
    mov     r1, #(0x3 << 20)     @ PB5
    orr     r1, #(0x3 << 24)     @ PB6
    orr     r1, #(0x3 << 28)     @ PB7
    str     r1, [r0]

    ldr     r0, =GPIOB_CRH
    mov     r1, #0x3             @ PB8
    orr     r1, #(0x3 << 4)      @ PB9
    orr     r1, #(0x3 << 24)     @ PB14
    orr     r1, #(0x3 << 28)     @ PB15
    str     r1, [r0]

calc_start:
    mov     r6, #0               @ Clear stored numbers
    mov     r7, #0

wait_first:
    bl      read_buttons         @ Returns number in r0
    cmp     r0, #0
    beq     wait_first           @ If no button, keep waiting
    mov     r6, r0               @ Store first number
    bl      display_number       @ Show the number
    bl      delay_ms            @ Debounce delay

wait_release1:
    bl      read_buttons
    cmp     r0, #0
    bne     wait_release1        @ Wait until button released

wait_second:
    bl      read_buttons
    cmp     r0, #0
    beq     wait_second          @ If no button, keep waiting
    mov     r7, r0               @ Store second number
    bl      display_number       @ Show the number
    bl      delay_ms            @ Debounce delay

wait_release2:
    bl      read_buttons
    cmp     r0, #0
    bne     wait_release2        @ Wait until button released

    @ Read PA9 to determine operation
    ldr     r0, =GPIOA_IDR
    ldr     r1, [r0]
    tst     r1, #(1 << 9)        @ Test PA9 state
    beq     do_addition          @ If LOW, do addition
    b       do_subtraction       @ If HIGH, do subtraction

do_addition:
    add     r0, r6, r7           @ Add numbers
    b       check_result

do_subtraction:
    sub     r0, r6, r7           @ Subtract numbers
    @ If result is negative, show 0
    cmp     r0, #0
    it      lt
    movlt   r0, #0

check_result:
    cmp     r0, #9               @ Check if result > 9
    it      gt
    movgt   r0, #0               @ If > 9, show 0

    @ Delay and show result
    mov     r4, #2               @ Reduced delay (2 iterations)
delay_loop:
    push    {r0, r4}             @ Save result and counter
    bl      delay_ms
    pop     {r0, r4}
    subs    r4, #1
    bne     delay_loop

    @ Show result
    bl      display_number
    bl      delay_ms

    b       calc_start           @ Start over

@ Function to read buttons, returns 1-9 in r0 or 0 if no button
read_buttons:
    push    {r4, lr}
    ldr     r0, =GPIOA_IDR
    ldr     r4, [r0]             @ Read inputs
    mov     r0, #0               @ Default return 0
    mov     r1, #0               @ Counter
check_each:
    mov     r2, #1
    lsl     r2, r1               @ Create mask
    tst     r4, r2               @ Test bit
    beq     button_found         @ If 0, button is pressed
    add     r1, #1
    cmp     r1, #9
    blt     check_each
    b       read_done
button_found:
    add     r0, r1, #1           @ Return button number
read_done:
    pop     {r4, pc}

@ Function for delay
delay_ms:
    push    {r4, lr}
    mov     r4, #0x8FFF          @ Reduced delay value
1:  mov     r3, #0x10
2:  subs    r3, #1
    bne     2b
    subs    r4, #1
    bne     1b
    pop     {r4, pc}

@ Function to display number in r0
display_number:
    push    {r4, lr}
    ldr     r4, =GPIOB_ODR
    cmp     r0, #1
    beq     show_1
    cmp     r0, #2
    beq     show_2
    cmp     r0, #3
    beq     show_3
    cmp     r0, #4
    beq     show_4
    cmp     r0, #5
    beq     show_5
    cmp     r0, #6
    beq     show_6
    cmp     r0, #7
    beq     show_7
    cmp     r0, #8
    beq     show_8
    cmp     r0, #9
    beq     show_9
    mov     r1, #0               @ If 0 or invalid, all segments off
    str     r1, [r4]
    pop     {r4, pc}

show_1:
    mov     r1, #(1 << 15)       @ b
    orr     r1, #(1 << 5)        @ c
    str     r1, [r4]
    pop     {r4, pc}

show_2:
    mov     r1, #(1 << 14)       @ a
    orr     r1, #(1 << 15)       @ b
    orr     r1, #(1 << 6)        @ d
    orr     r1, #(1 << 7)        @ e
    orr     r1, #(1 << 9)        @ g
    str     r1, [r4]
    pop     {r4, pc}

show_3:
    mov     r1, #(1 << 14)       @ a
    orr     r1, #(1 << 15)       @ b
    orr     r1, #(1 << 5)        @ c
    orr     r1, #(1 << 6)        @ d
    orr     r1, #(1 << 9)        @ g
    str     r1, [r4]
    pop     {r4, pc}

show_4:
    mov     r1, #(1 << 15)       @ b
    orr     r1, #(1 << 5)        @ c
    orr     r1, #(1 << 8)        @ f
    orr     r1, #(1 << 9)        @ g
    str     r1, [r4]
    pop     {r4, pc}

show_5:
    mov     r1, #(1 << 14)       @ a
    orr     r1, #(1 << 5)        @ c
    orr     r1, #(1 << 6)        @ d
    orr     r1, #(1 << 8)        @ f
    orr     r1, #(1 << 9)        @ g
    str     r1, [r4]
    pop     {r4, pc}

show_6:
    mov     r1, #(1 << 14)       @ a
    orr     r1, #(1 << 5)        @ c
    orr     r1, #(1 << 6)        @ d
    orr     r1, #(1 << 7)        @ e
    orr     r1, #(1 << 8)        @ f
    orr     r1, #(1 << 9)        @ g
    str     r1, [r4]
    pop     {r4, pc}

show_7:
    mov     r1, #(1 << 14)       @ a
    orr     r1, #(1 << 15)       @ b
    orr     r1, #(1 << 5)        @ c
    str     r1, [r4]
    pop     {r4, pc}

show_8:
    mov     r1, #(1 << 14)       @ a
    orr     r1, #(1 << 15)       @ b
    orr     r1, #(1 << 5)        @ c
    orr     r1, #(1 << 6)        @ d
    orr     r1, #(1 << 7)        @ e
    orr     r1, #(1 << 8)        @ f
    orr     r1, #(1 << 9)        @ g
    str     r1, [r4]
    pop     {r4, pc}

show_9:
    mov     r1, #(1 << 14)       @ a
    orr     r1, #(1 << 15)       @ b
    orr     r1, #(1 << 5)        @ c
    orr     r1, #(1 << 6)        @ d
    orr     r1, #(1 << 8)        @ f
    orr     r1, #(1 << 9)        @ g
    str     r1, [r4]
    pop     {r4, pc}
