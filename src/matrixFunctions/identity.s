.global setIdentityMatrix

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text

/* -----------------------------------------------------
* setIdentityMatrix:
* Genera la matriz identidad de tamaño n x n solicitada por el usuario y la guarda como resultado. 
* Se solicita el ID de una matriz ingresada, valida si es cuadrada, reserva memoria para la matriz 
* resultado usando mallocResultMatrix y luego llena la matriz resultado con 1s en la diagonal.
*
* Entrada:
* Por teclado
*
* Registros importantes:
*
------------------------------------------------------ */
setIdentityMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #48 // variables locales para matriz origen y matriz resultado

askIdentityMatrixId:
    ldr x0, =strAskIdUniqueOperation
    bl printString // Imprime "Ingrese el ID de la matriz a operar (A-Z): "
    bl readMatrixIdFromConsole // Lee el ID ingresado y lo valida, retorna 0 si es inválido
    cmp x0, #0
    bne continueIdentityMatrixId // Si el ID es válido (no 0), continuamos con la operación de generación de matriz identidad
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje de error y volvemos a pedir el ID
    b askIdentityMatrixId

continueIdentityMatrixId:
    bl getMatrixById // Busca la matriz por ID, retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-8] // Guardamos el puntero de la matriz origen
    str w1, [fp, #-12] // Guardamos filas de la matriz origen
    str w2, [fp, #-16] // Guardamos columnas de la matriz origen

    cmp x0, #0
    beq matrixNotFoundIdentity // Si no se encontró la matriz por ID,(puntero 0), mostramos mensaje de error

    cmp w1, w2
    bne notSquareMatrixIdentity // Si la matriz no es cuadrada (filas != columnas), mostramos mensaje de error

    // Si se encontró y es cuadrada, liberamos cualquier resultado previo almacenado en matrixResultPointer antes de guardar el nuevo resultado
    bl freePreviousMatrixResult
    // Reservamos memoria para la nueva matriz identidad usando matrixMalloc y guardamos su metadata para uso posterior
    ldr w0, [fp, #-12] // Cargamos filas = columnas para la matriz identidad
    ldr w1, [fp, #-12] // Cargamos filas = columnas para la matriz identidad
    bl mallocResultMatrix // reservamos memoria para la matriz resultado enviando filas y columnas

    // Traemos la metadata de la matriz resultado
    ldr x11, =matrixResultPointer // Carga la direccion de matrixResultPointer
    ldr x11, [x11] // Carga el puntero de la matriz resultado
    str x11, [fp, #-24] // Guardamos el puntero de la matriz resultado en el stack
    ldr x11, =matrixResultRows // Carga la direccion de matrixResultRows
    ldr w1, [x11] // Carga filas de la matriz resultado
    str w1, [fp, #-28] // Guardamos filas de la matriz resultado en el stack
    ldr x11, =matrixResultCols // Carga la direccion de matrixResultCols
    ldr w2, [x11] // Carga columnas de la matriz resultado
    str w2, [fp, #-32] // Guardamos columnas de la matriz resultado en el stack

    mov w11, #0 // creamos variable i para iterar filas y columnas de la matriz resultado
    str w11, [fp, #-36] // Guardamos i en el stack

    // Llenamos la matriz resultado con 1s en la diagonal (donde i == j), el resto no se llena porque malloc las entrega en 0
loopIdentityMatrix:
    ldr w9, [fp, #-36] // Cargamos i de la matriz resultado
    ldr w10, [fp, #-28] // Cargamos filas de la matriz resultado
    cmp w9, w10
    bge printIdentityResult // Si i >= filas, terminamos de llenar la matriz

    // Calculamos el offset para la posición (i, i) en la matriz resultado y almacenamos un 1 allí
    ldr w11, [fp, #-32] // Cargamos columnas de la matriz resultado
    mul w13, w9, w11 // Calculamos la posición base de la fila: i * columnas de la matriz resultado
    add w13, w13, w9 // Sumamos i para obtener el offset total en elementos: i * columnas + i
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de la matriz resultado

    mov w0, #1 // valor a almacenar en la diagonal
    str w0, [x15, x14] // Almacenamos 1 en [i][i]

    add w9, w9, #1 // i++
    str w9, [fp, #-36] // Guardamos i actualizado
    b loopIdentityMatrix

notSquareMatrixIdentity:
    bl generalNotSquareMatrix // Mostramos mensaje de error de matriz no cuadrada
    b endSetIdentityMatrix

matrixNotFoundIdentity:
    bl generalMatrixNotFound // Mostramos mensaje de error de matriz no encontrada
    b endSetIdentityMatrix

printIdentityResult:
    bl printLastResult // Imprime la matriz resultado (identidad) usando la función de impresión general
    b endSetIdentityMatrix

endSetIdentityMatrix:
    add sp, sp, #48 // limpiamos espacio de variables locales
    ldp fp, lr, [sp], #0x10
    ret
