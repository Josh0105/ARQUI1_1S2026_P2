.global setMultiplicationMatrix

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text

/* -----------------------------------------------------
* setMultiplicationMatrix:
* Genera la matriz resultado de multiplicar dos matrices solicitadas por ID y la guarda como resultado.
* Solicita operador 1 y operador 2, valida que existan y que sean compatibles para multiplicación,
* reserva memoria para el resultado y calcula la operación con triple loop.
*
* Entrada:
* Por teclado para IDs
*
* Retorno:
* Se almacena la matriz producto en matrixResultPointer con dimensiones en matrixResultRows y matrixResultCols.
* Si no se pudo generar el producto, matrixResultPointer se conserva sin cambios.
*
* Registros importantes:
* w9  = i (fila actual del resultado)
* w10 = j (columna actual del resultado)
* w11 = k (indice interno de producto punto)
* w12 = valor temporal de A[i][k]
* w13 = valor temporal de B[k][j] / indice en elementos
* w14 = offset en bytes / término temporal
* w15 = acumulador de suma para resultado[i][j]
* x15 = puntero base temporal de matrices
* ----------------------------------------------------- */
setMultiplicationMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #80 // variables locales para operadores, resultado e indices de loops

mulAskFirstMatrixId:
    bl generalAskIdFirstMatrix // Imprime "Ingrese el ID de la matriz (A-Z) Operador 1: "
    bl readMatrixIdFromConsole // Lee ID del operador 1, retorna 0 si es inválido
    cmp x0, #0
    bne mulContinueFirstMatrixId // Si el ID es válido, continuamos con búsqueda de la matriz
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje y volvemos a pedir
    b mulAskFirstMatrixId

