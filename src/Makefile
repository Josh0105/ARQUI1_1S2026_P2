# Template: ARM64 nativo (sin QEMU) para host ARM64 – flujo mínimo

# ---------------------------------------------------------
# Toolchain (host ARM64)
# ---------------------------------------------------------
AS      = as                    # o aarch64-linux-gnu-as si prefieres el prefijo
LD      = ld

# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------
SRC     = main.s
BUILD   = build
OBJ     = $(BUILD)/main.o
BIN     = $(BUILD)/main

# ---------------------------------------------------------
# Flags
# ---------------------------------------------------------
ASFLAGS = -g                    # símbolos de depuración
LDFLAGS =

# ---------------------------------------------------------
# Targets
# ---------------------------------------------------------

# Compilación por defecto
all: $(BIN)

# Crear carpeta build si no existe
$(BUILD):
	mkdir -p $(BUILD)

# Ensamblar
$(OBJ): $(SRC) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

# Enlazar
$(BIN): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $<

# Ejecutar directamente en host ARM64
run: $(BIN)
	$(BIN)

# ---------------------------------------------------------
# Debug local (sin QEMU)
# ---------------------------------------------------------
gdb: $(BIN)
	gdb $(BIN)

# ---------------------------------------------------------
# Limpieza
# ---------------------------------------------------------
clean:
	rm -rf $(BUILD)

# ---------------------------------------------------------
# Utilidades
# ---------------------------------------------------------
info:
	@echo "Targets:"
	@echo "  make        -> compila el programa"
	@echo "  make run    -> ejecuta directamente en ARM64"
	@echo "  make gdb    -> abre gdb local"
	@echo "  make clean  -> limpia build/"
