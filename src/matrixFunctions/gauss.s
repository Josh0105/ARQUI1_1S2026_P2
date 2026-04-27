.global setGaussMatrix

/* ---------------------------------------------------------
 * Seccion de datos
 * --------------------------------------------------------- */
.section .data
    .align 2
    strGaussSwapSign: .string "Signo de swaps: "

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text

/* -----------------------------------------------------
* setGaussMatrix:
* Aplica eliminación de Gauss sobre una copia C de la matriz A usando Bareiss
* para mantener operaciones enteras sin usar decimales.
*
* Flujo:
* 1) Copia A en C (matrix resultado)
* 2) Busca pivote C[k][k] y hace swap de filas si pivote es cero
* 3) Elimina valores debajo del pivote con Bareiss
* 4) Termina con C triangular superior y mantiene signo de swaps
*
* Entrada:
* Por teclado (ID de matriz)
*
* Retorno:
* x0 = puntero de la matriz resultado C
* x1 = signo de swaps (+1 o -1), útil para el determinante
* ----------------------------------------------------- */
setGaussMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #96 // locales: A, C, n, i, j, k, r, prevPivot, swapSign

/* -----------------------------------------------------
* Layout de locales (fp-):
* -8  = puntero A         // dirección base de la matriz original
* -12 = filas A       // filas de la matriz original
* -16 = cols A        // columnas de la matriz original
* -24 = puntero C         // dirección base de la copia/resultado
* -28 = filas C       // filas del resultado
* -32 = cols C        // columnas del resultado
* -36 = i             // fila actual que se está eliminando
* -40 = j             // columna actual dentro de la fila i
* -44 = k             // pivote actual (índice diagonal)
* -48 = r             // fila candidata para swap si el pivote es 0
* -56 = prevPivot     // pivote anterior requerido por Bareiss
* -60 = swapSign      // signo acumulado por intercambios de filas
----------------------------------------------------- */

gaussAskMatrixId:
    // Pedimos el ID de la matriz origen. Si el usuario ingresa algo inválido, repetimos.
    ldr x0, =strAskIdUniqueOperation
    bl printString // Imprime "Ingrese el ID de la matriz a operar (A-Z): "
    bl readMatrixIdFromConsole // Lee ID, retorna 0 si es inválido
    cmp x0, #0
    bne gaussContinueMatrixId
    bl generalStrCharInvalid
    b gaussAskMatrixId

