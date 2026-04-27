# Pruebas 5x5 (solo enteros)

## Matrices cargadas
- `A` (diagonal):

2 0 0 0 0  
0 4 0 0 0  
0 0 6 0 0  
0 0 0 8 0  
0 0 0 0 10

- `B` (triangular superior, det=1):

1 1 0 0 0  
0 1 1 0 0  
0 0 1 1 0  
0 0 0 1 1  
0 0 0 0 1

- `C` (singular, sin inversa):

1 2 3 4 5  
1 2 3 4 5  
0 1 0 1 0  
2 0 2 0 2  
3 3 3 3 3

- `D` (identidad 5x5):

1 0 0 0 0  
0 1 0 0 0  
0 0 1 0 0  
0 0 0 1 0  
0 0 0 0 1

## Comando recomendado (PTY)
No usar redirección directa `./build/main < ...` porque `read` consume buffers de 32 bytes. Usar:

```bash
cd src
make
script -qec "./build/main" /tmp/p2_full_session.log < ../docs/test_5x5_input.txt
```

## Checkpoints esperados
- Opción 4 (Identidad sobre `A`): identidad 5x5.
- Opción 5 (Transpuesta de `B`):

1 0 0 0 0  
1 1 0 0 0  
0 1 1 0 0  
0 0 1 1 0  
0 0 0 1 1

- Opción 6 (Gauss sobre `B`): mantiene triangular superior y `Signo de swaps: 1`.
- Opción 7 (Gauss-Jordan sobre `B`): identidad 5x5 y mensaje de éxito.
- Opción 8 (Inversa de `B`):

1 -1 1 -1 1  
0 1 -1 1 -1  
0 0 1 -1 1  
0 0 0 1 -1  
0 0 0 0 1

- Opción 8 (Inversa de `C`): mensaje `La matriz no tiene inversa...`.
- Opción 9 (Determinante de `B`): `1`.
- Opción 9 (Determinante de `C`): `0`.
- Opción 10.1 (Suma `A + D`):

3 0 0 0 0  
0 5 0 0 0  
0 0 7 0 0  
0 0 0 9 0  
0 0 0 0 11

- Opción 10.2 (Resta `A - D`):

1 0 0 0 0  
0 3 0 0 0  
0 0 5 0 0  
0 0 0 7 0  
0 0 0 0 9

- Opción 10.3 (Multiplicación `A * B`):

2 2 0 0 0  
0 4 4 0 0  
0 0 6 6 0  
0 0 0 8 8  
0 0 0 0 10

- Opción 10.4 (División `A / B = A * inv(B)`):

2 -2 2 -2 2  
0 4 -4 4 -4  
0 0 6 -6 6  
0 0 0 8 -8  
0 0 0 0 10

- Opción 11 (Último resultado): debe coincidir con división.
- Opción 2 + 3 sobre `D`: liberar y luego `No existe una matriz con ese ID.`
