.global newMatrix
.global getMatrixById
.global printMatrixById
.global printLastResult
.global freeMatrixById

/* ---------------------------------------------------------
 * Seccion bss para estado global de matrices
 * --------------------------------------------------------- */
.section .bss
    .align 3
    // Aceptaremos 26 matrices (A..Z)
    matrixPointers: .skip 208      // Apuntadores de cada matriz 26 * 8 bytes
    matrixRows: .skip 104          // Cantidad de filas para cada matriz 26 * 4 bytes
    matrixCols: .skip 104          // Cantidad de columnas para cada matriz 26 * 4 bytes
    matrixIds: .skip 26            // ids ASCII: A..Z
    matrixCount: .skip 4           // Contador de matrices creadas (0..26)
    matrixResultPointer: .skip 8 // Puntero para almacenar resultados de operaciones entre matrices
    matrixResultRows: .skip 4 // Filas de la matriz resultado
    matrixResultCols: .skip 4 // Columnas de la matriz resultado

/* ---------------------------------------------------------
 * Seccion de datos
 * --------------------------------------------------------- */
.section .data
    .align 2
    strRows: .string "Numero de filas: "
    strCols: .string "Numero de columnas: "
    strVal1: .string "Ingrese el valor["
    strVal2: .string "]["
    strVal3: .string "]: "
    strSaved: .string "Matriz guardada con identificador: "
    strIntInvalid: .string "Entrada invalida. Ingrese un entero positivo.\n"
    strCharInvalid: .string "Entrada invalida. Ingrese una letra (A-Z).\n"
    strNoSlot: .string "No hay mas identificadores disponibles (A-Z).\n"
    strAskIdPrint: .string "Ingrese el ID de la matriz a imprimir (A-Z): "
    strAskIdFree: .string "Ingrese el ID de la matriz a liberar (A-Z): "
    strMatrixNotFound: .string "No existe una matriz con ese ID.\n"
    strMatrixResultNotFound: .string "No hay una matriz resultado para mostrar.\n"
    strMatrixFreed: .string "Matriz liberada correctamente.\n"
    strMatrixAlreadyFreed: .string "La matriz ya estaba liberada.\n"
    strAskIdUniqueOperation: .string "Ingrese el ID de la matriz a operar (A-Z): "
    strSpace: .string " "

    .align 2
    matrixIdBuffer: .byte 0, 0 // Buffer para imprimir el ID de la matriz seguido de un null terminator

/* ---------------------------------------------------------
 * Seccion de codigo
 * --------------------------------------------------------- */
.section .text
/* -----------------------------------------------------
* newMatrix:
* Crea una matriz de enteros de 32 bits en memoria dinamica,
* guarda su puntero/dimensiones y asigna ID secuencial A..Z.
*
* Registros importantes:
* x0 = parametro/retorno de funciones auxiliares
* x14/w15 = acceso y actualizacion de matrixCount
* x16/x17 = calculo de direccion de slot por indice
* w9 = indice i (fila actual)
* w11 = indice j (columna actual)
* x15 = puntero base de la matriz en memoria dinamica
* ----------------------------------------------------- */
newMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #64 // Espacio para variables locales: filas, columnas, puntero matriz, indice matriz, i, j

    // Verifica si aun hay slots disponibles (A..Z)
    ldr x9, =matrixCount // Carga la direccion de matrixCount
    ldr w10, [x9] // Carga el valor de matrixCount
    cmp w10, #26
    bge noMatrixSlot // Si ya hay 26 matrices, no hay slots disponibles

askRows:
    // Solicita filas hasta recibir entero positivo
    ldr x0, =strRows
    bl printString
    bl readIntFromConsole 
    cmp x0, #1 
    bge saveRows // si el resultado es 1 o más, guardamos filas
    ldr x0, =strIntInvalid // de lo contrario, mensaje de error
    bl printString
    b askRows

