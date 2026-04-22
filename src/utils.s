/* =========================================================
 * Proyecto 2 ARQUI 1 - Archivo inicial - en ARM64 (Linux)
 * Archivo: utils.s
 *
 * Utilidades para el proyecto 2 de ARQUI 1
 * ========================================================= */

.global printEnter
.global printString
.global readOptionFromConsole

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
    
    adrp x0, enter // Cargar la dirección de la página de 'enter' en x0
    add x0, x0, :lo12:enter // Agregar el desplazamiento de 'enter' a x0
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
  bne processNextChar // si no es nueva línea, seguimos procesando

  mov x1, x9 // si es nueva línea, movemos el contador a x1 para devolverlo
  ldp fp, lr, [sp], #0x10
  ret

/* -----------------------------------------------------
* processNextChar:
* Procesa cada dígito de la cadena, actualizando el valor entero acumulado en x0 y el contador de dígitos en x9.
* x0 = valor entero acumulado
* w2 = byte actual leído de la cadena
* x4 = constante 10 para multiplicar el valor acumulado
* x9 = contador de dígitos procesados
* ----------------------------------------------------- */
processNextChar:
  add x9, x9, #1 // incrementamos el contador de dígitos
  sub w2, w2, #48 // convertimos el carácter ASCII a su valor numérico restando 48
  mov x4, #10 // constante para multiplicar el valor acumulado
  mul x0, x0, x4 // multiplicamos el valor acumulado por 10 para desplazarlo a la izquierda
  add x0, x0, x2 // sumamos el valor del dígito actual al valor acumulado
  b processFuncAtoiWithCounter