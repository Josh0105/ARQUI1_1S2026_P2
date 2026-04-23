.global newMatrix
.global getMatrixById
.global printMatrixById
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
    strInvalid: .string "Entrada invalida. Ingrese un entero positivo.\n"
    strNoSlot: .string "No hay mas identificadores disponibles (A-Z).\n"
    strAskIdPrint: .string "Ingrese el ID de la matriz a imprimir (A-Z): "
    strAskIdFree: .string "Ingrese el ID de la matriz a liberar (A-Z): "
    strMatrixNotFound: .string "No existe una matriz con ese ID.\n"
    strMatrixFreed: .string "Matriz liberada correctamente.\n"
    strMatrixAlreadyFreed: .string "La matriz ya estaba liberada.\n"
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
    sub sp, sp, #64

    // Verifica si aun hay slots disponibles (A..Z)
    ldr x9, =matrixCount
    ldr w10, [x9]
    cmp w10, #26
    bge noMatrixSlot

askRows:
    // Solicita filas hasta recibir entero positivo
    ldr x0, =strRows
    bl printString
    bl readIntFromConsole
    cmp x0, #1
    bge saveRows
    ldr x0, =strInvalid
    bl printString
    b askRows

saveRows:
    str w0, [fp, #-4]

askCols:
    // Solicita columnas hasta recibir entero positivo
    ldr x0, =strCols
    bl printString
    bl readIntFromConsole
    cmp x0, #1
    bge saveCols
    ldr x0, =strInvalid
    bl printString
    b askCols

saveCols:
    str w0, [fp, #-8]

    // bytes = filas * columnas * 4 (int32)
    ldr w11, [fp, #-4]
    ldr w12, [fp, #-8]
    mul w13, w11, w12
    lsl w13, w13, #2
    uxtw x0, w13 // Convierte a 64 bits para syscall
    bl matrixMalloc
    str x0, [fp, #-16]

    // Toma el indice disponible y lo guarda para reutilizarlo
    ldr x14, =matrixCount
    ldr w15, [x14]
    str w15, [fp, #-20]

    // Guarda puntero de matriz en matrixPointers[indice]
    ldr x16, =matrixPointers
    uxtw x17, w15 // Convierte a 64 bits para syscall
    lsl x17, x17, #3
    add x16, x16, x17
    ldr x0, [fp, #-16]
    str x0, [x16]

    // Guarda filas en matrixRows[indice]
    ldr x16, =matrixRows
    uxtw x17, w15 // Convierte a 64 bits para syscall
    lsl x17, x17, #2
    add x16, x16, x17
    ldr w0, [fp, #-4]
    str w0, [x16]

    // Guarda columnas en matrixCols[indice]
    ldr x16, =matrixCols
    uxtw x17, w15 // Convierte a 64 bits para syscall
    lsl x17, x17, #2
    add x16, x16, x17
    ldr w0, [fp, #-8]
    str w0, [x16]

    // ID = 'A' + indice
    ldr x16, =matrixIds
    uxtw x17, w15 // Convierte a 64 bits para syscall
    add x16, x16, x17
    mov w0, #'A'
    add w0, w0, w15
    strb w0, [x16]

    add w15, w15, #1
    str w15, [x14]

    // Bucle doble de llenado: i filas, j columnas
    mov w9, #0
    str w9, [fp, #-24]   // i
loopRows:
    ldr w9, [fp, #-24]
    ldr w10, [fp, #-4]
    cmp w9, w10
    bge endInputValues

    mov w11, #0
    str w11, [fp, #-28]  // j
loopCols:
    ldr w11, [fp, #-28]
    ldr w9, [fp, #-24]
    ldr w12, [fp, #-8]
    cmp w11, w12
    bge nextRow

    // Imprime prompt: Ingrese el valor[i][j]:
    ldr x0, =strVal1
    bl printString
    ldr w9, [fp, #-24]
    uxtw x0, w9 // Convierte a 64 bits para printInteger
    bl printInteger
    ldr x0, =strVal2
    bl printString
    ldr w11, [fp, #-28]
    uxtw x0, w11 // Convierte a 64 bits para printInteger
    bl printInteger
    ldr x0, =strVal3
    bl printString

askValue:
    // Acepta cero o positivo para elementos de matriz
    bl readIntFromConsole
    cmp x0, #0
    bge storeValue
    ldr x0, =strInvalid
    bl printString
    b askValue

storeValue:
    // offset = (i * columnas + j) * 4  #ROW MAJOR
    ldr w9, [fp, #-24]
    ldr w11, [fp, #-28]
    ldr w13, [fp, #-8]
    mul w14, w9, w13
    add w14, w14, w11
    lsl w14, w14, #2
    ldr x15, [fp, #-16]
    str w0, [x15, x14]

    add w11, w11, #1
    str w11, [fp, #-28]
    b loopCols

nextRow:
    ldr w9, [fp, #-24]
    add w9, w9, #1
    str w9, [fp, #-24]
    b loopRows

endInputValues:
    // Muestra ID asignado al finalizar
    ldr x0, =strSaved
    bl printString

    ldr w1, [fp, #-20]
    mov w0, #'A'
    add w0, w0, w1
    ldr x2, =matrixIdBuffer
    strb w0, [x2]
    mov w3, #0
    strb w3, [x2, #1]
    mov x0, x2
    bl printString
    bl printEnter
    b endIngresarMatriz

noMatrixSlot:
    // Sin slots disponibles (se alcanzo Z)
    ldr x0, =strNoSlot
    bl printString

endIngresarMatriz:
    add sp, sp, #64
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* readMatrixIdFromConsole:
* Lee un ID de matriz (A..Z) desde consola.
*
* Retorno:
* x0 = ASCII en mayuscula si es valido, 0 si es invalido
* ----------------------------------------------------- */
readMatrixIdFromConsole:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp

    bl cleanUpInput
    mov x0, #0
    ldr x1, =input
    mov x2, #32
    mov x8, #63
    svc #0
    cmp x0, #1
    blt invalidMatrixId

    ldr x1, =input
    ldrb w0, [x1]

    cmp w0, #'a'
    blt checkUpperId
    cmp w0, #'z'
    bgt checkUpperId
    sub w0, w0, #32

checkUpperId:
    cmp w0, #'A'
    blt invalidMatrixId
    cmp w0, #'Z'
    bgt invalidMatrixId

    ldp fp, lr, [sp], #0x10
    ret

invalidMatrixId:
    mov x0, #0
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* printMatrixById:
* Solicita un ID y muestra la matriz asociada en consola.
* ----------------------------------------------------- */
printMatrixById:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #48

askPrintId:
    ldr x0, =strAskIdPrint
    bl printString
    bl readMatrixIdFromConsole
    cmp x0, #0
    bne continuePrintById
    ldr x0, =strMatrixNotFound
    bl printString
    b askPrintId

continuePrintById:
    bl getMatrixById
    str x0, [fp, #-8]
    str w1, [fp, #-12]
    str w2, [fp, #-16]

    cmp x0, #0
    beq matrixNotFoundPrint

    mov w11, #0
    str w11, [fp, #-20] // i

printRowsLoop:
    ldr w11, [fp, #-20]
    ldr w9, [fp, #-12]  // filas
    cmp w11, w9
    bge endPrintById
    mov w12, #0
    str w12, [fp, #-24] // j

printColsLoop:
    ldr w12, [fp, #-24]
    ldr w10, [fp, #-16] // columnas
    cmp w12, w10
    bge nextPrintRow

    ldr w11, [fp, #-20]
    ldr w13, [fp, #-16]
    mul w14, w11, w13
    add w14, w14, w12
    lsl w14, w14, #2
    ldr x15, [fp, #-8]
    ldr w0, [x15, x14]
    bl printInteger
    ldr x0, =strSpace
    bl printString

    ldr w12, [fp, #-24]
    add w12, w12, #1
    str w12, [fp, #-24]
    b printColsLoop

nextPrintRow:
    bl printEnter
    ldr w11, [fp, #-20]
    add w11, w11, #1
    str w11, [fp, #-20]
    b printRowsLoop

matrixNotFoundPrint:
    ldr x0, =strMatrixNotFound
    bl printString

endPrintById:
    add sp, sp, #48
    ldp fp, lr, [sp], #0x10
    ret

/* -----------------------------------------------------
* freeMatrixById:
* Solicita un ID y libera la matriz asociada con munmap.
* ----------------------------------------------------- */
freeMatrixById:
    stp fp, lr, [sp, #-0x10]!
    mov fp, sp
    sub sp, sp, #32

askFreeId:
    ldr x0, =strAskIdFree
    bl printString
    bl readMatrixIdFromConsole
    cmp x0, #0
    bne continueFreeById
    ldr x0, =strMatrixNotFound
    bl printString
    b askFreeId

continueFreeById:
    mov w9, w0
    sub w10, w9, #'A'
    str w10, [fp, #-20] // indice a liberar

    bl getMatrixById
    str x0, [fp, #-8]
    str w1, [fp, #-12]
    str w2, [fp, #-16]

    cmp x0, #0
    beq matrixNotFoundFree

    ldr w11, [fp, #-12]
    ldr w12, [fp, #-16]
    mul w13, w11, w12
    lsl w13, w13, #2

    ldr x0, [fp, #-8]
    uxtw x1, w13
    bl matrixFree

    // Limpia metadata del indice liberado
    ldr w10, [fp, #-20]
    ldr x14, =matrixPointers
    uxtw x15, w10
    lsl x15, x15, #3
    str xzr, [x14, x15]

    ldr w10, [fp, #-20]
    ldr x14, =matrixRows
    uxtw x15, w10
    lsl x15, x15, #2
    str wzr, [x14, x15]

    ldr w10, [fp, #-20]
    ldr x14, =matrixCols
    uxtw x15, w10
    lsl x15, x15, #2
    str wzr, [x14, x15]

    ldr w10, [fp, #-20]
    ldr x14, =matrixIds
    uxtw x15, w10
    strb wzr, [x14, x15]

    ldr x0, =strMatrixFreed
    bl printString
    b endFreeById

matrixNotFoundFree:
    ldr x0, =strMatrixNotFound
    bl printString

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

    mov w9, w0
    cmp w9, #'A'
    blt notFoundMatrix
    cmp w9, #'Z'
    bgt notFoundMatrix

    // Convierte ID a indice: A->0, B->1, ...
    sub w10, w9, #'A'
    ldr x11, =matrixCount
    ldr w12, [x11]
    cmp w10, w12
    bhs notFoundMatrix

    // Carga puntero y dimensiones del indice encontrado
    ldr x13, =matrixPointers
    uxtw x14, w10 // Convierte a 64 bits para syscall
    lsl x14, x14, #3
    ldr x0, [x13, x14]

    ldr x13, =matrixRows
    uxtw x14, w10 // Convierte a 64 bits para syscall
    lsl x14, x14, #2
    ldr w1, [x13, x14]

    ldr x13, =matrixCols
    uxtw x14, w10 // Convierte a 64 bits para syscall
    lsl x14, x14, #2
    ldr w2, [x13, x14]

    ldp fp, lr, [sp], #0x10
    ret

notFoundMatrix:
    // Retorno nulo cuando no existe la matriz solicitada
    mov x0, #0
    mov w1, #0
    mov w2, #0
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