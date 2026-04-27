.global setInverseMatrix
.global setInverseMatrixNoAsk

/* ---------------------------------------------------------
 * Seccion de datos
 * --------------------------------------------------------- */
.section .data
    .align 2
    strInverseMatrixInput: .string "Matriz a invertir: "
    strInverseResult: .string "Inversa:\n"
    strInverseNoExists: .string "La matriz no tiene inversa (determinante 0 / pivote nulo).\n"

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text

/* -----------------------------------------------------
* setInverseMatrix:
* Wrapper que solicita el ID de la matriz y delega el cálculo real a
* setInverseMatrixNoAsk.
*
* Entrada:
* Por teclado (ID de matriz)
*
* Retorno:
* x0 = 1 si se calculó inversa, 0 en caso contrario.
* ----------------------------------------------------- */
setInverseMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #16 // Espacio mínimo para guardar el ID seleccionado

inverseAskMatrixId:
    ldr x0, =strAskIdUniqueOperation
    bl printString // Imprime "Ingrese el ID de la matriz a operar (A-Z): "
    bl readMatrixIdFromConsole // Lee ID, retorna 0 si es inválido
    cmp x0, #0
    bne inverseCallNoAsk
    bl generalStrCharInvalid
    b inverseAskMatrixId

inverseCallNoAsk:
    str w0, [fp, #-8] // Guardamos el ID para delegar sin volver a pedir entrada
    ldr w0, [fp, #-8]
    bl setInverseMatrixNoAsk

inverseWrapperEnd:
    add sp, sp, #16
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* setInverseMatrixNoAsk:
* Calcula la inversa de una matriz cuadrada mediante Gauss-Jordan sobre una
* matriz aumentada [A | I].
*
* Flujo:
* 1) Valida que A exista y sea cuadrada
* 2) Construye matriz aumentada de tamaño n x (2n)
* 3) Aplica Gauss-Jordan completo (normalización y eliminación arriba/abajo)
* 4) Copia el bloque derecho como inversa en matrixResultPointer
*
* Entrada:
* x0 = ID de matriz a invertir
*
* Retorno:
* x0 = 1 si se calculó inversa, 0 en caso contrario.
* ----------------------------------------------------- */
setInverseMatrixNoAsk:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #80 // locales: A, dims, aug, bytes, n2, indices y temporales

/* -----------------------------------------------------
* Layout de locales (fp-):
* -8   = puntero A
* -12  = filas A (n)
* -16  = columnas A
* -24  = puntero Aug [A|I]
* -32  = bytes reservados de Aug
* -36  = columnas de Aug (2n)
* -40  = k pivote
* -44  = i fila
* -48  = j columna
* -52  = fila pivote encontrada r
* -56  = valor pivot (32 bits)
* -60  = factor fila i (32 bits)
* -64  = temporal valor
* -68  = ID ASCII
* -72  = flag de éxito (1/0)
* -76  = estado de retorno (1=inversa calculada, 0=fallo)
------------------------------------------------------ */

