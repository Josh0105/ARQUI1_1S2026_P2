.global setDivisionMatrix

/* ---------------------------------------------------------
 * Seccion de datos
 * --------------------------------------------------------- */
.section .data
    .align 2
    strDivisionCalcInverse: .string "Calculando inversa del Operador 2...\n"
    strDivisionResult: .string "\nResultado A * inv(B):\n"

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text

/* -----------------------------------------------------
* setDivisionMatrix:
* Calcula la división matricial A / B como A * inv(B).
*
* Flujo:
* 1) Solicita y valida operadores A y B
* 2) Calcula inv(B) usando setInverseMatrixNoAsk
* 3) Duplica el algoritmo de multiplicación para A * inv(B)
*    sin tocar la función setMultiplicationMatrix existente
*
* Entrada:
* Por teclado para IDs
*
* Retorno:
* Se almacena la matriz resultado en matrixResultPointer.
* ----------------------------------------------------- */
setDivisionMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #96 // locales: A, B, invTemp, resultado e indices

/* -----------------------------------------------------
* Layout de locales (fp-):
* -8   = puntero A
* -12  = filas A
* -16  = columnas A
* -24  = puntero B
* -28  = filas B
* -32  = columnas B
* -40  = puntero inv(B) temporal (copia)
* -44  = filas inv(B)
* -48  = columnas inv(B)
* -56  = puntero resultado
* -60  = filas resultado
* -64  = columnas resultado
* -68  = i
* -72  = j
* -76  = k
* -80  = acumulador
* -84  = ID A
* -88  = ID B
* -92  = bytes inv(B) temporal
------------------------------------------------------ */

divAskFirstMatrixId:
    bl generalAskIdFirstMatrix // Imprime "Ingrese el ID de la matriz (A-Z) Operador 1: "
    bl readMatrixIdFromConsole // Lee ID del operador 1, retorna 0 si es inválido
    cmp x0, #0
    bne divContinueFirstMatrixId // Si el ID es válido, continuamos con búsqueda de la matriz
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje y volvemos a pedir
    b divAskFirstMatrixId // Volvemos a pedir el ID de A para el operador 1

