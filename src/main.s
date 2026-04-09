/* =========================================================
 * Lección 00 – Hello World en ARM64 (Linux)
 * Archivo: main.s
 *
 * Ensamblador: aarch64-linux-gnu-as
 * Enlazador : aarch64-linux-gnu-ld
 * Ejecución : qemu-aarch64
 *
 * No usa libc, solo syscalls de Linux.
 * ========================================================= */

/* ---------------------------------------------------------
 * Registros usados en este archivo
 * ---------------------------------------------------------
 * x0 = argumento 1 de syscall (fd o codigo de salida)
 * x1 = argumento 2 de syscall (direccion de buffer)
 * x2 = argumento 3 de syscall (cantidad de bytes)
 * x8 = numero de syscall Linux ARM64
 * --------------------------------------------------------- */

/* ---------------------------------------------------------
 * Sección de datos
 * --------------------------------------------------------- */
.section .data

msg:
    .ascii "Hello, world\n"     // Cadena a imprimir (sin NULL)
    msg_len = . - msg           // Longitud del mensaje

/* ---------------------------------------------------------
 * Sección de código
 * --------------------------------------------------------- */
.section .text
.global _start               // Punto de entrada real

_start:
    /* -----------------------------------------------------
     * syscall: write(stdout, msg, msg_len)
     *
     * x0 = file descriptor (1 = stdout)
     * x1 = dirección del buffer
     * x2 = número de bytes
     * x8 = número de syscall (64)
     * ----------------------------------------------------- */
    mov     x0, #1               // stdout
    adr     x1, msg              // dirección del mensaje
    mov     x2, msg_len          // longitud
    mov     x8, #64              // syscall write
    svc     #0                   // llamada al kernel

    /* -----------------------------------------------------
     * syscall: exit(0)
     *
     * x0 = código de salida
     * x8 = número de syscall (93)
     * ----------------------------------------------------- */
    mov     x0, #0               // código de salida
    mov     x8, #93              // syscall exit
    svc     #0                   // llamada al kernel