gaussContinueMatrixId:
    // Buscamos la matriz original A y guardamos su puntero y dimensiones.
    bl getMatrixById // retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-8] // Guardamos puntero de A
    str w1, [fp, #-12] // Guardamos filas de A
    str w2, [fp, #-16] // Guardamos columnas de A

    cmp x0, #0
    bne gaussValidateSquare
    bl generalMatrixNotFound
    b gaussEnd

gaussValidateSquare:
    // Gauss/Bareiss se aplica aquí solo a matrices cuadradas.
    ldr w9, [fp, #-12] // filas
    ldr w10, [fp, #-16] // columnas
    cmp w9, w10
    beq gaussPrepareResult
    bl generalNotSquareMatrix // Bareiss para determinante/triangular: matriz cuadrada
    b gaussEnd

gaussPrepareResult:
    // Liberamos cualquier resultado previo y reservamos C con las mismas dimensiones que A.
    bl freePreviousMatrixResult
    ldr w0, [fp, #-12] // filas resultado
    ldr w1, [fp, #-16] // columnas resultado
    bl mallocResultMatrix

    // Cargamos metadata de C para usarla durante la copia y la eliminación.
    ldr x11, =matrixResultPointer
    ldr x11, [x11]
    str x11, [fp, #-24] // puntero C
    ldr x11, =matrixResultRows
    ldr w1, [x11]
    str w1, [fp, #-28] // filas C
    ldr x11, =matrixResultCols
    ldr w2, [x11]
    str w2, [fp, #-32] // cols C

    // prevPivot empieza en 1 para la primera iteración de Bareiss.
    // swapSign empieza en +1 y se invierte cada vez que intercambiamos filas.
    mov x9, #1
    str x9, [fp, #-56]
    mov w9, #1
    str w9, [fp, #-60]

    // Primera fase: copiar A en C sin modificar A.
    mov w9, #0
    str w9, [fp, #-36] // i = 0

gaussCopyRowsLoop:
    // Recorremos filas para copiar cada elemento de A hacia C.
    ldr w9, [fp, #-36] // i
    ldr w10, [fp, #-28] // filas
    cmp w9, w10
    bge gaussStartElimination

    mov w10, #0
    str w10, [fp, #-40] // j = 0

gaussCopyColsLoop:
    // Recorremos las columnas de la fila i actual.
    ldr w9, [fp, #-36] // i
    ldr w10, [fp, #-40] // j
    ldr w11, [fp, #-32] // cols
    cmp w10, w11
    bge gaussNextCopyRow // Si terminamos columnas, pasamos a la siguiente fila

    // Offset row-major en bytes: (i * cols + j) * 4.
    mul w13, w9, w11 // Calculamos la posición base de la fila: i * columnas
    add w13, w13, w10 // Sumamos la columna para obtener el offset total en elementos: i * columnas + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes

    ldr x15, [fp, #-8] // puntero A: base de la matriz original
    ldr w12, [x15, x14] // A[i][j]

    ldr x15, [fp, #-24] // puntero C: base de la matriz resultado
    str w12, [x15, x14] // C[i][j] = A[i][j]

    add w10, w10, #1 // j++
    str w10, [fp, #-40] // Guardamos j actualizado en el stack
    b gaussCopyColsLoop // Repetimos para la siguiente columna

gaussNextCopyRow:
    ldr w9, [fp, #-36] // Cargamos i
    add w9, w9, #1 // i++
    str w9, [fp, #-36] // Guardamos i actualizado en el stack
    b gaussCopyRowsLoop

gaussStartElimination:
    // Segunda fase: eliminación hacia abajo de la diagonal.
    mov w9, #0 // k = 0
    str w9, [fp, #-44] // Guardamos k en el stack

gaussKLoop:
    // k identifica el pivote actual C[k][k].
    ldr w9, [fp, #-44] // Cargamos k
    ldr w10, [fp, #-28] // Cargamos filas
    cmp w9, w10
    bge gaussPrintResult // Si k llegó al límite de filas, terminamos la eliminación

    // pivot = C[k][k]. Si es 0, buscaremos una fila debajo para swap.
    ldr w11, [fp, #-32] // Cargamos columnas
    mul w13, w9, w11 // Calculamos la posición base de la fila en C: k * columnas
    add w13, w13, w9 // Sumamos k para obtener el offset total en elementos: k * columnas + k
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // puntero C
    ldrsw x1, [x15, x14] // cargamos pivot actual en x1

    cbnz x1, gaussHavePivot // Si el pivote no es cero, seguimos con eliminación. Si es cero, buscamos swap.

    // Buscar una fila r > k con C[r][k] != 0 para usarla como pivote.
    add w10, w9, #1 //sumamos 1 a k para empezar a buscar en la siguiente fila
    str w10, [fp, #-48] // Guardamos r = k + 1 en el stack

// Si no encontramos pivote no-cero, simplemente avanzamos al siguiente k, tratando esta columna como singular.  
gaussFindPivotRowLoop:
    // Recorremos filas por debajo de k buscando un valor distinto de cero en la columna k.
    ldr w10, [fp, #-48] // Cargamos r
    ldr w12, [fp, #-28] // Cargamos filas
    cmp w10, w12
    bge gaussNoPivotFound // Si r llegó al límite de filas, no hay pivote no-cero en esta columna, tratamos como singular y avanzamos a siguiente k

    ldr w11, [fp, #-32] // Cargamos columnas de C    
    mul w13, w10, w11 // Calculamos la posición base de la fila candidata: r * columnas
    add w13, w13, w9 // Sumamos k para obtener el offset total en elementos: r * columnas + k
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24]
    ldrsw x2, [x15, x14] // Cargamos el valor de C[r][k] para verificar si es un pivote no-cero
    cbnz x2, gaussSwapRows // Si encontramos un pivote no-cero, vamos a swap de filas. Si es cero, seguimos buscando.

    add w10, w10, #1 // r++
    str w10, [fp, #-48]// cargado r actualizado en el stack
    b gaussFindPivotRowLoop

gaussSwapRows:
    // Intercambiamos fila k con fila r en C. Cada swap cambia el signo del determinante.
    mov w10, #0
    str w10, [fp, #-40] // j = 0

gaussSwapColsLoop:
    // Intercambio columna por columna entre las dos filas.
    ldr w10, [fp, #-40] // Cargamos j
    ldr w11, [fp, #-32] // Cargamos columnas
    cmp w10, w11
    bge gaussSwapSignUpdate // Si terminamos de intercambiar todas las columnas, actualizamos el signo y seguimos con eliminación

    // offset1 = (k * cols + j) * 4
    ldr w9, [fp, #-44] // Cargamos k
    mul w13, w9, w11 // Calculamos la posición base de la fila k: k * columnas
    add w13, w13, w10 // Sumamos j para obtener el offset total en elementos: k * columnas + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes

    // offset2 = (r * cols + j) * 4
    ldr w12, [fp, #-48] // r
    mul w13, w12, w11 // Calculamos la posición base de la fila r: r * columnas
    add w13, w13, w10 // Sumamos j para obtener el offset total en elementos: r * columnas + j
    lsl w15, w13, #2// Multiplicamos por 4 para obtener el offset en bytes

    ldr x0, [fp, #-24] // puntero C
    ldr w1, [x0, x14] // Cargamos el valor de C[k][j] en w1
    ldr w2, [x0, x15] /// Cargamos el valor de C[r][j] en w2
    str w2, [x0, x14] // Intercambiamos los valores: C[k][j] = C[r][j]
    str w1, [x0, x15] // C[r][j] = valor original de C[k][j]

    add w10, w10, #1 // j++
    str w10, [fp, #-40] // Guardamos j actualizado en el stack
    b gaussSwapColsLoop //Repetimos para la siguiente columna

gaussSwapSignUpdate:
    // Invertimos el signo acumulado porque un swap cambia el signo del determinante.
    ldr w10, [fp, #-60] // cArgamos swapSign actual
    neg w10, w10 // swapSign = -swapSign
    str w10, [fp, #-60] // Guardamos el nuevo swapSign actualizado en el stack

    // Recargamos el pivote después del swap para continuar eliminando.
    ldr w9, [fp, #-44] //  Cargamos k
    ldr w11, [fp, #-32] // cargamos columnas de C
    mul w13, w9, w11 // Calculamos la posición base de la fila pivote: k * columnas
    add w13, w13, w9 // Sumamos k para obtener el offset total en elementos: k * columnas + k
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // puntero C
    ldrsw x1, [x15, x14]// Cargamos el nuevo pivote en x1 después del swap

    cbnz x1, gaussHavePivot // Si el nuevo pivote no es cero, seguimos con eliminación. Si es cero, aunque raro, tratamos esta columna como singular y avanzamos a siguiente k.

    // Si sigue en cero, tratar como columna singular
    b gaussNoPivotFound

gaussNoPivotFound:
    // Si no encontramos pivote no-cero para esta columna, avanzamos al siguiente k.
    ldr w9, [fp, #-44] // Cargamos k
    add w9, w9, #1 // k++
    str w9, [fp, #-44] // Guardamos k actualizado en el stack
    b gaussKLoop

gaussHavePivot:
    // Con pivote disponible, eliminamos todos los elementos debajo de la diagonal.
    ldr w9, [fp, #-44] // Cargamos k
    add w10, w9, #1 // i empieza en k + 1 para eliminar filas por debajo del pivote
    str w10, [fp, #-36] // Guardamos i actualizado en el stack

gaussILoop:
    // i recorre las filas debajo del pivote actual.
    ldr w10, [fp, #-36] // Cargamos i
    ldr w11, [fp, #-28] // Cargmos filas
    cmp w10, w11 
    bge gaussUpdatePrevPivot // Si i llegó al límite de filas, actualizamos prevPivot y pasamos al siguiente pivote

    // aik = C[i][k], el valor que queremos anular.
    ldr w9, [fp, #-44] // cargamos k
    ldr w11, [fp, #-32] // cargamos columnas
    mul w13, w10, w11 // Calculamos la posición base de la fila i: i * columnas
    add w13, w13, w9 // SUMAMOS k para obtener el offset total en elementos: i * columnas + k
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] //Cargamos puntero C
    ldrsw x4, [x15, x14] // aik

    // j = k+1 porque la columna del pivote se elimina explícitamente.
    add w12, w9, #1 // j empieza en k + 1 para eliminar columnas a la derecha del pivote
    str w12, [fp, #-40] // Guardamos j actualizado en el stack

gaussJLoop:
    // j recorre las columnas a la derecha del pivote.
    ldr w12, [fp, #-40] // Cargamos j
    ldr w11, [fp, #-28] // Cargamos filas (que es igual a columnas en matriz cuadrada)
    cmp w12, w11
    bge gaussZeroBelowPivot // Si j llegó al límite de columnas, forzamos el valor debajo del pivote a cero y pasamos a la siguiente fila i

    // aij = C[i][j], valor actual de la fila i.
    ldr w10, [fp, #-36] // Cargamos i
    ldr w11, [fp, #-32] // Cargamos columnas
    mul w13, w10, w11 // Calculamos la posición base de la fila i: i * columnas
    add w13, w13, w12 // SUMAMOS j para obtener el offset total en elementos: i * columnas + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos puntero C
    ldrsw x7, [x15, x14] // cargamos aij, el valor actual en C[i][j] que queremos actualizar con la eliminación

    // akj = C[k][j], valor correspondiente en la fila pivote.
    ldr w9, [fp, #-44] // cargamos k
    ldr w11, [fp, #-32] // Cargamos columnas
    mul w13, w9, w11 // Calculamos la posición base de la fila pivote: k * columnas
    add w13, w13, w12 // Sumamos j para obtener el offset total en elementos: k * columnas + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos puntero C
    ldrsw x9, [x15, x14] // Cargamos akj, el valor en la fila pivote que se usa para eliminar aij

    // Bareiss evita decimales:
    // nuevo = (pivot * aij - aik * akj) / prevPivot
    mul x10, x1, x7 // pivot * aij
    mul x11, x4, x9 // aik * akj
    sub x10, x10, x11 // pivot * aij - aik * akj

    // Si prevPivot == 1, la división no cambia el valor.
    ldr x28, [fp, #-56] // pivote anterior
    cmp x28, #1
    beq gaussStoreBareissValue // Si prevPivot es 1, no necesitamos dividir, vamos directo a almacenar el nuevo valor calculado.
    sdiv x10, x10, x28 // división entera truncada hacia cero

gaussStoreBareissValue:
    // Guardamos el nuevo valor calculado en C[i][j].
    ldr w9, [fp, #-36] // Cargamos i
    ldr w12, [fp, #-40] // Cargamos j
    ldr w11, [fp, #-32] // Cargamos columnas
    mul w13, w9, w11 // Calculamos la posición base de la fila i: i * columnas
    add w13, w13, w12 // Sumamos j para obtener el offset total en elementos: i * columnas + j
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // Cargamos puntero C
    // x10 contiene el nuevo valor entero; lo almacenamos en C[i][j].
    str w10, [x15, x14]

    // j++ para seguir con la misma fila.
    ldr w12, [fp, #-40] // Cargamos j
    add w12, w12, #1 // j++
    str w12, [fp, #-40]
    b gaussJLoop

gaussZeroBelowPivot:
    // Ya terminamos la fila i; forzamos C[i][k] = 0 para mantener la triangular superior.
    ldr w10, [fp, #-36] // cargamos i
    ldr w9, [fp, #-44] // cargamos k
    ldr w11, [fp, #-32] // cargamos columnas
    mul w13, w10, w11 // multiplicamos i por columnas para obtener la posición base de la fila i
    add w13, w13, w9 // sumamos k para obtener el offset total en elementos: i * columnas + k
    lsl w14, w13, #2 // multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-24] // cargamos puntero C
    str wzr, [x15, x14] //

    // Pasamos a la siguiente fila debajo del pivote.
    ldr w10, [fp, #-36] // Cargamos i
    add w10, w10, #1 // i++
    str w10, [fp, #-36]
    b gaussILoop

gaussUpdatePrevPivot:
    // Actualizamos prevPivot con el pivote que acabamos de usar.
    str x1, [fp, #-56] // prevPivot = pivot actual para la próxima iteración de Bareiss

    // Avanzamos al siguiente pivote diagonal.
    ldr w9, [fp, #-44] // Cargamos k
    add w9, w9, #1 //Sumamos 1 para avanzar al siguiente pivote diagonal
    str w9, [fp, #-44] // Guardamos k actualizado en el stack
    b gaussKLoop

gaussPrintResult:
    // Al terminar, imprimimos C ya triangular superior y el signo acumulado de swaps.
    bl printLastResult
    ldr x0, =strGaussSwapSign
    bl printString
    ldr w0, [fp, #-60] // swapSign
    sxtw x0, w0
    bl printInteger
    bl printEnter

    // Retorno: C en x0 y signo de swaps en x1.
    ldr x0, [fp, #-24] // puntero C
    ldr w1, [fp, #-60] // signo
    sxtw x1, w1 // retorno con signo extendido en x1
    b gaussEnd

gaussEnd:
    add sp, sp, #96
    ldp fp, lr, [sp], #0x10
    ret
