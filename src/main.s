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
    str9: .string "9. Funciones aritméticas con matrices\n"
    str10: .string "10. Salir\n"
    errMsg: .string "Opción no válida, intente de nuevo.\n"
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
    bl printEnter


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

    ldr x0, =errMsg
    bl printString

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

case10:
    ldr x0, =strExit
    bl printString
    b endProgram


/* -----------------------------------------------------
* readOptionFromConsole:
* x0 = devuelve el entero ingresado en consola o negativo si hubo un error
* x1 = dirección del buffer de entrada
* x2 = tamaño del buffer de entrada
* x8 = número de syscall (63)
* ----------------------------------------------------- */
readOptionFromConsole:
  stp fp, lr, [sp, #-0x10]!
  mov fp, sp

  bl cleanUpInput
  mov x0, 0 // preparar para leer de stdin
  ldr x1, =input
  mov x2, 32 
  mov x8, 63 // syscall read
  svc 0 // ejecuta lectura
  ldr x0, =input // cargar dirección del buffer en x0 para validación

loopValidationInput:
  ldrb w1, [x0], #1 // leemos byte a byte
  cmp w1, 0x0 // null
  beq endLoopValidationInput // si es null, terminamos validación
  cmp w1, #10 // nueva línea
  beq loopValidationInput // si es nueva línea, la ignoramos y seguimos validando
  cmp w1, #48 // '0'
  blt errorInputAskInteger // si es menor que '0', es inválido
  cmp w1, #57 // '9'
  bgt errorInputAskInteger // si es mayor que '9', es inválido
  b loopValidationInput

endLoopValidationInput:
  ldr x0, =input // cargar dirección del buffer en x0
  mov x1, #10 // caracter de nueva línea para indicar el final de la cadena
  bl funcAtoiWithCounter

  ldp fp, lr, [sp], #0x10
  ret

/* -----------------------------------------------------
* errorInputAskInteger:
* devuelve -1 en x0 para indicar que hubo un error en la entrada del entero
* ----------------------------------------------------- */
errorInputAskInteger:
  mov x0, #-1
  ldp fp, lr, [sp], #0x10
  ret


/* -----------------------------------------------------
* cleanUpInput:
* limpia el buffer de entrada para evitar residuos de entradas anteriores
* ----------------------------------------------------- */
cleanUpInput:
  stp fp, lr, [sp, #-0x10]!
  mov fp, sp

  ldr x1, =input
  // escribimos ceros cada 8 bytes para limpiar el buffer
  str xzr, [x1], #8
  str xzr, [x1], #8
  str xzr, [x1], #8
  str xzr, [x1]

  ldp fp, lr, [sp], #0x10
  ret

/* -----------------------------------------------------
* funcAtoiWithCounter:
* Convierte una cadena de caracteres numéricos en un entero, deteniéndose al encontrar un carácter no numérico o el final de la cadena.
* x0 = valor entero resultante de la conversión
* x1 = dirección de la cadena a convertir
* x8 = caracter de nueva línea que indica el final de la cadena
* x9 = contador de dígitos procesados
* w2 = byte actual leído de la cadena
* w8 = caracter de nueva línea (fin de cadena)
* ----------------------------------------------------- */
funcAtoiWithCounter: //x0 address string x1 the endtocount- returns x0 integer
  stp fp, lr, [sp, #-0x10]!
  mov fp, sp
  mov x8, x1
  mov x1, x0 //x1 adress
  mov x0, #0 //value
  mov x9, #0 //the counter

processFuncAtoiWithCounter:
  ldrb w2, [x1], #1
  cmp w2, w8 // comparamos con el caracter de nueva línea
  bne isNotEndLine // si no es nueva línea, seguimos procesando

  mov x1, x9 // si es nueva línea, movemos el contador a x1 para devolverlo
  ldp fp, lr, [sp], #0x10
  ret

/* -----------------------------------------------------
* isNotEndLine:
* Procesa cada dígito de la cadena, actualizando el valor entero acumulado en x0 y el contador de dígitos en x9.
* x0 = valor entero acumulado
* w2 = byte actual leído de la cadena
* x4 = constante 10 para multiplicar el valor acumulado
* x9 = contador de dígitos procesados
* ----------------------------------------------------- */
isNotEndLine:
  add x9, x9, #1 // incrementamos el contador de dígitos
  sub w2, w2, #48 // convertimos el carácter ASCII a su valor numérico restando 48
  mov x4, #10 // constante para multiplicar el valor acumulado
  mul x0, x0, x4 // multiplicamos el valor acumulado por 10 para desplazarlo a la izquierda
  add x0, x0, x2 // sumamos el valor del dígito actual al valor acumulado
  b processFuncAtoiWithCounter

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