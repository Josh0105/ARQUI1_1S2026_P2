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
*   El gauss-jordan se adapta para operar sobre la matriz aumentada, asegurando que las operaciones de fila se apliquen a ambos lados [A|I] simultáneamente.
*   No se utiliza el Gauss-Jordan de la sección de funciones porque este es un proceso específico para la inversa que requiere manejar la matriz aumentada 
*   y forzar ceros explícitamente para mantener la forma reducida estable y este proceso no lo tomamos en cuenta desde que se estaba usando Jordan normal.
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
    sub sp, sp, #80 // locales: A, dimensiones, Aumentada, bytes, n2, indices y temporales

/* -----------------------------------------------------
* Layout de locales (fp-):
* -8   = puntero A
* -12  = filas A (n)
* -16  = columnas A
* -24  = puntero Aumentada [A|I]
* -32  = bytes reservados de Aumentada
* -36  = columnas de Aumentada (2n)
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
    bne inverseValidateSquare // Si existe, validamos que sea cuadrada
    bl generalMatrixNotFound // Si no existe, mostramos mensaje de error
    mov x0, #0 // Retorno 0: no se calculó inversa
    b inverseNoAskEnd // Si no existe, retornamos sin modificar matrixResultPointer

inverseValidateSquare:
    // La inversa solo existe para matrices cuadradas.
    ldr w9, [fp, #-12] // filas A
    ldr w10, [fp, #-16] // columnas A
    cmp w9, w10 // n == m?
    beq inversePrintOperand // Si es cuadrada pasamos al calculo
    bl generalNotSquareMatrix // Si no es cuadrada, mostramos mensaje de error
    mov x0, #0 // Retorno 0: no se calculó inversa
    b inverseNoAskEnd

inversePrintOperand:
    // Imprimimos la matriz original antes de operar.
    ldr x0, =strInverseMatrixInput
    bl printString // Imprime Matriz a operar
    bl printEnter
    ldr w0, [fp, #-68] // Cargamos ID para impresión
    bl printMatrixByIdNoAsk // Imprime la matriz original usando ID, sin pedirlo nuevamente
    bl printEnter

    // Calculamos columnas de Aumentada = 2n y bytes = n * (2n) * 4.
    ldr w9, [fp, #-12] // Cargamos n (filas = columnas de A)
    lsl w10, w9, #1 // columnas de Aumentada = 2n
    str w10, [fp, #-36] // Guardamos columnas de Aumentada
    mul w11, w9, w10 // n * (2n)
    lsl w11, w11, #2 // bytes de Aumentada = n * (2n) * 4
    str w11, [fp, #-32] // Guardamos bytes de Aumentada
    uxtw x0, w11 // Convertimos a 64 bits para malloc
    bl matrixMalloc // Reservamos memoria para matriz aumentada, puntero en x0
    str x0, [fp, #-24]

    // Inicializamos Aumentada con [A | I].
    mov w9, #0
    str w9, [fp, #-44] // Guardamos i = 0 en el stack

inverseFillRowsLoop:
    ldr w9, [fp, #-44] // Cargamos i
    ldr w10, [fp, #-12] // Cargamos n
    cmp w9, w10
    bge inverseStartJordan // Si i >= n, terminamos de llenar Aumentada y comenzamos Gauss-Jordan

    mov w11, #0
    str w11, [fp, #-48] // Guardamos j = 0 en el stack

// Llenado Aumentada fila por fila: primero copiamos A[i][j] para j < n
inverseFillColsLoop:
    ldr w9, [fp, #-44] // Cargamos i
    ldr w11, [fp, #-48] // Cargamos j
    ldr w12, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    cmp w11, w12
    bge inverseNextFillRow // Si j >= 2n, avanzamos a la siguiente fila

    // Si j < n, copiamos A[i][j].
    ldr w10, [fp, #-12] // cargamos n 
    cmp w11, w10
    bge inverseFillIdentitySide // Si j >= n, llenamos el bloque derecho con la identidad

    // Offset en A: (i*n + j)*4
    mul w13, w9, w10 // Calculamos la posición base de la fila: i * n
    add w13, w13, w11 // Sumamos j para obtener el offset total en elementos: i * n + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-8] // Cargamos el puntero de A
    ldr w16, [x15, x14] // Cargamos A[i][j]

    // Offset en Aumentada: (i*(2n) + j)*4
    ldr w12, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    mul w13, w9, w12 // Calculamos la posición base de la fila: i * columnas de Aumentada
    add w13, w13, w11 // Sumamos j para obtener el offset total en elementos: i * columnas de Aumentada + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de Aumentada
    str w16, [x15, x14] // Almacenamos A[i][j] en Aumentada[i][j]
    b inverseAdvanceFillCol // Avanzamos a la siguiente columna

// Si j >= n, llenamos el bloque derecho de Aumentada con la identidad I[i][jr], donde jr = j - n.
inverseFillIdentitySide:
    // Para j >= n, construimos I en el bloque derecho.
    sub w13, w11, w10 // restamos n para obtener el índice de columna de la identidad: jr = j - n
    cmp w13, w9 // comparamos jr con i para determinar si estamos en la diagonal (jr == i)
    bne inverseStoreZeroIdentity // Si no estamos en la diagonal, almacenamos 0
    mov w16, #1
    b inverseStoreIdentityValue // Si estamos en la diagonal, almacenamos 1

inverseStoreZeroIdentity:
    mov w16, #0 // valor a almacenar para el bloque de identidad fuera de la diagonal

// Almacenamos el valor correspondiente (0 o 1) en la posición Aumentada[i][j].
inverseStoreIdentityValue:
    // Offset en Aumentada: (i*(2n) + j)*4
    ldr w12, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    mul w13, w9, w12 // Calculamos la posición base de la fila: i * columnas de Aumentada
    add w13, w13, w11 // Sumamos j para obtener el offset total en elementos: i * columnas de Aumentada + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de Aumentada
    str w16, [x15, x14] // Almacenamos el valor (0 o 1) en Aumentada[i][j]

// Avanzamos a la siguiente columna en Aumentada
inverseAdvanceFillCol: 
    add w11, w11, #1 // j++
    str w11, [fp, #-48] // Guardamos j actualizado en el stack
    b inverseFillColsLoop // Repetimos para la siguiente columna

// Avanzamos a la siguiente fila en Aumentada
inverseNextFillRow: 
    ldr w9, [fp, #-44] // Cargamos i
    add w9, w9, #1 // i++
    str w9, [fp, #-44] // Guardamos i actualizado en el stack
    b inverseFillRowsLoop // Repetimos para la siguiente fila

// Iniciamos Gauss-Jordan en Aumentada.
inverseStartJordan:
    mov w9, #0
    str w9, [fp, #-40] // Guardamos k = 0 en el stack

inverseKLoop:
    ldr w9, [fp, #-40] // Cargamos k
    ldr w10, [fp, #-12] // Cargamos n
    cmp w9, w10
    bge inverseBuildResult // Si k >= n, terminamos Gauss-Jordan y construimos la matriz inversa a partir del bloque derecho de Aumentada

    // Buscamos fila pivote r >= k con Aumentada[r][k] != 0.
    str w9, [fp, #-52] // Guardamos k en r para iniciar la búsqueda de pivote desde la fila k

// El loop de búsqueda de pivote se maneja en un bloque separado para permitir saltar directamente a la normalización si el pivote ya está en la fila k, evitando iteraciones innecesarias.
inverseFindPivotLoop:
    ldr w11, [fp, #-52] // Cargamos r
    ldr w10, [fp, #-12] // Cargamos n
    cmp w11, w10
    bge inverseSingularFail // Si r >= n, no se encontró pivote válido, la matriz es singular

    ldr w12, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    mul w13, w11, w12 // Calculamos la posición base de la fila r: r * columnas de Aumentada
    add w13, w13, w9 // Sumamos k para obtener el offset total en elementos: r * columnas de Aumentada + k
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de Aumentada
    ldr w16, [x15, x14] // Cargamos Aumentada[r][k]
    cbnz w16, inversePivotFound // Si Aumentada[r][k] != 0, encontramos un pivote válido y saltamos a normalizar la fila pivote

    add w11, w11, #1 // r++
    str w11, [fp, #-52] // Guardamos r actualizado en el stack
    b inverseFindPivotLoop // Repetimos para la siguiente fila

// Si r != k, intercambiamos filas completas en Aumentada.
inversePivotFound:
    ldr w11, [fp, #-52] // Cargamos r
    cmp w11, w9 //
    beq inverseLoadPivot // si r == k, la fila pivote ya está en su lugar, saltamos al proceso de normalización

    mov w12, #0
    str w12, [fp, #-48] // Guardamos j = 0 en el stack

//Intercambio de filas r y k en Aumentada, iterando sobre todas las columnas j desde 0 hasta 2n para asegurar que se intercambien tanto el bloque izquierdo A como el bloque derecho I simultáneamente.
inverseSwapColsLoop:
    ldr w12, [fp, #-48] // Cargamos j
    ldr w13, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    cmp w12, w13
    bge inverseLoadPivot // Si j >= 2n, terminamos de intercambiar filas y pasamos a cargar el pivote para normalización

    // offset k,j
    mul w14, w9, w13 // Calculamos la posición base de la fila k: k * columnas de Aumentada
    add w14, w14, w12 // Sumamos j para obtener el offset total en elementos: k * columnas de Aumentada + j
    lsl w14, w14, #2 // Multiplicamos por 4 para obtener el offset en bytes

    // offset r,j
    mul w15, w11, w13 // Calculamos la posición base de la fila r: r * columnas de Aumentada
    add w15, w15, w12 // Sumamos j para obtener el offset total en elementos: r * columnas de Aumentada + j
    lsl w15, w15, #2 // Multiplicamos por 4 para obtener el offset en bytes

    ldr x16, [fp, #-24] // Cargamos el puntero de Aumentada
    ldr w17, [x16, x14] // Cargamos Aumentada[k][j]
    ldr w18, [x16, x15] // Cargamos Aumentada[r][j]
    str w18, [x16, x14] // Almacenamos Aumentada[r][j] en Aumentada[k][j]
    str w17, [x16, x15] // Almacenamos Aumentada[k][j] en Aumentada[r][j]

    add w12, w12, #1 // j++
    str w12, [fp, #-48] // Guardamos j actualizado en el stack
    b inverseSwapColsLoop // Repetimos para la siguiente columna

// Cargamos el pivote después de asegurar que está en la fila k (ya sea porque r == k o porque se hizo el intercambio)
inverseLoadPivot:
    ldr w12, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    mul w13, w9, w12 // Calculamos la posición base de la fila k: k * columnas de Aumentada
    add w13, w13, w9 // Sumamos k para obtener el offset total en elementos: k * columnas de Aumentada + k (columna pivote)
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de Aumentada
    ldr w16, [x15, x14] // Cargamos el valor del pivote Aumentada[k][k]
    str w16, [fp, #-56] // Guardamos el valor del pivote para usarlo en la normalización y eliminación
    cbnz w16, inverseNormalizePivotRow // Si el pivote es distinto de cero, normalizamos la fila pivote

// Si el pivote es cero, la matriz es singular y no tiene inversa.
inverseSingularFail:
    mov w9, #0
    str w9, [fp, #-72]
    b inversePrintFail // Saltamos a imprimir mensaje de matriz sin inversa y retornamos

// Normalizamos fila pivote: Aumentada[k][j] /= pivot para j entre 0 y 2n, asegurando que el pivote quede exactamente 1
inverseNormalizePivotRow:
    mov w12, #0
    str w12, [fp, #-48] // Guardamos j = 0 en el stack

// Iteramos sobre cada columna j de la fila pivote k para dividir por el valor del pivote, normalizando así la fila pivote.
inverseNormalizeLoop:
    ldr w12, [fp, #-48] // Cargamos j
    ldr w13, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    cmp w12, w13
    bge inverseEliminateOtherRows // Si j >= 2n, terminamos de normalizar la fila pivote y pasamos a eliminar los valores en la columna pivote para las otras filas

    mul w14, w9, w13 // Calculamos la posición base de la fila k: k * columnas de Aumentada
    add w14, w14, w12 // Sumamos j para obtener el offset total en elementos: k * columnas de Aumentada + j
    lsl w14, w14, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de Aumentada
    ldrsw x16, [x15, x14] // Cargamos Aumentada[k][j] como valor de 32 bits con signo para la división

    ldrsw x17, [fp, #-56] // Cargamos el pivote como valor de 32 bits con signo para la división
    sdiv x16, x16, x17 // Dividimos Aumentada[k][j] por el pivote para normalizar la fila pivote
    str w16, [x15, x14] // Almacenamos el valor normalizado de vuelta en Aumentada[k][j]

    add w12, w12, #1 // j++
    str w12, [fp, #-48] // Guardamos j actualizado en el stack
    b inverseNormalizeLoop // Repetimos para la siguiente columna

inverseEliminateOtherRows: 
    // Eliminamos columna k para todas las filas i != k.
    mov w10, #0
    str w10, [fp, #-44] // Guardamos i = 0 en el stack

inverseILoop:
    ldr w10, [fp, #-44] // Cargamos i
    ldr w11, [fp, #-12] // Cargamos n
    cmp w10, w11
    bge inverseNextK // Si i >= n, terminamos de procesar la columna pivote k y avanzamos a la siguiente columna pivote

    cmp w10, w9 // Comparamos i con k para asegurarnos de no eliminar la fila pivote
    beq inverseNextI // Si i == k, saltamos la eliminación para esta fila y pasamos a la siguiente fila

    // factor = Aumentada[i][k]
    ldr w12, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    mul w13, w10, w12 // Calculamos la posición base de la fila i: i * columnas de Aumentada
    add w13, w13, w9 // Sumamos k para obtener el offset total en elementos: i * columnas de Aumentada + k (columna pivote)
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de Aumentada
    ldr w16, [x15, x14] // Cargamos Aumentada[i][k]
    str w16, [fp, #-60] // Guardamos el factor para usarlo en la eliminación
    cbz w16, inverseNextI // Si el factor es cero, saltamos a la siguiente fila

    mov w12, #0
    str w12, [fp, #-48] // Guardamos j = 0

inverseJLoop:
    ldr w12, [fp, #-48] // Cargamos j
    ldr w13, [fp, #-36] // Cargamos 2n
    cmp w12, w13
    bge inverseForceZeroAtPivot // Si j >= 2n, forzamos Aumentada[i][k] = 0 para estabilizar la forma reducida y pasamos a la siguiente fila

    // aij = Aumentada[i][j]
    mul w14, w10, w13 // Calculamos la posición base de la fila i: i * columnas de Aumentada
    add w14, w14, w12 // Sumamos j para obtener el offset total en elementos: i * columnas de Aumentada + j
    lsl w14, w14, #2  // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de Aumentada
    ldrsw x16, [x15, x14] // Cargamos Aumentada[i][j]

    // akj = Aumentada[k][j]
    mul w17, w9, w13 // Calculamos la posición base de la fila k: k * columnas de Aumentada
    add w17, w17, w12 // Sumamos j para obtener el offset total en elementos: k * columnas de Aumentada + j
    lsl w17, w17, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldrsw x18, [x15, x17] // Cargamos Aumentada[k][j]

    // Aumentada[i][j] = aij - factor*akj
    ldrsw x19, [fp, #-60] // Cargamos el factor
    mul x20, x19, x18 // Multiplicamos el factor por Aumentada[k][j]
    sub x21, x16, x20 // Restamos el producto de la multiplicación a Aumentada[i][j]
    str w21, [x15, x14] // Almacenamos el resultado en Aumentada[i][j]

    add w12, w12, #1 // j++
    str w12, [fp, #-48] // Guardamos j actualizado en el stack
    b inverseJLoop // Repetimos para la siguiente columna

// Forzamos Aumentada[i][k] = 0 para estabilizar la forma reducida.
inverseForceZeroAtPivot:
    ldr w13, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    mul w14, w10, w13 // Calculamos la posición base de la fila i: i * columnas de Aumentada
    add w14, w14, w9 // Sumamos k para obtener el offset total en elementos: i * columnas de Aumentada + k (columna pivote)
    lsl w14, w14, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de Aumentada
    str wzr, [x15, x14] // Forzamos Aumentada[i][k] = 0

inverseNextI:
    ldr w10, [fp, #-44] // Cargamos i
    add w10, w10, #1 // i++
    str w10, [fp, #-44] // Guardamos i actualizado en el stack
    b inverseILoop // Repetimos para la siguiente fila

inverseNextK:
    ldr w9, [fp, #-40] // Cargamos k
    add w9, w9, #1 // k++
    str w9, [fp, #-40] // Guardamos k actualizado en el stack
    b inverseKLoop // Repetimos para la siguiente columna pivote


// Construimos el resultado final copiando el bloque derecho de Aumentada (que ahora es la inversa) a matrixResultPointer, y luego liberamos la matriz aumentada temporal
inverseBuildResult:
    // Construimos resultado final (n x n) con el bloque derecho de Aumentada.
    bl freePreviousMatrixResult
    ldr w0, [fp, #-12] // Cargamos n para reservar la matriz resultado
    ldr w1, [fp, #-12] // Cargamos n para reservar la matriz resultado
    bl mallocResultMatrix // Reservamos la matriz resultado con las mismas dimensiones que A, puntero en x0

    // Cargamos metadata del resultado para copiar la inversa.
    ldr x9, =matrixResultPointer
    ldr x9, [x9]
    str x9, [fp, #-8] // Reutilizamos local de puntero como base resultado final

    mov w9, #0 // i = 0
    str w9, [fp, #-44] // Guardamos i en el stack para el loop de copia de filas

// Copiamos el bloque derecho de Aumentada a matrixResultPointer iterando sobre cada elemento del bloque derecho y almacenándolo en la posición correspondiente de la matriz resultado
inverseCopyRowsLoop:
    ldr w9, [fp, #-44] // Cargamos i
    ldr w10, [fp, #-12] // Cargamos n
    cmp w9, w10
    bge inversePrintSuccess // Si i >= n, terminamos de copiar la inversa y pasamos a imprimir el resultado

    mov w11, #0
    str w11, [fp, #-48] // Guardamos j = 0 en el stack para el loop de copia de columnas

inverseCopyColsLoop:
    ldr w11, [fp, #-48] // Cargamos j
    ldr w10, [fp, #-12] // Cargamos n
    cmp w11, w10
    bge inverseNextCopyRow // Si j >= n, terminamos de copiar la fila actual y pasamos a la siguiente fila

    // Leemos Aumentada[i][j+n].
    ldr w12, [fp, #-36] // Cargamos columnas de Aumentada (2n)
    add w13, w11, w10 // Calculamos j+n para acceder al bloque derecho de Aumentada
    mul w14, w9, w12 // Calculamos la posición base de la fila i: i * columnas de Aumentada
    add w14, w14, w13 // Sumamos j+n para obtener el offset total en elementos: i * columnas de Aumentada + (j+n)
    lsl w14, w14, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos el puntero de Aumentada
    ldr w16, [x15, x14] // Cargamos Aumentada[i][j+n], que es el elemento de la inversa que queremos copiar a la matriz resultado

    // Escribimos resultado[i][j].
    mul w14, w9, w10 // Calculamos la posición base de la fila i en la matriz resultado: i * n
    add w14, w14, w11 // Sumamos j para obtener el offset total en elementos: i * n + j
    lsl w14, w14, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-8] // Cargamos el puntero de la matriz resultado
    str w16, [x15, x14] // Almacenamos el valor de la inversa en resultado[i][j]

    add w11, w11, #1 // j++
    str w11, [fp, #-48] // Guardamos j actualizado en el stack
    b inverseCopyColsLoop // Repetimos para la siguiente columna

inverseNextCopyRow:
    ldr w9, [fp, #-44]
    add w9, w9, #1
    str w9, [fp, #-44] // Guardamos i actualizado en el stack
    b inverseCopyRowsLoop // Repetimos para la siguiente fila

// Si llegamos aquí, se calculó la inversa exitosamente y se copió a matrixResultPointer, procedemos a imprimir el resultado y liberar la matriz aumentada temporal.
inversePrintSuccess: //
    ldr x0, =strInverseResult
    bl printString // Imprime "Inversa:\n"
    bl printLastResult // Imprime la matriz resultado usando el puntero en matrixResultPointer, sin pedir entrada adicional
    bl printEnter
    mov w9, #1 // Marcamos éxito en el cálculo de la inversa
    str w9, [fp, #-76] // Guardamos estado de retorno indicando que se calculó la inversa exitosamente
    b inverseFreeAumentadaAndReturn // Saltamos a liberar la matriz aumentada temporal y retornar

// Si llegamos aquí, no se pudo calcular la inversa (matriz singular), procedemos a imprimir mensaje de error y retornar sin modificar matrixResultPointer.
inversePrintFail:
    ldr x0, =strInverseNoExists
    bl printString // Imprime "La matriz no tiene inversa (determinante 0 / pivote nulo).\n"
    mov w9, #0 // Marcamos estado de retorno indicando que no se calculó la inversa
    str w9, [fp, #-76] // Guardamos estado de retorno indicando que no se calculó la inversa

// Liberamos la matriz aumentada temporal si fue reservada
inverseFreeAumentadaAndReturn:
    ldr x9, [fp, #-24]
    cbz x9, inverseNoAskEnd // Si no se reservó Aumentada, saltamos a la limpieza final y retorno
    ldr w10, [fp, #-32] // Cargamos bytes reservados para Aumentada
    uxtw x1, w10 // Convertimos a 64 bits para matrixFree
    mov x0, x9 // Cargamos el puntero de Aumentada para liberar
    bl matrixFree // Liberamos la matriz aumentada temporal

inverseNoAskEnd:
    ldr w0, [fp, #-76] // Recuperamos estado final (evita que matrixFree lo sobrescriba)
    add sp, sp, #80
    ldp fp, lr, [sp], #0x10
    ret
