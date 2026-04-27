.global setDeterminantMatrix
/* ---------------------------------------------------------
 * Seccion de datos
 * --------------------------------------------------------- */
.section .data
    .align 2
    strDeterminante: .string "Determinante: "

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text

/* -----------------------------------------------------
* setDeterminantMatrix:
* Calcula el determinante apoyandose en setGaussMatrix (Bareiss).
* setGaussMatrix deja una matriz triangular C y retorna:
* x0 = puntero de C
* x1 = signo acumulado por swaps (+1 o -1)
*
* Para Bareiss, el determinante queda en C[n-1][n-1].
* Luego se aplica el signo de swaps y se guarda como matriz resultado 1x1.
*
* Entrada:
* Por teclado (la solicita setGaussMatrix)
*
* Retorno:
* Se almacena la matriz resultado 1x1 con el determinante en matrixResultPointer.
* ----------------------------------------------------- */
setDeterminantMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #48 // locales: puntero matriz Gauss, signo swaps, n, resultado final

    // Reutilizamos Gauss/Bareiss para validar y triangularizar.
    bl setGaussMatrix
    str x0, [fp, #-8] // Puntero de la matriz resultado de Gauss (matriz triangular C)
    str x1, [fp, #-16] // Signo acumulado por swaps durante Gauss

    // Validamos que exista resultado de Gauss y que no sea nulo.
    cmp x0, #0
    beq determinantEnd // Si no hay matriz resultado de Gauss, terminamos sin modificar matrixResultPointer

    ldr x9, =matrixResultRows // Cargamos la dirección de matrixResultRows para obtener n (filas de C)
    ldr w10, [x9] // cargamos n (filas de C)
    str w10, [fp, #-20] // Guardamos n en el stack para uso posterior
    cmp w10, #0
    ble determinantEnd // Si n es 0, terminamos sin modificar matrixResultPointer

    // offset ultimo elemento diagonal: ((n * n) - 1) * 4
    mul w11, w10, w10 // Calculamos n*n
    sub w11, w11, #1 // Restamos 1 para obtener el índice del último elemento en términos de cantidad de elementos
    lsl w12, w11, #2 // Multiplicamos por 4 para obtener el offset en bytes del último elemento diagonal C[n-1][n-1]

    ldr x13, [fp, #-8] // Cargamos el puntero de la matriz triangular C
    ldrsw x14, [x13, x12] // Cargamos el valor del último elemento diagonal C[n-1][n-1] (el determinante sin signo) y lo extendemos a 64 bits
    ldr x15, [fp, #-16] // Cargamos el signo acumulado por swaps
    mul x14, x14, x15 // Determinante final = C[n-1][n-1] * signo_swaps
    str x14, [fp, #-32] // Guardamos el resultado final del determinante en el stack

    // Convertimos el resultado a matriz 1x1.
    bl freePreviousMatrixResult
    mov w0, #1 // filas resultado
    mov w1, #1 // columnas resultado
    bl mallocResultMatrix // Reservamos memoria para la matriz resultado 1x1

    ldr x9, =matrixResultPointer // Cargamos la dirección de matrixResultPointer
    ldr x9, [x9] // Cargamos el puntero de la matriz resultado
    ldr w10, [fp, #-32] // Cargamos el valor del determinante calculado
    str w10, [x9] // Almacenamos el determinante en la matriz resultado

    ldr x0, =strDeterminante
    bl printString

    bl printLastResult

determinantEnd:
    add sp, sp, #48
    ldp fp, lr, [sp], #0x10
    ret
