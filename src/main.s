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
 * Sección de para reservar espacio
 * --------------------------------------------------------- */
.section .bss
  .align 3
  input: .space 32

/* ---------------------------------------------------------
 * Sección de datos
 * --------------------------------------------------------- */
.section .data
    .align 2  
    strBienvenida: .string "¡Bienvenido al Proyecto 2 - ARQUI 1 Aarch64!\n"
    strInstruction: .string "Seleccione una opción:\n"
    str1: .string "1. Ingresar Una matriz\n"
    str2: .string "2. Liberar espacio de una matriz\n"
    str3: .string "3. Imprimir una matriz\n"
    str4: .string "4. Generar matriz identidad\n"
    str5: .string "5. Generar matriz transpuesta\n"
    str6: .string "6. Gauss\n"
    str7: .string "7. Gauss-Jordan\n"
    str8: .string "8. Matriz inversa\n"
    str9: .string "9. Determinante\n"
    str10: .string "10. Funciones aritméticas con matrices\n"
    str11: .string "11. Salir\n"
    errMsg: .string "Opción no válida, intente de nuevo.\n"
    str1_1: .string "1. Suma de matrices\n"
    str1_2: .string "2. Resta de matrices\n"
    str1_3: .string "3. Multiplicación de matrices\n"
    str1_4: .string "4. División de matrices\n"
    str1_5: .string "5. Volver al menú principal\n"
    strExit: .string "Saliendo...\n"


/* ---------------------------------------------------------
 * Sección de código
 * --------------------------------------------------------- */
.section .text
.global _start               // Punto de entrada

_start:
    ldr x0, =strBienvenida
    bl printString
    bl printEnter

// Imprimimos el menú inicial
printInitialMenu:
    ldr x0, =strInstruction
    bl printString
    bl printEnter
    ldr x0, =str1
    bl printString
    ldr x0, =str2
    bl printString
    ldr x0, =str3
    bl printString
    ldr x0, =str4
    bl printString
    ldr x0, =str5
    bl printString
    ldr x0, =str6
    bl printString
    ldr x0, =str7
    bl printString
    ldr x0, =str8
    bl printString
    ldr x0, =str9
    bl printString
    ldr x0, =str10
    bl printString
    ldr x0, =str11
    bl printString
    bl printEnter

    // Leemos la opción ingresada en la consola
    bl readOptionFromConsole

    str x0, [sp, #-16]!// Guardamos la opción ingresada en la pila
    bl printEnter
    ldr x0, [sp], #16 // Recuperamos la opción ingresada de la pila

//SWITCH CASE PARA LAS OPCIONES DEL MENU
    cmp x0, #1
    beq case1
    cmp x0, #2
    beq case2
    cmp x0, #3
    beq case3
    cmp x0, #4
    beq case4
    cmp x0, #5
    beq case5
    cmp x0, #6
    beq case6
    cmp x0, #7
    beq case7
    cmp x0, #8
    beq case8
    cmp x0, #9
    beq case9
    cmp x0, #10
    beq case10
    cmp x0, #11
    beq case11

    // Si la opción no es válida, imprimimos un mensaje de error
    ldr x0, =errMsg
    bl printString
    // Volvemos a imprimir el menú inicial
    b printInitialMenu

case1:
    ldr x0, =str1
    bl printString
    b printInitialMenu

case2:
    ldr x0, =str2
    bl printString
    b printInitialMenu
  
case3:
    ldr x0, =str3
    bl printString
    b printInitialMenu

case4:
    ldr x0, =str4
    bl printString
    b printInitialMenu

case5:
    ldr x0, =str5
    bl printString
    b printInitialMenu

case6:
    ldr x0, =str6
    bl printString
    b printInitialMenu

case7:
    ldr x0, =str7
    bl printString
    b printInitialMenu

case8:
    ldr x0, =str8
    bl printString
    b printInitialMenu

case9:
    ldr x0, =str9
    bl printString
    b printInitialMenu

case10: // Funciones aritméticas con matrices
    b printArithmeticMenu

case11: //Salir
    ldr x0, =strExit
    bl printString
    b endProgram

// imprimir el menú de operaciones aritméticas con matrices
printArithmeticMenu:
    bl printEnter
    ldr x0, =str1_1
    bl printString
    ldr x0, =str1_2
    bl printString
    ldr x0, =str1_3
    bl printString
    ldr x0, =str1_4
    bl printString
    ldr x0, =str1_5
    bl printString
    bl printEnter

//SWITCH CASE PARA LAS OPCIONES SEGUNDO MENU
    bl readOptionFromConsole

    str x0, [sp, #-16]!// Guardamos la opción ingresada en la pila
    bl printEnter
    ldr x0, [sp], #16 // Recuperamos la opción ingresada de la pila

    cmp x0, #1
    beq case1_1
    cmp x0, #2
    beq case1_2
    cmp x0, #3
    beq case1_3
    cmp x0, #4
    beq case1_4
    cmp x0, #5
    beq case1_5
    // Si la opción no es válida, imprimimos un mensaje de error
    ldr x0, =errMsg
    bl printString
    // Volvemos a imprimir el menú de operaciones aritméticas
    b printArithmeticMenu

case1_1:
    ldr x0, =str1_1
    bl printString
    b printArithmeticMenu

case1_2:
    ldr x0, =str1_2
    bl printString
    b printArithmeticMenu

case1_3:
    ldr x0, =str1_3
    bl printString
    b printArithmeticMenu

case1_4:
    ldr x0, =str1_4
    bl printString
    b printArithmeticMenu

case1_5:
    b printInitialMenu


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