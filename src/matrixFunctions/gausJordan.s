.global setGaussJordanMatrix
.global setGaussJordanMatrixNoAsk

/* ---------------------------------------------------------
 * Seccion de datos
 * --------------------------------------------------------- */
.section .data
    .align 2
    strGaussJordanResult: .string "Gauss-Jordan (forma reducida):\n"
    strGaussJordanIdentityOk: .string "Estado: exito, se alcanzo identidad por pivotes.\n"
    strGaussJordanIdentityFail: .string "Estado: fracaso, no se pudo alcanzar identidad por pivotes.\n"

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text

/* -----------------------------------------------------
* setGaussJordanMatrix:
* Wrapper que solicita el ID de la matriz y delega el trabajo real a
* setGaussJordanMatrixNoAsk.
*
* Entrada:
* Por teclado (ID de matriz)
*
* Retorno:
* matrixResultPointer queda con la forma reducida por filas (RREF) calculada.
* ----------------------------------------------------- */
setGaussJordanMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #16 // Espacio mínimo para guardar el ID seleccionado

gaussJordanAskMatrixId:
    ldr x0, =strAskIdUniqueOperation
    bl printString // Imprime "Ingrese el ID de la matriz a operar (A-Z): "
    bl readMatrixIdFromConsole // Lee ID, retorna 0 si es inválido
    cmp x0, #0
    bne gaussJordanCallNoAsk
    bl generalStrCharInvalid
    b gaussJordanAskMatrixId

gaussJordanCallNoAsk:
    str w0, [fp, #-8] // Guardamos el ID para delegar el cálculo sin volver a pedir entrada
    ldr w0, [fp, #-8] // Recuperamos el ID seleccionado
    bl setGaussJordanMatrixNoAsk

gaussJordanWrapperEnd:
    add sp, sp, #16
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* setGaussJordanMatrixNoAsk:
* Reutiliza la salida triangular de setGaussMatrixNoAsk y continúa el proceso
* hasta forma reducida por filas:
* 1) Normaliza la fila pivote k
* 2) Elimina arriba y abajo del pivote para todas las filas i != k
*
* Entrada:
* x0 = ID de la matriz a operar
*
* Retorno:
* matrixResultPointer queda con la forma reducida por filas (RREF) calculada.
* ----------------------------------------------------- */
setGaussJordanMatrixNoAsk:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #80 // locales: ptr C, pivot, factor, aij, akj, rows, cols, k, i, j, ID, success, pivotCount

/* -----------------------------------------------------
* Layout de locales (fp-):
* -8  = puntero C
* -16 = pivot actual (64 bits)
* -24 = factor de fila i (64 bits)
* -32 = temporal aij (64 bits)
* -40 = temporal akj (64 bits)
* -48 = filas de C
* -52 = columnas de C
* -56 = k (pivote actual)
* -60 = i (fila actual)
* -64 = j (columna actual)
* -68 = ID ASCII de la matriz
* -72 = successFlag (1=posible identidad por pivotes, 0=fallo)
* -76 = pivotCount (cantidad de pivotes no-cero procesados)
------------------------------------------------------ */

