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
    bne divContinueFirstMatrixId
    bl generalStrCharInvalid
    b divAskFirstMatrixId

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
    bne divContinueSecondMatrixId
    bl generalStrCharInvalid
    b divAskSecondMatrixId

divContinueSecondMatrixId:
    str w0, [fp, #-88] // Guardamos el ID ASCII de B para reutilizarlo
    bl getMatrixById
    str x0, [fp, #-24] // puntero B
    str w1, [fp, #-28] // filas B
    str w2, [fp, #-32] // columnas B

    cmp x0, #0
    bne divValidateBIsSquare
    bl generalMatrixNotFound
    b divAskSecondMatrixId

divValidateBIsSquare:
    // B debe ser cuadrada para poder invertirla.
    ldr w9, [fp, #-28]
    ldr w10, [fp, #-32]
    cmp w9, w10
    beq divPrintOperands
    bl generalNotSquareMatrix
    b divEnd

divPrintOperands:
    // Mostramos las matrices a operar.
    ldr x0, =strFirstMatrix
    bl printString
    bl printEnter
    ldr w0, [fp, #-84]
    bl printMatrixByIdNoAsk
    ldr x0, =strSecondMatrix
    bl printString
    bl printEnter
    ldr w0, [fp, #-88]
    bl printMatrixByIdNoAsk
    bl printEnter

    // Calculamos inv(B) en matrixResultPointer.
    ldr x0, =strDivisionCalcInverse
    bl printString
    ldr w0, [fp, #-88]
    bl setInverseMatrixNoAsk
    cmp x0, #1
    beq divLoadInverseResult
    b divEnd // setInverseMatrixNoAsk ya mostró mensaje de fallo

divLoadInverseResult:
    // Traemos puntero y dimensiones de inv(B).
    bl getMatrixResult
    str x0, [fp, #-40] // puntero inv(B) en resultado actual
    str w1, [fp, #-44] // filas inv(B)
    str w2, [fp, #-48] // columnas inv(B)

    cmp x0, #0
    beq divEnd

    // Validamos compatibilidad para A * inv(B): colsA == rowsInv.
    ldr w9, [fp, #-16]
    ldr w10, [fp, #-44]
    cmp w9, w10
    beq divCopyInverseTemp
    bl generalColsNotEqualRows
    b divEnd

divCopyInverseTemp:
    // Copiamos inv(B) a un buffer temporal porque matrixResult se reutilizará para el producto.
    ldr w9, [fp, #-44]
    ldr w10, [fp, #-48]
    mul w11, w9, w10
    lsl w11, w11, #2
    str w11, [fp, #-92]
    uxtw x0, w11
    bl matrixMalloc
    str x0, [fp, #-40] // Ahora -40 apunta al buffer temporal

    // Copiamos elemento a elemento desde el resultado actual (inv(B)) al temporal.
    bl getMatrixResult
    str x0, [fp, #-24] // Reutilizamos -24 como puntero fuente inv(B)

    mov w9, #0
    str w9, [fp, #-68] // i = 0

divCopyRowsLoop:
    ldr w9, [fp, #-68] // i
    ldr w10, [fp, #-44] // filas inv
    cmp w9, w10
    bge divPrepareResult

    mov w11, #0
    str w11, [fp, #-72] // j = 0

divCopyColsLoop:
    ldr w11, [fp, #-72] // j
    ldr w12, [fp, #-48] // cols inv
    cmp w11, w12
    bge divNextCopyRow

    mul w13, w9, w12
    add w13, w13, w11
    lsl w14, w13, #2

    ldr x15, [fp, #-24] // fuente inv(B)
    ldr w16, [x15, x14]
    ldr x15, [fp, #-40] // destino temporal
    str w16, [x15, x14]

    add w11, w11, #1
    str w11, [fp, #-72]
    b divCopyColsLoop

divNextCopyRow:
    ldr w9, [fp, #-68]
    add w9, w9, #1
    str w9, [fp, #-68]
    b divCopyRowsLoop

divPrepareResult:
    // Reservamos resultado final para A * inv(B).
    bl freePreviousMatrixResult
    ldr w0, [fp, #-12] // filas A
    ldr w1, [fp, #-48] // cols inv(B)
    bl mallocResultMatrix

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

    mov w9, #0
    str w9, [fp, #-68] // i = 0

/* -----------------------------------------------------
* Triple loop duplicado de multiplicación:
* resultado[i][j] = sum(k=0..colsA-1) A[i][k] * inv(B)[k][j]
-----------------------------------------------------*/
divRowsLoop:
    ldr w9, [fp, #-68] // i
    ldr w10, [fp, #-60] // filas resultado
    cmp w9, w10
    bge divPrintResult

    mov w10, #0
    str w10, [fp, #-72] // j = 0

divColsLoop:
    ldr w9, [fp, #-68] // i
    ldr w10, [fp, #-72] // j
    ldr w12, [fp, #-64] // cols resultado
    cmp w10, w12
    bge divNextRow

    mov w15, #0
    str w15, [fp, #-80] // acumulador = 0
    mov w11, #0
    str w11, [fp, #-76] // k = 0

divInnerLoop:
    ldr w11, [fp, #-76] // k
    ldr w12, [fp, #-16] // cols A
    cmp w11, w12
    bge divStoreResult

    // Offset A: (i * colsA + k) * 4
    ldr w9, [fp, #-68] // i
    mul w13, w9, w12
    add w13, w13, w11
    lsl w14, w13, #2
    ldr x15, [fp, #-8]
    ldr w12, [x15, x14]

    // Offset invTemp: (k * colsInv + j) * 4
    ldr w10, [fp, #-72] // j
    ldr w13, [fp, #-48] // colsInv
    mul w14, w11, w13
    add w14, w14, w10
    lsl w14, w14, #2
    ldr x15, [fp, #-40] // puntero invTemp
    ldr w13, [x15, x14]

    // acumulador += A[i][k] * invTemp[k][j]
    mul w14, w12, w13
    ldr w15, [fp, #-80]
    add w15, w15, w14
    str w15, [fp, #-80]

    add w11, w11, #1
    str w11, [fp, #-76]
    b divInnerLoop

divStoreResult:
    // Offset resultado: (i * colsR + j) * 4
    ldr w9, [fp, #-68] // i
    ldr w10, [fp, #-72] // j
    ldr w12, [fp, #-64] // cols resultado
    mul w13, w9, w12
    add w13, w13, w10
    lsl w14, w13, #2

    ldr x15, [fp, #-56]
    ldr w12, [fp, #-80]
    str w12, [x15, x14]

    add w10, w10, #1
    str w10, [fp, #-72]
    b divColsLoop

divNextRow:
    ldr w9, [fp, #-68]
    add w9, w9, #1
    str w9, [fp, #-68]
    b divRowsLoop

divPrintResult:
    ldr x0, =strDivisionResult
    bl printString
    bl printLastResult
    bl printEnter

    // Liberamos buffer temporal de inv(B).
    ldr x9, [fp, #-40]
    cbz x9, divEnd
    ldr w10, [fp, #-92]
    uxtw x1, w10
    mov x0, x9
    bl matrixFree

divEnd:
    add sp, sp, #96
    ldp fp, lr, [sp], #0x10
    ret