saveRows:
    str w0, [fp, #-4] // Guardamos filas en el stack

askCols:
    // Solicita columnas hasta recibir entero positivo
    ldr x0, =strCols
    bl printString
    bl readIntFromConsole
    cmp x0, #1
    bge saveCols // si el resultado es 1 o más, guardamos columnas
    ldr x0, =strIntInvalid // de lo contrario, mensaje de error
    bl printString
    b askCols

saveCols:
    str w0, [fp, #-8] // Guardamos columnas en el stack

/* -----------------------------------------------------
* Proceso de creación de matriz:
* 1) Calcula bytes a reservar: filas * columnas * 4 (int32)
* 2) Reserva memoria con matrixMalloc (syscall mmap) y calcula el indice para la nueva matriz
* 3) Guarda puntero y dimensiones en arrays globales por indice
* 4) Asigna ID secuencial (A + indice)
* 5) Bucle doble para llenar matriz con valores ingresados por usuario
* ----------------------------------------------------- */
// 1) Calcula bytes a reservar: filas * columnas * 4 (int32)
    ldr w11, [fp, #-4] // carga filas del stack
    ldr w12, [fp, #-8] // carga columnas del stack
    mul w13, w11, w12 // calcula filas * columnas
    lsl w13, w13, #2 // multiplicamos por 4 para obtener bytes a reservar
    uxtw x0, w13 // Convierte a 64 bits para enviar a matrixMalloc en x0

// 2) Reserva memoria con matrixMalloc (syscall mmap) y calcula el indice para la nueva matriz
    bl matrixMalloc // reservamos memoria y obtenemos puntero base en x0
    str x0, [fp, #-16] // Guardamos el puntero resultante en el stack

    ldr x14, =matrixCount // Carga la direccion de matrixCount
    ldr w15, [x14] // Carga el valor actual de matrixCount (indice para la nueva matriz)
    str w15, [fp, #-20] // Guardamos el indice en el stack

// 3) Guarda puntero y dimensiones en arrays globales por indice

    // Proceso para guardar puntero en matrixPointers[indice]
    ldr x16, =matrixPointers // Carga la direccion de matrixPointers
    uxtw x17, w15 // Convierte a 64 bits
    lsl x17, x17, #3 // Multiplica por 8 para obtener el offset correcto (punteros de 64 bits)
    add x16, x16, x17 // Calcula la direccion de matrixPointers[indice]
    ldr x0, [fp, #-16] // Carga el puntero de la matriz desde el stack
    str x0, [x16] // Guarda el puntero en matrixPointers[indice]

    // Proceso para guardar cantidad de filas en matrixRows[indice]
    ldr x16, =matrixRows // Carga la direccion de matrixRows
    uxtw x17, w15 // Convierte a 64 bits
    lsl x17, x17, #2 // Multiplica por 4 para obtener el offset correcto (enteros de 32 bits)
    add x16, x16, x17 // Calcula la direccion de matrixRows[indice]
    ldr w0, [fp, #-4] // Carga filas del stack
    str w0, [x16] // Guarda filas en matrixRows[indice]

    // Proceso para guardar cantidad de columnas en matrixCols[indice]
    ldr x16, =matrixCols // Carga la direccion de matrixCols
    uxtw x17, w15 // Convierte a 64 bits
    lsl x17, x17, #2 // Multiplica por 4 para obtener el offset correcto (enteros de 32 bits)
    add x16, x16, x17 // Calcula la direccion de matrixCols[indice]
    ldr w0, [fp, #-8] // Carga columnas del stack
    str w0, [x16]  // Guarda columnas en matrixCols[indice]

// 4) Asigna ID secuencial (A + indice)
    ldr x16, =matrixIds // Carga la direccion de matrixIds
    uxtw x17, w15 // Convierte a 64
    add x16, x16, x17 // Calcula la direccion de matrixIds[indice]
    mov w0, #'A' // Valor ASCII de 'A'
    add w0, w0, w15 // Suma el indice para obtener el ID correcto (A + indice)
    strb w0, [x16] // Guarda el ID en matrixIds[indice]

    add w15, w15, #1 // Incrementa matrixCount para la próxima matriz
    str w15, [x14] // Guarda el nuevo valor de matrixCount en el stack

//5) Bucle doble para llenar matriz con valores ingresados por usuario
    mov w9, #0
    str w9, [fp, #-24]   // i
loopRows:
    ldr w9, [fp, #-24] // Carga i
    ldr w10, [fp, #-4] // total de filas
    cmp w9, w10
    bge endInputValues // si terminamos las filas, salimos del bucle

    mov w11, #0 // resetea j para cada nueva fila
    str w11, [fp, #-28]  //guarda j
loopCols:
    ldr w11, [fp, #-28] // Carga j
    ldr w9, [fp, #-24] // Carga i
    ldr w12, [fp, #-8] // total de columnas
    cmp w11, w12 
    bge nextRow // si terminamos las columnas, vamos a la siguiente fila, si no, seguimos pidiendo valores para la fila actual

    // Imprime: Ingrese el valor[i][j]:
    ldr x0, =strVal1
    bl printString  // imprime "Ingrese el valor["
    ldr w9, [fp, #-24] // Carga i
    uxtw x0, w9 // Convierte a 64 bits para printInteger
    bl printInteger // imprime el valor de i
    ldr x0, =strVal2 
    bl printString // imprime "]["
    ldr w11, [fp, #-28] // Carga j
    uxtw x0, w11 // Convierte a 64 bits para printInteger
    bl printInteger // imprime el valor de j
    ldr x0, =strVal3
    bl printString // imprime "]: "

// Solicita valor para la posición actual de la matriz, acepta solo enteros positivos
askValue:
    bl readIntFromConsole // Lee valor desde consola
    cmp x0, #0
    bge storeValue // Si el valor es 0 o positivo, lo almacenamos en la matriz
    ldr x0, =strIntInvalid
    bl printString // Si el valor es negativo, mostramos mensaje de error y volvemos a pedir el valor
    b askValue

// Proceso para almacenar el valor ingresado en la posición correcta de la matriz
storeValue:
    // offset = (i * columnas + j) * 4  #ROW MAJOR
    ldr w9, [fp, #-24] // Carga i
    ldr w11, [fp, #-28] // Carga j
    ldr w13, [fp, #-8] // Carga total de columnas
    mul w14, w9, w13 // calculamos la posición base de la fila: i * columnas
    add w14, w14, w11 // sumamos la columna para obtener el offset total en elementos: i * columnas + j
    lsl w14, w14, #2 // multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-16] // Carga el puntero base de la matriz
    str w0, [x15, x14] // Almacena el valor ingresado entre x15 (puntero base) y el offset calculado

    add w11, w11, #1 // j++
    str w11, [fp, #-28] // Guarda j actualizado en el stack
    b loopCols // Itera a la siguiente columna

nextRow:
    ldr w9, [fp, #-24] // Carga i
    add w9, w9, #1 // i++
    str w9, [fp, #-24] // Guarda i actualizado
    b loopRows // Itera a la siguiente fila

// Muestra ID asignado al finalizar
endInputValues:
    ldr x0, =strSaved
    bl printString // imprime "Matriz guardada con identificador: "

    ldr w1, [fp, #-20] // Carga el indice de la matriz creada
    mov w0, #'A' // Valor ASCII de 'A'
    add w0, w0, w1 // Suma el indice para obtener el ID correcto (A + indice)
    ldr x2, =matrixIdBuffer // Carga la direccion del buffer para imprimir el ID
    strb w0, [x2] // Guarda el ID en el buffer
    mov w3, #0 // Null terminator para el buffer
    strb w3, [x2, #1] // Agrega null terminator en el byte después del ID
    mov x0, x2 // Prepara x0 con la direccion del buffer para imprimir el ID
    bl printString // imprime el ID de la matriz creada
    bl printEnter 
    b endIngresarMatriz

noMatrixSlot:
    // Sin slots disponibles (se alcanzo Z)
    ldr x0, =strNoSlot 
    bl printString // imprime mensaje de error

endIngresarMatriz:
    add sp, sp, #64
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* printMatrixById:
* Solicita un ID y muestra la matriz asociada en consola.
* ----------------------------------------------------- */
printMatrixById:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #48 // Espacio para variables locales: puntero matriz, filas, columnas, i, j

askPrintId:
    ldr x0, =strAskIdPrint
    bl printString // Imprime "Ingrese el ID de la matriz a imprimir (A-Z): "
    bl readMatrixIdFromConsole // Lee el ID ingresado y lo valida, retorna 0 si es inválido
    cmp x0, #0
    bne continuePrintById // Si el ID es válido (no 0), continuamos con la impresión de la matriz
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje de error y volvemos a pedir el ID
    b askPrintId

continuePrintById:
    bl getMatrixById // Busca la matriz por ID, retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-8] // Guardamos el puntero de la matriz en el stack
    str w1, [fp, #-12] // Guardamos filas en el stack
    str w2, [fp, #-16] // Guardamos columnas en el stack

    cmp x0, #0
    beq matrixNotFoundPrint // Si no se encontró la matriz (puntero 0), mostramos mensaje de error

    mov w11, #0 // creamos variable i para iterar filas
    str w11, [fp, #-20] // Guardamos i en el stack

/* -----------------------------------------------------
* Recorrido de la matriz usando i para filas y j para columnas, 
* calculando el offset para acceder a cada elemento y luego imprimiendo su valor 
* seguido de un espacio. Al finalizar cada fila, se imprime un salto de línea.
-----------------------------------------------------*/
printRowsLoop:
    ldr w11, [fp, #-20] // Carga i
    ldr w9, [fp, #-12]  // Carga total de filas
    cmp w11, w9
    bge endPrintById // Si terminamos de imprimir todas las filas, salimos
    mov w12, #0 // resetea j para cada nueva fila
    str w12, [fp, #-24] // guarda j en el stack

printColsLoop:
    ldr w12, [fp, #-24] // Carga j
    ldr w10, [fp, #-16] // Carga total de columnas
    cmp w12, w10
    bge nextPrintRow // si terminamos de imprimir todas las columnas, vamos a la siguiente fila, si no, seguimos imprimiendo valores para la fila actual

    ldr w11, [fp, #-20] // Carga i
    ldr w13, [fp, #-16] // Carga total de columnas
    mul w14, w11, w13 // calculamos la posición base de la fila: i * columnas
    add w14, w14, w12  // sumamos la columna para obtener el offset total en elementos: i * columnas + j
    lsl w14, w14, #2 // multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-8] // Carga el puntero base de la matriz
    ldr w0, [x15, x14] // Carga el valor del elemento actual de la matriz en w0
    bl printInteger // Imprime el valor del elemento actual
    ldr x0, =strSpace
    bl printString // Imprime un espacio después del valor

    ldr w12, [fp, #-24] // Carga j
    add w12, w12, #1 // j++
    str w12, [fp, #-24] // Guarda j actualizado en el stack
    b printColsLoop

nextPrintRow:
    bl printEnter // Imprime salto de línea al finalizar cada fila
    ldr w11, [fp, #-20] // Carga i
    add w11, w11, #1 // i++
    str w11, [fp, #-20] // Guarda i actualizado en el stack
    b printRowsLoop // Itera a la siguiente fila

matrixNotFoundPrint:
    bl generalMatrixNotFound // Si no se encontró la matriz, mostramos mensaje de error

endPrintById: 
    add sp, sp, #48
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* printLastResult:
* Muestra la última matriz resultado generada en consola.
* ----------------------------------------------------- */
printLastResult:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #32 // Espacio para variables locales: puntero matriz, filas, columnas, i, j

continuePrintLastResult:
    bl getMatrixResult  // Busca la matriz resultado, retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-8] // Guardamos el puntero de la matriz en el stack
    str w1, [fp, #-12] // Guardamos filas en el stack
    str w2, [fp, #-16] // Guardamos columnas en el stack

    cmp x0, #0
    beq matrixResultNotFoundPrint // Si no se encontró la matriz (puntero 0), mostramos mensaje de error

    mov w11, #0 // creamos variable i para iterar filas
    str w11, [fp, #-20] // Guardamos i en el stack

/* -----------------------------------------------------
* Recorrido de la matriz usando i para filas y j para columnas, 
* calculando el offset para acceder a cada elemento y luego imprimiendo su valor 
* seguido de un espacio. Al finalizar cada fila, se imprime un salto de línea.
-----------------------------------------------------*/
printLastResultRowsLoop:
    ldr w11, [fp, #-20] // Carga i
    ldr w9, [fp, #-12]  // Carga total de filas
    cmp w11, w9
    bge endPrintLastResult // Si terminamos de imprimir todas las filas, salimos
    mov w12, #0 // resetea j para cada nueva fila
    str w12, [fp, #-24] // guarda j en el stack

printLastResultColsLoop:
    ldr w12, [fp, #-24] // Carga j
    ldr w10, [fp, #-16] // Carga total de columnas
    cmp w12, w10
    bge nextPrintLastResultRow // si terminamos de imprimir todas las columnas, vamos a la siguiente fila, si no, seguimos imprimiendo valores para la fila actual

    ldr w11, [fp, #-20] // Carga i
    ldr w13, [fp, #-16] // Carga total de columnas
    mul w14, w11, w13 // calculamos la posición base de la fila: i * columnas
    add w14, w14, w12  // sumamos la columna para obtener el offset total en elementos: i * columnas + j
    lsl w14, w14, #2 // multiplicamos por 4 para obtener el offset en bytes
    ldr x15, [fp, #-8] // Carga el puntero base de la matriz
    ldr w0, [x15, x14] // Carga el valor del elemento actual de la matriz en w0
    bl printInteger // Imprime el valor del elemento actual
    ldr x0, =strSpace
    bl printString // Imprime un espacio después del valor

    ldr w12, [fp, #-24] // Carga j
    add w12, w12, #1 // j++
    str w12, [fp, #-24] // Guarda j actualizado en el stack
    b printLastResultColsLoop

nextPrintLastResultRow:
    bl printEnter // Imprime salto de línea al finalizar cada fila
    ldr w11, [fp, #-20] // Carga i
    add w11, w11, #1 // i++
    str w11, [fp, #-20] // Guarda i actualizado en el stack
    b printLastResultRowsLoop // Itera a la siguiente fila

matrixResultNotFoundPrint:
    bl generalMatrixResultNotFound // Si no se encontró la matriz, mostramos mensaje de error

endPrintLastResult: 
    add sp, sp, #32
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* freeMatrixById:
* Solicita un ID y libera la matriz asociada con munmap.
* ----------------------------------------------------- */
freeMatrixById:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #32 // Espacio para variables locales: puntero matriz, filas, columnas, indice matriz

askFreeId:
    ldr x0, =strAskIdFree
    bl printString
    bl readMatrixIdFromConsole // Lee el ID ingresado y lo valida, retorna 0 si es inválido
    cmp x0, #0
    bne continueFreeById // Si el ID es válido (no 0), continuamos con el proceso de liberación de la matriz
    bl generalStrCharInvalid // Si el ID es inválido, mostramos mensaje de error y volvemos a pedir el ID
    b askFreeId

continueFreeById:
    mov w9, w0 // Guardamos el ID ingresado en w9 para usarlo en la búsqueda de la matriz a liberar
    sub w10, w9, #'A' // Calculamos el indice interno restando el valor ASCII de 'A' al ID ingresado, por ejemplo, A->0, B->1, etc.
    str w10, [fp, #-20] // Guardamos el indice calculado en el stack

    bl getMatrixById // Busca la matriz por ID, retorna puntero en x0, filas en w1, columnas en w2
    str x0, [fp, #-8] // Guardamos el puntero de la matriz a liberar en el stack
    str w1, [fp, #-12] // Guardamos filas en el stack
    str w2, [fp, #-16] // Guardamos columnas en el stack

    cmp x0, #0
    beq matrixNotFoundFree // Si no se encontró la matriz (puntero 0), mostramos mensaje de error

    ldr w11, [fp, #-12] // Carga filas
    ldr w12, [fp, #-16] // Carga columnas
    mul w13, w11, w12 // Calcula cantidad de elementos: filas * columnas
    lsl w13, w13, #2 // Multiplica por 4 para obtener bytes a liberar

    ldr x0, [fp, #-8] // Carga el puntero base de la matriz a liberar
    uxtw x1, w13 // Convierte a 64 bits para enviar a matrixFree en x1
    bl matrixFree // Libera la memoria de la matriz con munmap

    // Proceso para Limpiar metadata del indice liberado
    ldr w10, [fp, #-20] // Carga el indice de la matriz liberada
    ldr x14, =matrixPointers // Carga la direccion de matrixPointers
    uxtw x15, w10 // Convierte a 64 bits
    lsl x15, x15, #3 // Multiplica por 8 para obtener el offset correcto (punteros de 64 bits)
    str xzr, [x14, x15] // rellenamos con 0 el puntero de matrixPointers[indice]

    ldr w10, [fp, #-20] // Carga el indice de la matriz liberada
    ldr x14, =matrixRows // Carga la direccion de matrixRows
    uxtw x15, w10 // Convierte a 64 bits
    lsl x15, x15, #2  // Multiplica por 4 para obtener el offset correcto (enteros de 32 bits)
    str wzr, [x14, x15] // rellenamos con 0 las filas de matrixRows[indice]

    ldr w10, [fp, #-20] // Carga el indice de la matriz liberada
    ldr x14, =matrixCols // Carga la direccion de matrixCols
    uxtw x15, w10 // Convierte a 64 bits
    lsl x15, x15, #2 // Multiplica por 4 para obtener el offset correcto (enteros de 32 bits)
    str wzr, [x14, x15] // rellenamos con 0 las columnas de matrixCols[indice]

    ldr w10, [fp, #-20] // Carga el indice de la matriz liberada
    ldr x14, =matrixIds // Carga la direccion de matrixIds
    uxtw x15, w10 // Convierte a 64 bits
    strb wzr, [x14, x15] // rellenamos con 0 el ID de matrixIds[indice]

    ldr x0, =strMatrixFreed
    bl printString // Imprime mensaje de éxito al liberar la matriz
    b endFreeById   

matrixNotFoundFree:
    bl generalMatrixNotFound // Si no se encontró la matriz, mostramos mensaje de error

endFreeById:
    add sp, sp, #32
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* getMatrixById:
* Busca una matriz por su identificador ASCII (A..Z).
*
* Entrada:
* x0 = identificador ASCII de la matriz
*
* Retorno:
* x0 = puntero de matriz (0 si no existe)
* w1 = filas
* w2 = columnas
*
* Registros importantes:
* w10 = indice interno (ID - 'A')
* w12 = cantidad de matrices creadas (matrixCount)
* ----------------------------------------------------- */
getMatrixById:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp

    mov w9, w0 // Guardamos el ID ingresado en w9 para usarlo en la búsqueda de la matriz
    cmp w9, #'A' 
    blt notFoundMatrix // Si es menor que 'A', no es un ID válido, vamos a la etiqueta de matriz no encontrada
    cmp w9, #'Z' //
    bgt notFoundMatrix // Si es mayor que 'Z', no es un ID válido, vamos a la etiqueta de matriz no encontrada

    // Convierte ID a indice: A->0, B->1, ...
    sub w10, w9, #'A' // Calculamos el indice interno restando el valor ASCII de 'A' al ID ingresado
    ldr x11, =matrixCount // Carga la direccion de matrixCount
    ldr w12, [x11] // Carga la cantidad de matrices creadas (matrixCount)
    cmp w10, w12 
    bhs notFoundMatrix // Si el indice calculado es mayor o igual a matrixCount, significa que el ID no corresponde a una matriz creada, vamos a la etiqueta de matriz no encontrada

    // Carga puntero y dimensiones del indice encontrado
    ldr x13, =matrixPointers // Carga la direccion de matrixPointers
    uxtw x14, w10 // Convierte a 64 bits 
    lsl x14, x14, #3 // Multiplica por 8 para obtener el offset correcto (punteros de 64 bits)
    ldr x0, [x13, x14] // Carga el puntero de la matriz encontrada en x0 para el retorno

    ldr x13, =matrixRows // Carga la direccion de matrixRows
    uxtw x14, w10 // Convierte a 64
    lsl x14, x14, #2 // Multiplica por 4 para obtener el offset correcto (enteros de 32 bits)
    ldr w1, [x13, x14] // Carga la cantidad de filas de la matriz encontrada en w1 para el retorno

    ldr x13, =matrixCols // Carga la direccion de matrixCols
    uxtw x14, w10 // Convierte a 64 bits
    lsl x14, x14, #2 // Multiplica por 4 para obtener el offset correcto (enteros de 32 bits)
    ldr w2, [x13, x14] // Carga la cantidad de columnas de la matriz encontrada en w2 para el retorno

    ldp fp, lr, [sp], #0x10
    ret


/* -----------------------------------------------------
* getMatrixResult:
* Busca la matriz resultado.
*
* Entrada:
* no tiene entradas, ya que siempre se busca la matriz resultado almacenada en matrixResultPointer
*
* Retorno:
* x0 = puntero de matriz (0 si no existe)
* w1 = filas
* w2 = columnas
*
* Registros importantes:
* x13 = registros temporales para cargar metadata de la matriz resultado
* ----------------------------------------------------- */
getMatrixResult:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp

    // Carga puntero y dimensiones de la matriz resultado
    ldr x0, =matrixResultPointer // Carga la direccion de matrixResultPointer
    ldr x0, [x0] // Carga el puntero de la matriz resultado en x0 para el retorno

    cmp x0, #0
    beq notFoundMatrix // Si el puntero es 0, significa que no hay

    ldr x13, =matrixResultRows // Carga la direccion de matrixResultRows
    ldr w1, [x13] // Carga la cantidad de filas de la matriz resultado en w1 para el retorno

    ldr x13, =matrixResultCols // Carga la direccion de matrixResultCols
    ldr w2, [x13] // Carga la cantidad de columnas de la matriz resultado en w2 para el retorno

    ldp fp, lr, [sp], #0x10
    ret

/* ----------------------------------------------------- 
* subrutina comun para getMatrixById y getMatrixResult cuando no se encuentra la matriz solicitada
* no tiene stp porque se asume que la función que llama a esta etiqueta ya hizo el stp correspondiente
* pero si tiene el ldp para restaurar fp y lr antes de retornar
-------------------------------------------------------*/
notFoundMatrix:
    // Retorno nulo cuando no existe la matriz solicitada
    mov x0, #0
    mov w1, #0
    mov w2, #0
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* generalMatrixNotFound:
* Funcion general para mostrar mensaje de error cuando no se encuentra una matriz solicitada por ID.:
* no recibe parametros, solo muestra mensaje de error y retorna.
* ----------------------------------------------------- */
generalMatrixNotFound:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    ldr x0, =strMatrixNotFound
    bl printString
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* generalMatrixResultNotFound:
* Funcion general para mostrar mensaje de error cuando no existe matriz resultado:
* no recibe parametros, solo muestra mensaje de error y retorna.
* ----------------------------------------------------- */
generalMatrixResultNotFound:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    ldr x0, =strMatrixResultNotFound
    bl printString
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* generalStrIntInvalid:
* Funcion general para mostrar mensaje de error cuando se ingresa un entero invalido
* no recibe parametros, solo muestra mensaje de error y retorna.
* ----------------------------------------------------- */
generalStrIntInvalid:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    ldr x0, =strIntInvalid
    bl printString
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* generalStrCharInvalid:
* Funcion general para mostrar mensaje de error cuando se ingresa un string invalido
* no recibe parametros, solo muestra mensaje de error y retorna.
* ----------------------------------------------------- */
generalStrCharInvalid:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    ldr x0, =strCharInvalid
    bl printString
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* mallocResultMatrix:
* Reserva memoria para la matriz resultado usando matrixMalloc.
* Entrada:
* w0 = filas de la matriz resultado
* w1 = columnas de la matriz resultado
* Retorno:
* x0 = direccion base reservada para la matriz resultado
* ----------------------------------------------------- */
mallocResultMatrix:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #16 // espacio para guardar filas y columnas de la matriz resultado

    str w0, [fp, #-4] // Guardamos filas resultado en el stack
    str w1, [fp, #-8] // Guardamos columnas resultado en el stack

    // Reservamos memoria para la nueva matriz resultado usando matrixMalloc
    ldr w11, [fp, #-4] // Carga filas del stack
    ldr w12, [fp, #-8] // Carga columnas del stack
    mul w13, w11, w12 // Calcula cantidad de elementos: filas * columnas
    lsl w13, w13, #2 // Multiplica por 4 para obtener bytes a reservar
    uxtw x0, w13 // Convierte a 64 bits para enviar a matrixMalloc en x0
    bl matrixMalloc // reservamos memoria y obtenemos puntero base en x0

    // Guardamos el puntero de la nueva matriz transpuesta en matrixResultPointer para su uso posterior
    ldr x14, =matrixResultPointer // Carga la direccion de matrixResultPointer
    str x0, [x14] // Guarda el puntero de la nueva matriz transpuesta en matrixResultPointer
    // Guardamos las dimensiones de la matriz transpuesta en matrixResultRows y matrixResultCols para su uso posterior
    ldr x14, =matrixResultRows // Carga la direccion de matrixResultRows
    ldr w11, [fp, #-4] // Carga filas del stack
    str w11, [x14] // Guarda filas de la matriz resultado
    ldr x14, =matrixResultCols // Carga la direccion de matrixResultCols
    ldr w12, [fp, #-8] // Carga columnas del stack
    str w12, [x14] // Guarda columnas de la matriz resultado

    add sp, sp, #16
    ldp fp, lr, [sp], #0x10
    ret

// Liberamos cualquier resultado previo almacenado en matrixResultPointer antes de guardar el nuevo resultado
freePreviousMatrixResult:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp

    // Cargamos metadata del resultado previo desde variables globales
    ldr x14, =matrixResultPointer
    ldr x0, [x14] // puntero resultado previo
    cmp x0, #0
    beq endFreePreviousResult // Si no hay resultado previo (puntero 0) terminamos el proceso de liberación y limpieza de metadata

    // Si hay un resultado previo, calculamos su tamaño para liberarlo con matrixFree
    ldr x14, =matrixResultRows
    ldr w11, [x14] // Carga filas del resultado previo
    ldr x14, =matrixResultCols
    ldr w12, [x14] // Carga columnas del resultado previo
    mul w13, w11, w12 // Calcula cantidad de elementos: filas * columnas
    lsl w13, w13, #2 // Multiplica por 4 para obtener bytes a liberar

    uxtw x1, w13 // Convierte a 64 bits para enviar a matrixFree en x1
    bl matrixFree // Libera la memoria de la matriz con munmap

    // Proceso para Limpiar metadata de la matriz resultado previa
    ldr x14, =matrixResultPointer // Carga la direccion de matrixResultPointer
    str xzr, [x14] // rellenamos con 0 el puntero de matrixResultPointer

    ldr x14, =matrixResultRows // Carga la direccion de matrixResultRows
    str wzr, [x14] // rellenamos con 0 las filas del resultado

    ldr x14, =matrixResultCols // Carga la direccion de matrixResultCols
    str wzr, [x14] // rellenamos con 0 las columnas del resultado

endFreePreviousResult:
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* matrixMalloc:
* Reserva memoria dinamica con syscall mmap.
*
* Entrada:
* x0 = bytes a reservar
*
* Retorno:
* x0 = direccion base reservada
*
* Registros importantes:
* x8 = numero de syscall (222 = mmap)
* ----------------------------------------------------- */
matrixMalloc:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp

    mov x1, x0
    mov x0, #0
    mov x2, #0x3
    mov x3, #0x22
    mov x4, #-1
    mov x5, #0
    mov x8, #222
    svc #0

    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* matrixFree:
* Libera memoria dinamica usando syscall munmap.
*
* Entrada:
* x0 = direccion base reservada
* x1 = bytes reservados
* ----------------------------------------------------- */
matrixFree:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp

    mov x8, #215
    svc #0

    ldp fp, lr, [sp], #0x10
    ret
