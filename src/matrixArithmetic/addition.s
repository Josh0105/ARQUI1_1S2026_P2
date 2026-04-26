.global setAdditionMatrix

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text

/* -----------------------------------------------------
* setAdditionMatrix:
* Genera la matriz resultado de sumar dos matrices solicitadas por ID y la guarda como resultado.
* Solicita operador 1 y operador 2, valida que existan y que tengan mismas dimensiones,
* reserva memoria para el resultado y calcula la suma elemento por elemento.
*
* Entrada:
* x0 = modo de operacion (0 = suma, 1 = resta)
* Por teclado para IDs
*
* Retorno:
* Se almacena la matriz suma en matrixResultPointer con dimensiones en matrixResultRows y matrixResultCols.
* Si no se pudo generar la suma, matrixResultPointer se conserva sin cambios.
*
* Registros importantes:
* w9 = i (fila actual)
* w10 = j (columna actual)
* w11 = columnas del resultado
* w12 = valor matriz operador 1
* w13 = valor matriz operador 2 / indice en elementos
* w14 = offset en bytes
* x15 = puntero base temporal de matrices
* ----------------------------------------------------- */
setAdditionMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #64 // variables locales para operadores y matriz resultado

    // Guardamos modo de operación para usarlo dentro del loop (0 suma, 1 resta)
    str w0, [fp, #-60]

askFirstMatrixId:
    bl generalAskIdFirstMatrix // Imprime "Ingrese el ID de la matriz (A-Z) Operador 1: "
    bl readMatrixIdFromConsole // Lee ID del operador 1, retorna 0 si es inválido
    cmp x0, #0
    bne continueFirstMatrixId // Si el ID es válido, continuamos con búsqueda de la matriz
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje y volvemos a pedir
    b askFirstMatrixId

continueFirstMatrixId:
    bl getMatrixById // Busca matriz operador 1 por ID, retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-8] // Guardamos puntero operador 1
    str w1, [fp, #-12] // Guardamos filas operador 1
    str w2, [fp, #-16] // Guardamos columnas operador 1

    cmp x0, #0
    bne askSecondMatrixId // Si existe, continuamos con operador 2
    bl generalMatrixNotFound // Si no existe, mostramos mensaje
    b askFirstMatrixId // volvemos a pedir operador 1

askSecondMatrixId:
    bl generalAskIdSecondMatrix // Imprime "Ingrese el ID de la matriz (A-Z) Operador 2: "
    bl readMatrixIdFromConsole // Lee ID del operador 2, retorna 0 si es inválido
    cmp x0, #0
    bne continueSecondMatrixId // Si el ID es válido, continuamos con búsqueda
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje y volvemos a pedir
    b askSecondMatrixId

continueSecondMatrixId:
    bl getMatrixById // Busca matriz operador 2 por ID, retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-24] // Guardamos puntero operador 2
    str w1, [fp, #-28] // Guardamos filas operador 2
    str w2, [fp, #-32] // Guardamos columnas operador 2

    cmp x0, #0
    bne validateEqualDimensions // Si existe, validamos dimensiones
    bl generalMatrixNotFound // Si no existe, mostramos mensaje
    b askSecondMatrixId // volvemos a pedir operador 2

validateEqualDimensions:
    ldr w9, [fp, #-12] // Cargamos filas operador 1
    ldr w10, [fp, #-28] // Cargamos filas operador 2
    cmp w9, w10
    bne noEqualDimensions // Si filas no coinciden, no se puede sumar

    ldr w9, [fp, #-16] // Cargamos columnas operador 1
    ldr w10, [fp, #-32] // Cargamos columnas operador 2
    cmp w9, w10
    bne noEqualDimensions // Si columnas no coinciden, no se puede sumar

    // Si dimensiones son compatibles, liberamos resultado previo y reservamos nueva matriz resultado
    bl freePreviousMatrixResult
    ldr w0, [fp, #-12] // filas resultado = filas operador 1
    ldr w1, [fp, #-16] // columnas resultado = columnas operador 1
    bl mallocResultMatrix // reservamos memoria para matriz resultado

    // Traemos metadata de la matriz resultado
    ldr x11, =matrixResultPointer
    ldr x11, [x11]
    str x11, [fp, #-40] // puntero resultado
    ldr x11, =matrixResultRows
    ldr w1, [x11]
    str w1, [fp, #-44] // filas resultado
    ldr x11, =matrixResultCols
    ldr w2, [x11]
    str w2, [fp, #-48] // columnas resultado

    mov w9, #0
    str w9, [fp, #-52] // i = 0

/* -----------------------------------------------------
* Bucle doble para sumar elemento por elemento:
* resultado[i][j] = operador1[i][j] + operador2[i][j]
-----------------------------------------------------*/
additionRowsLoop:
    ldr w9, [fp, #-52] // Cargamos i
    ldr w10, [fp, #-44] // Cargamos total de filas del resultado
    cmp w9, w10
    bge printAdditionResult // Si terminamos todas las filas, imprimimos resultado

    mov w10, #0
    str w10, [fp, #-56] // j = 0

additionColsLoop:
    ldr w9, [fp, #-52] // Cargamos i
    ldr w10, [fp, #-56] // Cargamos j
    ldr w11, [fp, #-48] // Cargamos total de columnas del resultado
    cmp w10, w11
    bge nextAdditionRow // Si terminamos columnas, pasamos a siguiente fila

    // Offset: (i * columnas + j) * 4
    mul w13, w9, w11
    add w13, w13, w10
    lsl w14, w13, #2

    // Cargamos operador1[i][j]
    ldr x15, [fp, #-8]
    ldr w12, [x15, x14]

    // Cargamos operador2[i][j]
    ldr x15, [fp, #-24]
    ldr w13, [x15, x14]

    // Aplicamos operación seleccionada y guardamos en resultado[i][j]
    ldr w11, [fp, #-60] // Cargamos modo: 0 suma, 1 resta
    cmp w11, #0
    beq doAddition
    sub w12, w12, w13 // resta: operador1 - operador2
    b storeAddSubResult

doAddition:
    add w12, w12, w13 // suma: operador1 + operador2

storeAddSubResult:
    ldr x15, [fp, #-40]
    str w12, [x15, x14]

    add w10, w10, #1 // j++
    str w10, [fp, #-56]
    b additionColsLoop

nextAdditionRow:
    ldr w9, [fp, #-52] // Cargamos i
    add w9, w9, #1 // i++
    str w9, [fp, #-52]
    b additionRowsLoop

noEqualDimensions:
    bl generalNoEqualDimensions // Mostramos mensaje de dimensiones incompatibles
    b endSetAdditionMatrix

printAdditionResult:
    bl printLastResult // Imprime la matriz resultado de la suma
    b endSetAdditionMatrix

endSetAdditionMatrix:
    add sp, sp, #64
    ldp fp, lr, [sp], #0x10
    ret
