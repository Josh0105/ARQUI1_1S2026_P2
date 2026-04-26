.global setTransposedMatrix

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text
/* -----------------------------------------------------
* setTransposedMatrix:
* Genera la matriz transpuesta de una matriz solicitada por ID y la guarda como resultado. 
* Se solicita el ID de la matriz a transponer, se valida y se obtiene su puntero y dimensiones usando 
* getMatrixById. Luego se reserva memoria para la matriz resultado usando mallocResultMatrix.
*
* Entrada:
* Por teclado
*
* Retorno:
* x0 = puntero de matriz (0 si no existe)
* w1 = filas
* w2 = columnas
*
* Registros importantes:
* x13 = registros temporales para cargar metadata de la matriz resultado
* ----------------------------------------------------- */
setTransposedMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #48 // variables locales para matriz origen y resultado previo

askTransposedMatrixId:
    ldr x0, =strAskIdUniqueOperation
    bl printString // Imprime "Ingrese el ID de la matriz a operar (A-Z): "
    bl readMatrixIdFromConsole // Lee el ID ingresado y lo valida, retorna 0 si es inválido
    cmp x0, #0
    bne continueTransposedMatrixId // Si el ID es válido (no 0), continuamos con la operación de transposición de la matriz
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje de error y volvemos a pedir el ID
    b askTransposedMatrixId

continueTransposedMatrixId:
    bl getMatrixById // Busca la matriz por ID, retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-8] // Guardamos el puntero de la matriz en el stack
    str w1, [fp, #-12] // Guardamos filas en el stack
    str w2, [fp, #-16] // Guardamos columnas en el stack

    cmp x0, #0
    beq matrixNotFoundTransposed // Si no se encontró la matriz (puntero 0), mostramos mensaje de error

    // Si se encontró liberamos cualquier resultado previo almacenado en matrixResultPointer antes de guardar el nuevo resultado
    bl freePreviousMatrixResult
    // Reservamos memoria para la nueva matriz transpuesta usando matrixMalloc y guardamos su metadata para uso posterior
    ldr w0, [fp, #-16] // Cargamos filas resultado = columnas matriz original
    ldr w1, [fp, #-12] // Cargamos columnas resultado = filas matriz original
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

    mov w11, #0 // creamos variable i para iterar filas
    str w11, [fp, #-36] // Guardamos i en el stack
    
/* -----------------------------------------------------
* Recorrido de la matriz usando i para filas y j para columnas, 
* calculando el offset para acceder a cada elemento de la matriz original,
* almacenando su valor transpuesto en la posición correcta de la matriz 
* resultado usando el puntero y dimensiones de la matriz resultado.
-----------------------------------------------------*/
transposedRowsLoop:
    ldr w11, [fp, #-36] // Carga i
    ldr w9, [fp, #-12]  // Carga total de filas de la matriz original
    cmp w11, w9
    bge endTransposed // Si terminamos de iterar todas las filas, salimos
    mov w12, #0 // resetea j para cada nueva fila
    str w12, [fp, #-40] // guarda j en el stack

transposedColsLoop:
    ldr w12, [fp, #-40] // Carga j
    ldr w10, [fp, #-16] // Carga total de columnas de la matriz original
    cmp w12, w10
    bge nextTransposedRow // si terminamos de iterar todas las columnas, vamos a la siguiente fila, si no, seguimos iterando para la fila actual

    ldr w11, [fp, #-36] // Carga i
    ldr w13, [fp, #-16] // Carga total de columnas de la matriz original
    mul w14, w11, w13 // calculamos la posición base de la fila: i * columnas de la matriz original
    add w14, w14, w12  // sumamos la columna para obtener el offset total en elementos: i * columnas + j
    lsl w14, w14, #2 // multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-8] // Carga el puntero base de la matriz original
    ldr w0, [x15, x14] // Carga el valor del elemento actual de la matriz original en w0

    // Ahora calculamos el offset para almacenar el valor transpuesto en la matriz resultado
    ldr w11, [fp, #-40] // Carga j (que será la fila en la matriz resultado)
    ldr w13, [fp, #-32] // Carga total de columnas de la matriz resultado
    mul w14, w11, w13 // calculamos la posición base de la fila en la matriz resultado: j * columnas resultado
    ldr w12, [fp, #-36] // Carga i (que será la columna en la matriz resultado)
    add w14, w14, w12  // sumamos la columna para obtener el offset total en elementos: j * filas resultado + i
    lsl w14, w14, #2 // multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Carga el puntero base de la matriz resultado

    str w0, [x15, x14] // Almacena el valor transpuesto en la posición correcta de la matriz resultado

    ldr w12, [fp, #-40] // Carga j
    add w12, w12, #1 // j++
    str w12, [fp, #-40] // Guarda j actualizado en el stack
    b transposedColsLoop

nextTransposedRow:
    ldr w11, [fp, #-36] // Carga i
    add w11, w11, #1 // i++
    str w11, [fp, #-36] // Guarda i actualizado en el stack
    b transposedRowsLoop

matrixNotFoundTransposed:
    bl generalMatrixNotFound

endTransposed:
    add sp, sp, #48
    ldp fp, lr, [sp], #0x10
    ret
