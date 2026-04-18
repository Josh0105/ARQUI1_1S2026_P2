/* =========================================================
 * Proyecto 2 ARQUI 1 - Archivo inicial - en ARM64 (Linux)
 * Archivo: main.s
 *
 * Ensamblador: aarch64-linux-gnu-as
 * Enlazador : aarch64-linux-gnu-ld
 * Ejecución : nativa
 *
 * No usa libc, solo syscalls de Linux.
 * ========================================================= */

/* ---------------------------------------------------------
 * Registros usados en este archivo
 * ---------------------------------------------------------
 * x0 = argumento 1 de syscall (direccion de buffer o codigo de salida)
 * --------------------------------------------------------- */

.include "utils.s" // Incluimos el archivo de utilidades

/* ---------------------------------------------------------
 * Sección de datos
 * --------------------------------------------------------- */
.section .data
    .align 2  
    str1: .string "¡Bienvenido al Proyecto 2 - ARQUI 1 Aarch64!\n"
    str2: .string "Seleccione una opción:\n"
    str3: .string "1. Ingresar Matriz A\n"
    str4: .string "2. Salir del sistema\n"
    str5: .string "Saliendo...\n"


/* ---------------------------------------------------------
 * Sección de código
 * --------------------------------------------------------- */
.section .text
.global _start               // Punto de entrada

_start:

printInitialMenu:
    ldr x0, =str1
    bl printString
    bl printEnter

    ldr x0, =str2
    bl printString
    bl printEnter
    ldr x0, =str3
    bl printString
    ldr x0, =str4
    bl printString

    bl printEnter

    ldr x0, =str5
    bl printString
    bl printEnter


bl endProgram

/* -----------------------------------------------------
* syscall exit(0)
*
* x0 = código de salida
* x8 = número de syscall (93)
* ----------------------------------------------------- */
endProgram:
    mov     x0, #0               // código de salida
    mov     x8, #93              // syscall exit
    svc     #0                   // llamada al kernel