divContinueFirstMatrixId:
    str w0, [fp, #-84] // Guardamos el ID ASCII de A para reutilizarlo en impresión
    bl getMatrixById
    str x0, [fp, #-8] // puntero A
    str w1, [fp, #-12] // filas A
    str w2, [fp, #-16] // columnas A

    cmp x0, #0
    bne divAskSecondMatrixId
    bl generalMatrixNotFound
    b divAskFirstMatrixId

divAskSecondMatrixId:
    bl generalAskIdSecondMatrix // Imprime "Ingrese el ID de la matriz (A-Z) Operador 2: "
    bl readMatrixIdFromConsole // Lee ID del operador 2, retorna 0 si es inválido
    cmp x0, #0
    bne divContinueSecondMatrixId // Si el ID es válido, continuamos con la bósqueda
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje y volvemos a pedir
    b divAskSecondMatrixId // Si el ID es válido, continuamos con búsqueda de la matriz

divContinueSecondMatrixId:
    str w0, [fp, #-88] // Guardamos el ID ASCII de B para reutilizarlo
    bl getMatrixById
    str x0, [fp, #-24] // puntero B
    str w1, [fp, #-28] // filas B
    str w2, [fp, #-32] // columnas B

    cmp x0, #0
    bne divValidateBIsSquare // Si existe, validamos que B sea cuadrada para poder invertir
    bl generalMatrixNotFound // Si no existe, mostramos mensaje
    b divAskSecondMatrixId // volvemos a pedir operador 2

divValidateBIsSquare:
    // B debe ser cuadrada para poder invertirla.
    ldr w9, [fp, #-28] // Cargamos filas de B
    ldr w10, [fp, #-32] // Cargamos columnas de B
    cmp w9, w10
    beq divPrintOperands // Si B es cuadrada, continuamos con la operación
    bl generalNotSquareMatrix // Si no es cuadrada, mostramos mensaje de error
    b divEnd // terminamos sin modificar matrixResultPointer

divPrintOperands:
    // Mostramos las matrices a operar.
    ldr x0, =strFirstMatrix
    bl printString // Imprime "Primera matriz (A):"
    bl printEnter
    ldr w0, [fp, #-84] // Cargamos el ID ASCII de A
    bl printMatrixByIdNoAsk // Imprime la matriz A usando su ID, sin pedirlo nuevamente
    ldr x0, =strSecondMatrix
    bl printString // Imprime "Segunda matriz (B):"
    bl printEnter
    ldr w0, [fp, #-88]//Cargamos el ID ASCII de B
    bl printMatrixByIdNoAsk // Imprime la matriz B usando su ID, sin pedirlo nuevamente
    bl printEnter

    // Calculamos inv(B) en matrixResultPointer.
    ldr x0, =strDivisionCalcInverse
    bl printString // Imprime "Calculando inversa del Operador 2..."
    ldr w0, [fp, #-88]
    bl setInverseMatrixNoAsk // Calcula inv(B), resultado en matrixResultPointer, retorno en w0: 1 si se calculó, 0 si no se pudo calcular
    cmp x0, #1 // Verificamos si se calculó la inversa correctamente
    beq divLoadInverseResult // Si se calculó, continuamos con la multiplicación A * inv(B)
    b divEnd // setInverseMatrixNoAsk mostró mensaje de error específico para el caso, así que solo terminamos sin modificar matrixResultPointer

divLoadInverseResult:
    // Traemos puntero y dimensiones de inv(B).
    bl getMatrixResult
    str x0, [fp, #-40] // puntero inv(B) en resultado actual
    str w1, [fp, #-44] // filas inv(B)
    str w2, [fp, #-48] // columnas inv(B)

    cmp x0, #0 
    beq divEnd // Aunque setInverseMatrixNoAsk debería haber retornado 0 o 1, validamos que el puntero no sea 0 antes de continuar para evitar errores posteriores. Si es 0, terminamos sin modificar matrixResultPointer.

    // Validamos compatibilidad para A * inv(B): colsA == rowsInv.
    ldr w9, [fp, #-16] // Cargamos columnas de A
    ldr w10, [fp, #-44] // Cargamos filas de inv(B)
    cmp w9, w10
    beq divCopyInverseTemp // Si las dimensiones son compatibles, continuamos con la multiplicación
    bl generalColsNotEqualRows // Si no son compatibles, mostramos mensaje de error específico para multiplicación
    b divEnd // terminamos

// Copiamos inv(B) a un buffer temporal porque matrixResult se reutilizará para el producto.
divCopyInverseTemp:
    ldr w9, [fp, #-44] // filas inv(B)
    ldr w10, [fp, #-48] // columnas inv(B)
    mul w11, w9, w10 // Calculamos cantidad de elementos en inv(B)
    lsl w11, w11, #2 // Multiplicamos por 4 para obtener bytes totales de inv(B)
    str w11, [fp, #-92] // Guardamos bytes necesarios para el buffer temporal
    uxtw x0, w11 // Convertimos a 64 bits para matrixMalloc
    bl matrixMalloc // Reservamos buffer temporal para inv(B)
    str x0, [fp, #-40] // Ahora -40 apunta al buffer temporal

    // Copiamos elemento a elemento desde el resultado actual (inv(B)) al temporal.
    bl getMatrixResult // Traemos nuevamente el puntero de inv(B) para copiar desde allí
    str x0, [fp, #-24] // Reutilizamos -24 como puntero fuente inv(B)

    mov w9, #0 // i = 0
    str w9, [fp, #-68] // cargamos i en el stack

divCopyRowsLoop:
    ldr w9, [fp, #-68] // cargamos i
    ldr w10, [fp, #-44] // Cargamos filas de inv(B)
    cmp w9, w10
    bge divPrepareResult // Si i >= filas inv(B), terminamos de copiar

    mov w11, #0 // j = 0
    str w11, [fp, #-72] // Guardamos j en el stack

// Copiamos la fila i completa de inv(B) al buffer temporal.
divCopyColsLoop:
    ldr w11, [fp, #-72] // cargamos j
    ldr w12, [fp, #-48] // CArgamos columnas de inv(B)
    cmp w11, w12
    bge divNextCopyRow // Si j >= columnas inv(B), terminamos de copiar la fila

    mul w13, w9, w12 // Offset en elementos: i * columnas inv(B)
    add w13, w13, w11 // Sumamos j para obtener el offset total en elementos: i * columnas + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes

    ldr x15, [fp, #-24] // Cargamos puntero fuente inv(B)
    ldr w16, [x15, x14] // Cargamos el valor de inv(B)[i][j] en w16
    ldr x15, [fp, #-40] // Cargamos puntero destino temporal
    str w16, [x15, x14] // Almacenamos el valor en el mismo offset del buffer temporal

    add w11, w11, #1 // j++
    str w11, [fp, #-72] // Guardamos j actualizado
    b divCopyColsLoop // Volvemos a copiar la siguiente columna de la misma fila

// Incrementamos i para copiar la siguiente fila completa
divNextCopyRow:
    ldr w9, [fp, #-68]
    add w9, w9, #1 // i++
    str w9, [fp, #-68] // Guardamos i actualizado
    b divCopyRowsLoop

// Ahora el buffer temporal tiene una copia de inv(B) y podemos reutilizar matrixResult para almacenar el resultado final de A * inv(B) sin perder la inversa calculada.
divPrepareResult:
    // Reservamos resultado final para A * inv(B).
    bl freePreviousMatrixResult // Liberamos cualquier resultado previo almacenado en matrixResultPointer antes de guardar el nuevo resultado
    ldr w0, [fp, #-12] // Cargamos filas de A para el resultado
    ldr w1, [fp, #-48] // Cargamos columnas de inv(B) para el resultado
    bl mallocResultMatrix // reservamos memoria para la matriz resultado enviando filas de A y columnas de inv(B)

    // Cargamos metadata del resultado.
    ldr x11, =matrixResultPointer
    ldr x11, [x11]
    str x11, [fp, #-56]
    ldr x11, =matrixResultRows
    ldr w1, [x11]
    str w1, [fp, #-60]
    ldr x11, =matrixResultCols
    ldr w2, [x11]
    str w2, [fp, #-64]

    mov w9, #0 // i = 0
    str w9, [fp, #-68] // Guardamos i en el stack para la multiplicación

/* -----------------------------------------------------
* Triple loop, utilizamos el mismo algoritmo que aplicamos en la multiplicación de matrices, pero ahora con el buffer temporal de inv(B) en lugar de B:
* resultado[i][j] = sum(k=0..colsA-1) A[i][k] * inv(B)[k][j]
-----------------------------------------------------*/
divRowsLoop:
    ldr w9, [fp, #-68] // Cargamos i
    ldr w10, [fp, #-60] // Cargamos total de filas del resultado
    cmp w9, w10
    bge divPrintResult // Si terminamos todas las filas, imprimimos resultado

    mov w10, #0 // j = 0
    str w10, [fp, #-72] // Guardamos j en el stack

divColsLoop:
    ldr w9, [fp, #-68] // Cargamos i
    ldr w10, [fp, #-72] // Cargamos j
    ldr w12, [fp, #-64] // Cargamos total de columnas del resultado
    cmp w10, w12
    bge divNextRow // Si terminamos columnas, pasamos a siguiente fila

    mov w15, #0 // acumulador = 0
    str w15, [fp, #-80] // Guardamos acumulador = 0
    mov w11, #0 // k = 0
    str w11, [fp, #-76] //guardamos k en el stack

divInnerLoop:
    ldr w11, [fp, #-76] // Cargamos k
    ldr w12, [fp, #-16] // Cargamos columnas de A
    cmp w11, w12
    bge divStoreResult // Si k >= columnas de A, almacenamos el resultado acumulado en resultado[i][j]

    // Offset A: (i * colsA + k) * 4
    ldr w9, [fp, #-68] // Cargamos i
    mul w13, w9, w12 // Calculamos la posición base de la fila: i * columnas de A
    add w13, w13, w11 // Sumamos k para obtener el offset total en elementos: i * columnas + k
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-8] // Carga el puntero base de A
    ldr w12, [x15, x14] // Carga el valor de A[i][k] en w12

    // Offset invTemp: (k * colsInv + j) * 4
    ldr w10, [fp, #-72] // Cargamos j
    ldr w13, [fp, #-48] // Cargamos cols de inv(B)
    mul w14, w11, w13 // Calculamos la posición base de la fila en inv(B): k * columnas de inv(B)
    add w14, w14, w10 // Sumamos j para obtener el offset total en elementos: k * columnas + j
    lsl w14, w14, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-40] // Cargamos puntero base del buffer temporal de inv(B)
    ldr w13, [x15, x14] // Carga el valor de inv(B)[k][j] en w13

    // acumulador += A[i][k] * invTemp[k][j]
    mul w14, w12, w13 // Multiplicamos A[i][k] * inv(B)[k][j]
    ldr w15, [fp, #-80] // Cargamos acumulador
    add w15, w15, w14 // Sumamos al acumulador el producto actual
    str w15, [fp, #-80] // Guardamos el acumulador actualizado en el stack

    add w11, w11, #1 // k++
    str w11, [fp, #-76] // Guardamos k actualizado en el stack
    b divInnerLoop // Repetimos para el siguiente k
    
// Al finalizar el cálculo del acumulador para resultado[i][j], lo almacenamos en la posición correspondiente de la matriz resultado.
divStoreResult:
    // Offset resultado: (i * colsR + j) * 4
    ldr w9, [fp, #-68] // Cargamos i
    ldr w10, [fp, #-72] // Cargamos j
    ldr w12, [fp, #-64] // Cargamos columnas del resultado
    mul w13, w9, w12 // Calculamos la posición base de la fila en la matriz resultado: i * columnas de resultado
    add w13, w13, w10 // Sumamos j para obtener el offset total en elementos: i * columnas + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes

    ldr x15, [fp, #-56] // Cargamos puntero base de resultado
    ldr w12, [fp, #-80] // Cargamos acumulador final
    str w12, [x15, x14] // Guardamos resultado[i][j] = acumulador

    add w10, w10, #1 // j++
    str w10, [fp, #-72] // Guardamos j actualizado
    b divColsLoop // Repetimos para la siguiente columna de la misma fila

divNextRow:
    ldr w9, [fp, #-68] // Cargamos i
    add w9, w9, #1 // i++
    str w9, [fp, #-68] // Guardamos i actualizado
    b divRowsLoop

divPrintResult:
    ldr x0, =strDivisionResult
    bl printString
    bl printLastResult // Imprime la matriz resultado de A * inv(B)
    bl printEnter

    // Liberamos buffer temporal de inv(B).
    ldr x9, [fp, #-40] // Cargamos puntero base del buffer temporal de inv(B)
    cbz x9, divEnd // Si el puntero es 0, no se reservó el buffer temporal, así que saltamos a la limpieza final y retorno
    ldr w10, [fp, #-92]
    uxtw x1, w10 // Convertimos a 64 bits para matrixFree
    mov x0, x9 // Cargamos el puntero del buffer temporal de inv(B) para liberar
    bl matrixFree // Liberamos el buffer temporal de inv(B)

divEnd:
    add sp, sp, #96
    ldp fp, lr, [sp], #0x10
    ret
