;; Particle swarm algorithm module. 
;;
;; Compiler used: NASM version 2.13
;;
;; @file pso.asm
;; @author Marek Sedlacek (xsedla1b)
;; @date October 2018
;; @email xsedla1b@fit.vutbr.cz 
;;        mr.mareksedlacek@gmail.com
;;

;; Exported functions
global pso3dim_static           ;; PSO algorithm for 3 dimensional function (does not use heap)

;; Included C functions

;; Constants

;; Global uninitialized variables
section .bss

;; Global variables
section .data

;; Code
section .text

;; PSO3DIM_STATIC
;;
;; PSO algorithm for 3 dimensional function (does not use heap)
;;
pso3dim_static:
        
        ;; Stack frame end
        
        ;; Leaving function

        ret
;; end pso3dim_static