mulContinueFirstMatrixId:
    bl getMatrixById // Busca matriz operador 1 por ID, retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-8] // Guardamos puntero operador 1
    str w1, [fp, #-12] // Guardamos filas operador 1
    str w2, [fp, #-16] // Guardamos columnas operador 1

    cmp x0, #0
    bne mulAskSecondMatrixId // Si existe, continuamos con operador 2
    bl generalMatrixNotFound // Si no existe, mostramos mensaje
    b mulAskFirstMatrixId // volvemos a pedir operador 1

mulAskSecondMatrixId:
    bl generalAskIdSecondMatrix // Imprime "Ingrese el ID de la matriz (A-Z) Operador 2: "
    bl readMatrixIdFromConsole // Lee ID del operador 2, retorna 0 si es inválido
    cmp x0, #0
    bne mulContinueSecondMatrixId // Si el ID es válido, continuamos con búsqueda
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje y volvemos a pedir
    b mulAskSecondMatrixId

mulContinueSecondMatrixId:
    bl getMatrixById // Busca matriz operador 2 por ID, retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-24] // Guardamos puntero operador 2
    str w1, [fp, #-28] // Guardamos filas operador 2
    str w2, [fp, #-32] // Guardamos columnas operador 2

    cmp x0, #0
    bne mulValidateMultiplicationDimensions // Si existe, validamos dimensiones
    bl generalMatrixNotFound // Si no existe, mostramos mensaje
    b mulAskSecondMatrixId // volvemos a pedir operador 2

mulValidateMultiplicationDimensions:
    ldr w9, [fp, #-16] // Cargamos columnas de A
    ldr w10, [fp, #-28] // Cargamos filas de B
    cmp w9, w10
    bne mulColsNotEqualRows // Si columnas de A != filas de B, no se puede multiplicar

    // Si dimensiones son compatibles, liberamos resultado previo y reservamos nueva matriz resultado
    // Dimensiones del resultado: filasA x columnasB
    bl freePreviousMatrixResult
    ldr w0, [fp, #-12] // filas resultado = filas de A
    ldr w1, [fp, #-32] // columnas resultado = columnas de B
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
* Triple loop para multiplicación de matrices:
* resultado[i][j] = sum(k=0..colsA-1) A[i][k] * B[k][j]
-----------------------------------------------------*/
mulRowsLoop:
    ldr w9, [fp, #-52] // Cargamos i
    ldr w10, [fp, #-44] // Cargamos total de filas del resultado
    cmp w9, w10
    bge mulPrintMultiplicationResult // Si terminamos todas las filas, imprimimos resultado

    mov w10, #0
    str w10, [fp, #-56] // j = 0

mulColsLoop:
    ldr w9, [fp, #-52] // Cargamos i
    ldr w10, [fp, #-56] // Cargamos j
    ldr w12, [fp, #-48] // Cargamos total de columnas del resultado
    cmp w10, w12
    bge mulNextMulRow // Si terminamos columnas, pasamos a siguiente fila

    mov w15, #0
    str w15, [fp, #-64] // acumulador = 0
    mov w11, #0
    str w11, [fp, #-60] // k = 0

mulInnerLoop:
    ldr w11, [fp, #-60] // Cargamos k
    ldr w12, [fp, #-16] // Cargamos columnas de A
    cmp w11, w12
    bge mulStoreMulResult // Si k llegó al límite, guardamos acumulador en resultado[i][j]

    // Offset A: (i * colsA + k) * 4
    ldr w9, [fp, #-52] // Cargamos i
    mul w13, w9, w12 // Calculamos la posición base de la fila: i * columnas de A
    add w13, w13, w11 // Sumamos k para obtener el offset total en elementos: i * columnas + k
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-8] // Carga el puntero base de A
    ldr w12, [x15, x14] // Carga el valor de A[i][k] en w12

    // Offset B: (k * colsB + j) * 4
    ldr w10, [fp, #-56] // Cargamos j
    ldr w13, [fp, #-32] // Cargamos colsB
    mul w14, w11, w13 // Calculamos la posición base de la fila en B: k * columnas de B
    add w14, w14, w10 // Sumamos j para obtener el offset total en elementos: k * columnas + j
    lsl w14, w14, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Carga el puntero base de B
    ldr w13, [x15, x14] // Carga el valor de B[k][j] en w13

    // acumulador += A[i][k] * B[k][j]
    mul w14, w12, w13 // w14 = A[i][k] * B[k][j]
    ldr w15, [fp, #-64] // Cargamos acumulador actual
    add w15, w15, w14 // Sumamos al acumulador el nuevo producto
    str w15, [fp, #-64] // Guardamos el acumulador actualizado en el stack

    add w11, w11, #1 // k++
    str w11, [fp, #-60] // Guardamos k actualizado en el stack
    b mulInnerLoop // Repetimos para el siguiente k

// Luego de iterrar sobre k, guardamos el valor final del acumulador en resultado[i][j]
mulStoreMulResult:
    // Offset resultado: (i * colsR + j) * 4
    ldr w9, [fp, #-52] // Cargamos i
    ldr w10, [fp, #-56] // Cargamos j
    ldr w12, [fp, #-48] // Cargamos cols Resultado
    mul w13, w9, w12 // Calculamos la posición base de la fila en la matriz resultado: i * columnas de resultado
    add w13, w13, w10 // Sumamos j para obtener el offset total en elementos: i * columnas + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes

    ldr x15, [fp, #-40] // Carga el puntero base de la matriz resultado
    ldr w12, [fp, #-64] // Cargamos acumulador final
    str w12, [x15, x14] // Guardamos resultado[i][j] = acumulador

    add w10, w10, #1 // j++
    str w10, [fp, #-56]
    b mulColsLoop

mulNextMulRow:
    ldr w9, [fp, #-52] // Cargamos i
    add w9, w9, #1 // i++
    str w9, [fp, #-52]
    b mulRowsLoop

mulColsNotEqualRows:
    bl generalColsNotEqualRows // Mostramos mensaje de incompatibilidad para multiplicación
    b endSetMultiplicationMatrix

mulPrintMultiplicationResult:
    bl printLastResult // Imprime la matriz resultado de la multiplicación
    b endSetMultiplicationMatrix

endSetMultiplicationMatrix:
    add sp, sp, #80
    ldp fp, lr, [sp], #0x10
    ret
