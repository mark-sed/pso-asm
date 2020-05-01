# Makefile for compiling pso module
# @author Marek Sedláček
# Brno University of Technology

ASM_C=nasm
ASM_FLAGS=-f elf64 -F dwarf -g
ASM_SRC=pso.asm
ASM_OUTPUT=pso.o
C_C=gcc
C_FLAGS=-Wall -pedantic -no-pie -g
C_OUTPUT=pso
C_SRC=main.c
C_LIBS=-lm


.PHONY: obj main

build: obj main

obj:
	$(ASM_C) $(ASM_FLAGS) -o $(ASM_OUTPUT) $(ASM_SRC)

main:
	$(C_C) $(C_FLAGS) -o $(C_OUTPUT) $(C_SRC) $(ASM_OUTPUT) $(C_LIBS)

clean:
	rm $(ASM_OUTPUT)
	rm $(C_OUTPUT)