inverseNoAskStart:
    str w0, [fp, #-68] // Guardamos ID para impresión de operando
    mov w9, #1
    str w9, [fp, #-72] // Iniciamos con éxito tentativo
    mov w9, #0
    str w9, [fp, #-76] // Estado retorno por defecto: fallo

    // Buscamos la matriz origen A.
    bl getMatrixById
    str x0, [fp, #-8] // puntero A
    str w1, [fp, #-12] // filas A
    str w2, [fp, #-16] // columnas A

    cmp x0, #0
    bne inverseValidateSquare
    bl generalMatrixNotFound
    mov x0, #0
    b inverseNoAskEnd

inverseValidateSquare:
    // La inversa solo existe para matrices cuadradas.
    ldr w9, [fp, #-12]
    ldr w10, [fp, #-16]
    cmp w9, w10
    beq inversePrintOperand
    bl generalNotSquareMatrix
    mov x0, #0
    b inverseNoAskEnd

inversePrintOperand:
    // Imprimimos la matriz original antes de operar.
    ldr x0, =strInverseMatrixInput
    bl printString
    bl printEnter
    ldr w0, [fp, #-68]
    bl printMatrixByIdNoAsk
    bl printEnter

    // Calculamos columnas de Aug = 2n y bytes = n * (2n) * 4.
    ldr w9, [fp, #-12] // n
    lsl w10, w9, #1 // 2n
    str w10, [fp, #-36]
    mul w11, w9, w10
    lsl w11, w11, #2
    str w11, [fp, #-32]
    uxtw x0, w11
    bl matrixMalloc
    str x0, [fp, #-24]

    // Inicializamos Aug con [A | I].
    mov w9, #0
    str w9, [fp, #-44] // i = 0

inverseFillRowsLoop:
    ldr w9, [fp, #-44] // i
    ldr w10, [fp, #-12] // n
    cmp w9, w10
    bge inverseStartJordan

    mov w11, #0
    str w11, [fp, #-48] // j = 0

inverseFillColsLoop:
    ldr w9, [fp, #-44] // i
    ldr w11, [fp, #-48] // j
    ldr w12, [fp, #-36] // 2n
    cmp w11, w12
    bge inverseNextFillRow

    // Si j < n, copiamos A[i][j].
    ldr w10, [fp, #-12] // n
    cmp w11, w10
    bge inverseFillIdentitySide

    // Offset en A: (i*n + j)*4
    mul w13, w9, w10
    add w13, w13, w11
    lsl w14, w13, #2
    ldr x15, [fp, #-8]
    ldr w16, [x15, x14]

    // Offset en Aug: (i*(2n) + j)*4
    ldr w12, [fp, #-36]
    mul w13, w9, w12
    add w13, w13, w11
    lsl w14, w13, #2
    ldr x15, [fp, #-24]
    str w16, [x15, x14]
    b inverseAdvanceFillCol

inverseFillIdentitySide:
    // Para j >= n, construimos I en el bloque derecho.
    sub w13, w11, w10 // jr = j - n
    cmp w13, w9
    bne inverseStoreZeroIdentity
    mov w16, #1
    b inverseStoreIdentityValue

inverseStoreZeroIdentity:
    mov w16, #0

inverseStoreIdentityValue:
    // Offset en Aug: (i*(2n) + j)*4
    ldr w12, [fp, #-36]
    mul w13, w9, w12
    add w13, w13, w11
    lsl w14, w13, #2
    ldr x15, [fp, #-24]
    str w16, [x15, x14]

inverseAdvanceFillCol:
    add w11, w11, #1
    str w11, [fp, #-48]
    b inverseFillColsLoop

inverseNextFillRow:
    ldr w9, [fp, #-44]
    add w9, w9, #1
    str w9, [fp, #-44]
    b inverseFillRowsLoop

inverseStartJordan:
    // Iniciamos Gauss-Jordan en Aug.
    mov w9, #0
    str w9, [fp, #-40] // k = 0

inverseKLoop:
    ldr w9, [fp, #-40] // k
    ldr w10, [fp, #-12] // n
    cmp w9, w10
    bge inverseBuildResult

    // Buscamos fila pivote r >= k con Aug[r][k] != 0.
    str w9, [fp, #-52] // r = k

inverseFindPivotLoop:
    ldr w11, [fp, #-52] // r
    ldr w10, [fp, #-12] // n
    cmp w11, w10
    bge inverseSingularFail

    ldr w12, [fp, #-36] // 2n
    mul w13, w11, w12
    add w13, w13, w9
    lsl w14, w13, #2
    ldr x15, [fp, #-24]
    ldr w16, [x15, x14]
    cbnz w16, inversePivotFound

    add w11, w11, #1
    str w11, [fp, #-52]
    b inverseFindPivotLoop

inversePivotFound:
    // Si r != k, intercambiamos filas completas en Aug.
    ldr w11, [fp, #-52] // r
    cmp w11, w9
    beq inverseLoadPivot

    mov w12, #0
    str w12, [fp, #-48] // j = 0

inverseSwapColsLoop:
    ldr w12, [fp, #-48] // j
    ldr w13, [fp, #-36] // 2n
    cmp w12, w13
    bge inverseLoadPivot

    // offset k,j
    mul w14, w9, w13
    add w14, w14, w12
    lsl w14, w14, #2

    // offset r,j
    mul w15, w11, w13
    add w15, w15, w12
    lsl w15, w15, #2

    ldr x16, [fp, #-24]
    ldr w17, [x16, x14]
    ldr w18, [x16, x15]
    str w18, [x16, x14]
    str w17, [x16, x15]

    add w12, w12, #1
    str w12, [fp, #-48]
    b inverseSwapColsLoop

inverseLoadPivot:
    // pivot = Aug[k][k]
    ldr w12, [fp, #-36] // 2n
    mul w13, w9, w12
    add w13, w13, w9
    lsl w14, w13, #2
    ldr x15, [fp, #-24]
    ldr w16, [x15, x14]
    str w16, [fp, #-56]
    cbnz w16, inverseNormalizePivotRow

inverseSingularFail:
    mov w9, #0
    str w9, [fp, #-72]
    b inversePrintFail

inverseNormalizePivotRow:
    // Normalizamos fila pivote: Aug[k][j] /= pivot para j en [0, 2n).
    mov w12, #0
    str w12, [fp, #-48] // j = 0

inverseNormalizeLoop:
    ldr w12, [fp, #-48] // j
    ldr w13, [fp, #-36] // 2n
    cmp w12, w13
    bge inverseEliminateOtherRows

    mul w14, w9, w13
    add w14, w14, w12
    lsl w14, w14, #2
    ldr x15, [fp, #-24]
    ldrsw x16, [x15, x14]

    ldrsw x17, [fp, #-56]
    sdiv x16, x16, x17
    str w16, [x15, x14]

    add w12, w12, #1
    str w12, [fp, #-48]
    b inverseNormalizeLoop

inverseEliminateOtherRows:
    // Eliminamos columna k para todas las filas i != k.
    mov w10, #0
    str w10, [fp, #-44] // i = 0

inverseILoop:
    ldr w10, [fp, #-44] // i
    ldr w11, [fp, #-12] // n
    cmp w10, w11
    bge inverseNextK

    cmp w10, w9
    beq inverseNextI

    // factor = Aug[i][k]
    ldr w12, [fp, #-36] // 2n
    mul w13, w10, w12
    add w13, w13, w9
    lsl w14, w13, #2
    ldr x15, [fp, #-24]
    ldr w16, [x15, x14]
    str w16, [fp, #-60]
    cbz w16, inverseNextI

    mov w12, #0
    str w12, [fp, #-48] // j = 0

inverseJLoop:
    ldr w12, [fp, #-48] // j
    ldr w13, [fp, #-36] // 2n
    cmp w12, w13
    bge inverseForceZeroAtPivot

    // aij = Aug[i][j]
    mul w14, w10, w13
    add w14, w14, w12
    lsl w14, w14, #2
    ldr x15, [fp, #-24]
    ldrsw x16, [x15, x14]

    // akj = Aug[k][j]
    mul w17, w9, w13
    add w17, w17, w12
    lsl w17, w17, #2
    ldrsw x18, [x15, x17]

    // Aug[i][j] = aij - factor*akj
    ldrsw x19, [fp, #-60]
    mul x20, x19, x18
    sub x21, x16, x20
    str w21, [x15, x14]

    add w12, w12, #1
    str w12, [fp, #-48]
    b inverseJLoop

inverseForceZeroAtPivot:
    // Forzamos Aug[i][k] = 0 para estabilizar la forma reducida.
    ldr w13, [fp, #-36] // 2n
    mul w14, w10, w13
    add w14, w14, w9
    lsl w14, w14, #2
    ldr x15, [fp, #-24]
    str wzr, [x15, x14]

inverseNextI:
    ldr w10, [fp, #-44]
    add w10, w10, #1
    str w10, [fp, #-44]
    b inverseILoop

inverseNextK:
    ldr w9, [fp, #-40]
    add w9, w9, #1
    str w9, [fp, #-40]
    b inverseKLoop

inverseBuildResult:
    // Construimos resultado final (n x n) con el bloque derecho de Aug.
    bl freePreviousMatrixResult
    ldr w0, [fp, #-12] // n
    ldr w1, [fp, #-12] // n
    bl mallocResultMatrix

    // Cargamos metadata del resultado para copiar la inversa.
    ldr x9, =matrixResultPointer
    ldr x9, [x9]
    str x9, [fp, #-8] // Reutilizamos local de puntero como base resultado final

    mov w9, #0
    str w9, [fp, #-44] // i = 0

inverseCopyRowsLoop:
    ldr w9, [fp, #-44] // i
    ldr w10, [fp, #-12] // n
    cmp w9, w10
    bge inversePrintSuccess

    mov w11, #0
    str w11, [fp, #-48] // j = 0

inverseCopyColsLoop:
    ldr w11, [fp, #-48] // j
    ldr w10, [fp, #-12] // n
    cmp w11, w10
    bge inverseNextCopyRow

    // Leemos Aug[i][j+n].
    ldr w12, [fp, #-36] // 2n
    add w13, w11, w10 // j+n
    mul w14, w9, w12
    add w14, w14, w13
    lsl w14, w14, #2
    ldr x15, [fp, #-24]
    ldr w16, [x15, x14]

    // Escribimos resultado[i][j].
    mul w14, w9, w10
    add w14, w14, w11
    lsl w14, w14, #2
    ldr x15, [fp, #-8]
    str w16, [x15, x14]

    add w11, w11, #1
    str w11, [fp, #-48]
    b inverseCopyColsLoop

inverseNextCopyRow:
    ldr w9, [fp, #-44]
    add w9, w9, #1
    str w9, [fp, #-44]
    b inverseCopyRowsLoop

inversePrintSuccess:
    ldr x0, =strInverseResult
    bl printString
    bl printLastResult
    bl printEnter
    mov w9, #1
    str w9, [fp, #-76] // Marcamos éxito antes de liberar temporales
    b inverseFreeAugAndReturn

inversePrintFail:
    ldr x0, =strInverseNoExists
    bl printString
    mov w9, #0
    str w9, [fp, #-76] // Marcamos fallo antes de liberar temporales

inverseFreeAugAndReturn:
    // Liberamos la matriz aumentada temporal si fue reservada.
    ldr x9, [fp, #-24]
    cbz x9, inverseNoAskEnd
    ldr w10, [fp, #-32]
    uxtw x1, w10
    mov x0, x9
    bl matrixFree

inverseNoAskEnd:
    ldr w0, [fp, #-76] // Recuperamos estado final (evita que matrixFree lo sobrescriba)
    add sp, sp, #80
    ldp fp, lr, [sp], #0x10
    ret
