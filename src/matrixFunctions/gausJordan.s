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
    ldr w10, [x9] // Cargamos filas de la matriz resultado
    str w10, [fp, #-48] // Guardamos filas de la matriz resultado en el stack
    ldr x9, =matrixResultCols
    ldr w10, [x9] // Cargamos columnas de la matriz resultado
    str w10, [fp, #-52] // Guardamos columnas de la matriz resultado en el stack

    mov w9, #0 // k = 0, iniciamos con el primer pivote diagonal
    str w9, [fp, #-56] // Guardamos k en el stack

gaussJordanKLoop:
    // Recorremos pivotes en la diagonal principal.
    ldr w9, [fp, #-56] // Cargamos k (pivote actual)
    ldr w10, [fp, #-48] // filas
    cmp w9, w10
    bge gaussJordanPrintResult // Si terminamos pivotes, ya tenemos forma reducida

    // Leemos pivot = C[k][k]. Si es 0, esta columna no se puede normalizar.
    ldr w11, [fp, #-52] // Cargamos columnas para calcular offset
    mul w13, w9, w11 // Calculamos offset multiplicando fila por cantidad de columnas
    add w13, w13, w9 // Sumamos k para llegar a la diagonal
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener offset en bytes
    ldr x15, [fp, #-8] // Cargamos puntero base de la matriz resultado
    ldrsw x16, [x15, x14] // Cargamos el valor del pivote actual (C[k][k]) para evaluar si es cero o no
    str x16, [fp, #-16] // Guardamos el pivote actual en el stack para usarlo en normalización y eliminación de filas

    cbnz x16, gaussJordanPivotValid // Si pivote es no-cero, continuamos con normalización

    // Si pivote es 0, marcamos fracaso para identidad y avanzamos.
    mov w9, #0 // Marcamos que no se pudo alcanzar identidad por pivotes
    str w9, [fp, #-72] // Guardamos el flag de fracaso en el stack
    b gaussJordanNextK // Avanzamos al siguiente pivote sin intentar normalizar ni eliminar filas

gaussJordanPivotValid:
    // Contamos este pivote no-cero como válido para criterio de identidad por pivotes.
    ldr w9, [fp, #-76] // Cargamos contador de pivotes válidos
    add w9, w9, #1 // Incrementamos contador de pivotes válidos
    str w9, [fp, #-76] // Guardamos el nuevo contador de pivotes válidos en el stack

    // Normalizamos la fila pivote dividiendo cada elemento entre pivot.
    mov w12, #0
    str w12, [fp, #-64] // Guardamos j=0 para iterar por columnas de la fila pivote

gaussJordanNormalizeRowLoop:
    ldr w12, [fp, #-64] // Cargamos j
    ldr w11, [fp, #-52] // Cargamos columnas
    cmp w12, w11
    bge gaussJordanEliminateRows // Si terminamos columnas, pasamos a eliminar filas

    ldr w9, [fp, #-56] // Cargamos k para calcular offset
    mul w13, w9, w11 // Calculamos offset base de la fila pivote multiplicando por cantidad de columnas
    add w13, w13, w12  // Sumamos j para obtener offset total del elemento actual en la fila pivote
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener offset en bytes
    ldr x15, [fp, #-8] // Cargamos puntero base de la matriz resultado
    ldrsw x10, [x15, x14] // C[k][j] para normalizarlo dividiendo por el pivote

    ldr x11, [fp, #-16] // Cargamos pivot para dividir
    sdiv x10, x10, x11 // Normalizamos: C[k][j] = C[k][j] / pivot
    str w10, [x15, x14] // Guardamos el valor normalizado en el stack temporalmente

    add w12, w12, #1 // j++
    str w12, [fp, #-64] // Guardamos j actualizado
    b gaussJordanNormalizeRowLoop // Repetimos para la siguiente columna de la fila pivote

gaussJordanEliminateRows:
    // Eliminamos la columna pivote en todas las filas i != k.
    mov w10, #0 // i = 0
    str w10, [fp, #-60] // Guardamos i en el stack

gaussJordanILoop:
    ldr w10, [fp, #-60] // Cargamos i
    ldr w11, [fp, #-48] // Cargamos filas para comparar con i
    cmp w10, w11 
    bge gaussJordanNextK // Si terminamos filas, pasamos al siguiente pivote

    ldr w9, [fp, #-56] // Cargamos k
    cmp w10, w9
    beq gaussJordanNextI // Si i == k, esta es la fila pivote que ya normalizamos, la saltamos para eliminar solo en filas distintas

    // factor = C[i][k]
    ldr w11, [fp, #-52] // Cargamos columnas para calcular offset
    mul w13, w10, w11 // Calculamos offset multiplicando fila i por cantidad de columnas
    add w13, w13, w9 // Sumamos k para llegar a la columna pivote
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener offset en bytes
    ldr x15, [fp, #-8] // Cargamos puntero base de la matriz resultado
    ldrsw x17, [x15, x14] // C[i][k] para usarlo como factor de eliminación
    str x17, [fp, #-24]

    cbz x17, gaussJordanNextI // Si factor es 0, la fila ya está eliminada en esta columna

    mov w12, #0
    str w12, [fp, #-64] // Guardamos j=0 para iterar por columnas de la fila actual i

gaussJordanJLoop:
    ldr w12, [fp, #-64] // cargamos j  
    ldr w11, [fp, #-52] // cargamos columnas

    cmp w12, w11
    bge gaussJordanForceZeroAtPivotColumn // Si terminamos columnas, forzamos explícitamente C[i][k] = 0 para mantener la forma reducida estable y pasamos a siguiente fila

    // aij = C[i][j]
    ldr w10, [fp, #-60] // Cargamos i para calcular offset
    mul w13, w10, w11 // Calculamos offset base de la fila actual multiplicando por cantidad de columnas
    add w13, w13, w12 // Sumamos j para obtener offset total del elemento actual
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener offset en bytes
    ldr x15, [fp, #-8] // Cargamos puntero base de la matriz resultado
    ldrsw x18, [x15, x14] // C[i][j] para usarlo en la fórmula de eliminación
    str x18, [fp, #-32] // Guardamos aij en el stack temporalmente

    // akj = C[k][j]
    ldr w9, [fp, #-56] // cargamos k para calcular offset
    mul w13, w9, w11 // Calculamos offset base de la fila pivote multiplicando por cantidad de columnas
    add w13, w13, w12 // Sumamos j para obtener offset total del elemento actual en la fila pivote
    lsl w19, w13, #2 // Multiplicamos por 4 para obtener offset en bytes
    ldrsw x20, [x15, x19] // C[k][j] para usarlo en la fórmula de eliminación
    str x20, [fp, #-40]  // Guardamos akj en el stack temporalmente

    // C[i][j] = aij - factor * akj
    ldr x21, [fp, #-24] // cargamos factor de eliminación
    mul x22, x21, x20 // factor * akj
    sub x23, x18, x22 // restamos aij - factor * akj para obtener el nuevo valor de C[i][j]
    str w23, [x15, x14] // Guardamos el nuevo valor de C[i][j] después de la eliminación

    add w12, w12, #1 // j++
    str w12, [fp, #-64] // Guardamos j actualizado
    b gaussJordanJLoop // Repetimos para la siguiente columna de la fila actual i

gaussJordanForceZeroAtPivotColumn:
    // Forzamos explícitamente C[i][k] = 0 para mantener la forma reducida estable.
    ldr w10, [fp, #-60] // cargamos i
    ldr w9, [fp, #-56] // cargamos k
    ldr w11, [fp, #-52] // cargamos columnas
    mul w13, w10, w11 // Calculamos offset multiplicando fila i por cantidad de columnas
    add w13, w13, w9 // Sumamos k para llegar a la columna pivote
    lsl w14, w13, #2 // Multiplicamos por 4 para obtener offset en bytes
    ldr x15, [fp, #-8] // Cargamos puntero base de la matriz resultado
    str wzr, [x15, x14] // Forzamos C[i][k] = 0

gaussJordanNextI:
    ldr w10, [fp, #-60] // Cargamos i
    add w10, w10, #1 // i++
    str w10, [fp, #-60] // Guardamos i actualizado
    b gaussJordanILoop

gaussJordanNextK:
    // Avanzamos al siguiente pivote diagonal.
    ldr w9, [fp, #-56] // Cargamos k
    add w9, w9, #1 // k++
    str w9, [fp, #-56] // Guardamos k actualizado
    b gaussJordanKLoop

gaussJordanPrintResult:
    ldr x0, =strGaussJordanResult
    bl printString
    bl printLastResult // Imprime la matriz resultado de Gauss-Jordan (forma reducida por filas)
    bl printEnter

    // Sin recorrer toda la matriz: declaramos identidad si fue cuadrada y todos los pivotes fueron válidos.
    ldr w9, [fp, #-48] // cargamos filas
    ldr w10, [fp, #-52] // cargamos columnas
    cmp w9, w10
    bne gaussJordanPrintFail

    ldr w11, [fp, #-72] // cargamos successFlag para identidad por pivotes
    cmp w11, #1 // Verificamos que no se haya marcado fracaso por pivote cero
    bne gaussJordanPrintFail // si 0, no se alcanzó identidad por pivotes, aunque la matriz sea cuadrada

    ldr w12, [fp, #-76] // cargamos pivotCount 
    cmp w12, w9 
    bne gaussJordanPrintFail // Verificamos que la cantidad de pivotes válidos sea igual a la cantidad de filas (y columnas) para asegurar que cada fila tuvo un pivote no cero

    ldr x0, =strGaussJordanIdentityOk
    bl printString // Imprime mensaje de éxito para identidad por pivotes
    b gaussJordanEnd

gaussJordanPrintFail:
    ldr x0, =strGaussJordanIdentityFail
    bl printString // Imprime mensaje de fracaso para identidad por pivotes

gaussJordanEnd:
    add sp, sp, #80
    ldp fp, lr, [sp], #0x10
    ret
