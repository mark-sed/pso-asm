ASM_C=nasm
ASM_FLAGS=-f elf64 -F dwarf -g
ASM_SRC=pso.asm
ASM_OUTPUT=pso.o
C_C=gcc
C_FLAGS=-Wall -pedantic -no-pie
C_OUTPUT=main
C_SRC=main.c

build: obj main

obj:
	$(ASM_C) $(ASM_FLAGS) -o $(ASM_OUTPUT) $(ASM_SRC)

main:
	$(C_C) $(C_FLAGS) -o $(C_OUTPUT) $(C_SRC) $(ASM_OUTPUT)

clean:
	rm $(ASM_OUTPUT)
	rm $(C_OUTPUT)

