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
* Se almacena la matriz transpuesta en la dirección apuntada por matrixResultPointer, con dimensiones
* actualizadas en matrixResultRows y matrixResultCols. Si no se pudo generar la matriz transpuesta, 
* matrixResultPointer se mantiene en 0.
*
* Registros importantes:
* x0 = puntero de la matriz original (después de llamar a getMatrixById)
* w1 = filas de la matriz original (después de llamar a getMatrixById)
* w2 = columnas de la matriz original (después de llamar a getMatrixById)
* w0 = filas resultado = columnas matriz original (después de reservar memoria para matriz resultado)
* w1 = columnas resultado = filas matriz original (después de reservar memoria para matriz resultado)
* x11 = puntero de la matriz resultado (después de reservar memoria para matriz resultado)
* w9, w10, w12, w13, w14 = registros usados para cálculos de offsets y control de loops al llenar la matriz transpuesta
* w0 = valor del elemento actual de la matriz original que se va a transponer
* x15 = puntero base de la matriz original o resultado para cargar/almacenar elementos durante el proceso de transposición
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
    beq matrixNotFoundTransposed // Si no se encontró la matriz por ID,(puntero 0), mostramos mensaje de error

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
    ldr w9, [fp, #-36] // Carga i
    ldr w10, [fp, #-12]  // Carga total de filas de la matriz original
    cmp w9, w10
    bge printTransposedResult // Si terminamos de iterar todas las filas, salimos
    mov w10, #0 // resetea j para cada nueva fila
    str w10, [fp, #-40] // guarda j en el stack

transposedColsLoop:
    ldr w9, [fp, #-36] // Carga i
    ldr w10, [fp, #-40] // Carga j
    ldr w11, [fp, #-16] // Carga total de columnas de la matriz original
    cmp w10, w11
    bge nextTransposedRow // si terminamos de iterar todas las columnas, vamos a la siguiente fila, si no, seguimos iterando para la fila actual

    // Offset origen: (i * columnas + j) * 4
    mul w13, w9, w11 // Calculamos la posición base de la fila: i * columnas de la matriz original
    add w13, w13, w10 // Sumamos la columna para obtener el offset total en elementos: i * columnas + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-8] // Carga el puntero base de la matriz original
    ldr w0, [x15, x14] // Carga el valor del elemento actual de la matriz original en w0

    // Offset destino: (j * columnas + i) * 4 (para la matriz transpuesta, las filas y columnas se invierten)
    ldr w12, [fp, #-32] // Cargamos columnas de la matriz resultado
    mul w13, w10, w12 // Calculamos la posición base de la fila en la matriz resultado: j * columnas de la matriz resultado
    add w13, w13, w9 // Sumamos i para obtener el offset total en elementos: j * columnas + i
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Carga el puntero base de la matriz resultado

    str w0, [x15, x14] // Almacena el valor transpuesto en la posición correcta de la matriz resultado

    add w10, w10, #1 // j++
    str w10, [fp, #-40] // Guarda j actualizado en el stack
    b transposedColsLoop

nextTransposedRow:
    ldr w9, [fp, #-36] // Carga i
    add w9, w9, #1 // i++
    str w9, [fp, #-36] // Guarda i actualizado en el stack
    b transposedRowsLoop

matrixNotFoundTransposed:
    bl generalMatrixNotFound
    b endTransposed

printTransposedResult:
    bl printLastResult
    b endTransposed

endTransposed:
    add sp, sp, #48
    ldp fp, lr, [sp], #0x10
    ret