gaussJordanStart:
    str w0, [fp, #-68] // Guardamos el ID para trazabilidad y depuración local
    mov w9, #1
    str w9, [fp, #-72] // Iniciamos en exito tentativo; se invalida si algún pivote es cero
    mov w9, #0
    str w9, [fp, #-76] // Contador de pivotes válidos procesados

    // Primero obtenemos la triangular superior usando Gauss/Bareiss sin volver a pedir ID.
    bl setGaussMatrixNoAsk
    str x0, [fp, #-8] // Guardamos el puntero de la matriz resultado triangular

    cmp x0, #0
    beq gaussJordanEnd // Si Gauss no produjo resultado válido, salimos

    // Cargamos dimensiones actuales del resultado para iterar por pivotes, filas y columnas.
    ldr x9, =matrixResultRows
    ldr w10, [x9]
    str w10, [fp, #-48]
    ldr x9, =matrixResultCols
    ldr w10, [x9]
    str w10, [fp, #-52]

    mov w9, #0
    str w9, [fp, #-56] // k = 0

gaussJordanKLoop:
    // Recorremos pivotes en la diagonal principal.
    ldr w9, [fp, #-56] // k
    ldr w10, [fp, #-48] // filas
    cmp w9, w10
    bge gaussJordanPrintResult // Si terminamos pivotes, ya tenemos forma reducida

    // Leemos pivot = C[k][k]. Si es 0, esta columna no se puede normalizar.
    ldr w11, [fp, #-52] // columnas
    mul w13, w9, w11
    add w13, w13, w9
    lsl w14, w13, #2
    ldr x15, [fp, #-8]
    ldrsw x16, [x15, x14]
    str x16, [fp, #-16]

    cbnz x16, gaussJordanPivotValid // Si pivote es no-cero, continuamos con normalización

    // Si pivote es 0, marcamos fracaso para identidad y avanzamos.
    mov w9, #0
    str w9, [fp, #-72]
    b gaussJordanNextK

gaussJordanPivotValid:
    // Contamos este pivote no-cero como válido para criterio de identidad por pivotes.
    ldr w9, [fp, #-76]
    add w9, w9, #1
    str w9, [fp, #-76]

    // Normalizamos la fila pivote dividiendo cada elemento entre pivot.
    mov w12, #0
    str w12, [fp, #-64] // j = 0

gaussJordanNormalizeRowLoop:
    ldr w12, [fp, #-64] // j
    ldr w11, [fp, #-52] // columnas
    cmp w12, w11
    bge gaussJordanEliminateRows

    ldr w9, [fp, #-56] // k
    mul w13, w9, w11
    add w13, w13, w12
    lsl w14, w13, #2
    ldr x15, [fp, #-8]
    ldrsw x10, [x15, x14]

    ldr x11, [fp, #-16] // pivot
    sdiv x10, x10, x11
    str w10, [x15, x14] // C[k][j] = C[k][j] / pivot

    add w12, w12, #1
    str w12, [fp, #-64]
    b gaussJordanNormalizeRowLoop

gaussJordanEliminateRows:
    // Eliminamos la columna pivote en todas las filas i != k.
    mov w10, #0
    str w10, [fp, #-60] // i = 0

gaussJordanILoop:
    ldr w10, [fp, #-60] // i
    ldr w11, [fp, #-48] // filas
    cmp w10, w11
    bge gaussJordanNextK

    ldr w9, [fp, #-56] // k
    cmp w10, w9
    beq gaussJordanNextI // No eliminamos sobre la misma fila pivote

    // factor = C[i][k]
    ldr w11, [fp, #-52] // columnas
    mul w13, w10, w11
    add w13, w13, w9
    lsl w14, w13, #2
    ldr x15, [fp, #-8]
    ldrsw x17, [x15, x14]
    str x17, [fp, #-24]

    cbz x17, gaussJordanNextI // Si factor es 0, la fila ya está eliminada en esta columna

    mov w12, #0
    str w12, [fp, #-64] // j = 0

gaussJordanJLoop:
    ldr w12, [fp, #-64] // j
    ldr w11, [fp, #-52] // columnas
    cmp w12, w11
    bge gaussJordanForceZeroAtPivotColumn

    // aij = C[i][j]
    ldr w10, [fp, #-60] // i
    mul w13, w10, w11
    add w13, w13, w12
    lsl w14, w13, #2
    ldr x15, [fp, #-8]
    ldrsw x18, [x15, x14]
    str x18, [fp, #-32]

    // akj = C[k][j]
    ldr w9, [fp, #-56] // k
    mul w13, w9, w11
    add w13, w13, w12
    lsl w19, w13, #2
    ldrsw x20, [x15, x19]
    str x20, [fp, #-40]

    // C[i][j] = aij - factor * akj
    ldr x21, [fp, #-24] // factor
    mul x22, x21, x20
    sub x23, x18, x22
    str w23, [x15, x14]

    add w12, w12, #1
    str w12, [fp, #-64]
    b gaussJordanJLoop

gaussJordanForceZeroAtPivotColumn:
    // Forzamos explícitamente C[i][k] = 0 para mantener la forma reducida estable.
    ldr w10, [fp, #-60] // i
    ldr w9, [fp, #-56] // k
    ldr w11, [fp, #-52] // columnas
    mul w13, w10, w11
    add w13, w13, w9
    lsl w14, w13, #2
    ldr x15, [fp, #-8]
    str wzr, [x15, x14]

gaussJordanNextI:
    ldr w10, [fp, #-60]
    add w10, w10, #1
    str w10, [fp, #-60]
    b gaussJordanILoop

gaussJordanNextK:
    // Avanzamos al siguiente pivote diagonal.
    ldr w9, [fp, #-56]
    add w9, w9, #1
    str w9, [fp, #-56]
    b gaussJordanKLoop

gaussJordanPrintResult:
    ldr x0, =strGaussJordanResult
    bl printString
    bl printLastResult
    bl printEnter

    // Sin recorrer toda la matriz: declaramos identidad si fue cuadrada y todos los pivotes fueron válidos.
    ldr w9, [fp, #-48] // filas
    ldr w10, [fp, #-52] // columnas
    cmp w9, w10
    bne gaussJordanPrintFail

    ldr w11, [fp, #-72] // successFlag
    cmp w11, #1
    bne gaussJordanPrintFail

    ldr w12, [fp, #-76] // pivotCount
    cmp w12, w9
    bne gaussJordanPrintFail

    ldr x0, =strGaussJordanIdentityOk
    bl printString
    b gaussJordanEnd

gaussJordanPrintFail:
    ldr x0, =strGaussJordanIdentityFail
    bl printString

gaussJordanEnd:
    add sp, sp, #80
    ldp fp, lr, [sp], #0x10
    ret
