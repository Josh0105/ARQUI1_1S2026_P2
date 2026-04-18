/* =========================================================
 * Proyecto 2 ARQUI 1 - Archivo inicial - en ARM64 (Linux)
 * Archivo: utils.s
 *
 * Utilidades para el proyecto 2 de ARQUI 1
 * ========================================================= */

.global printEnter
.global printString

/* ---------------------------------------------------------
 * Seccion bss para variables globales no inicializadas
 * --------------------------------------------------------- */
.section .bss
    .align 3
    output: .skip 112

/* ---------------------------------------------------------
 * Sección de datos
 * --------------------------------------------------------- */
.section .data
    .align 2
    enter: .asciz "\n"
    
/* ---------------------------------------------------------
 * Sección de código
 * --------------------------------------------------------- */
.section .text
/* -----------------------------------------------------
* printEnter:
* x0 = dirección de la cadena a imprimir (en este caso, un salto de línea)
* ----------------------------------------------------- */
printEnter:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    
    adrp x0, enter
    add x0, x0, :lo12:enter
    bl printString

    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* countBytes:
* x0 = dirección de la cadena a contar
* x1 = dirección del buffer
* x2 = número de bytes
* w3 = byte actual
* ----------------------------------------------------- */
countBytes:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    mov x2, #0
    mov x1, x0
    b auxBytes
auxBytes:
    ldrb w3, [x1], #1
    cmp w3, 0
    beq endCountBytes 
    add x2, x2, #1
    b auxBytes
endCountBytes:
    mov x0, x2
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* printString:
* x0 = dirección de la cadena a imprimir
* x1 = dirección del buffer
* x2 = número de bytes
* x8 = número de syscall (64)
* ----------------------------------------------------- */
printString: //x0 string address to print
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    mov x7, x0
    bl countBytes
    mov x2, x0
    mov x0, 1
    mov x1, x7
    mov x8, 64
    svc 0
    ldp fp, lr, [sp], #0x10
    ret