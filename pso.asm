;; Particle swarm algorithm module. 
;;
;; Compiler used: NASM version 2.13
;; Made for: 64-bit Linux with C caling convention
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
extern rand

;; Macros
%define _MACRO_PSO3DIM_STATIC_PARTICLES 20          ;; How many particles will be used in pso3dim_static function

;; typedef struct {
;;    double velocity[2];  //< Velocity for each dimension
;;    double position[2];  //< Position in each dimension
;;    double best_pos[2];  //< Best position
;;    double best_val;     //< Value of the best position
;; } TParticle3Dim;
%define _TPARTICLE3DIM_SIZE 8                       ;; Extra padding is added for alignment

;; Constants
PSO3DIM_STATIC_PARTICLES    EQU _MACRO_PSO3DIM_STATIC_PARTICLES
DBL_MAX                     EQU 0x7FEFFFFFFFFFFFFF  ;; Maximal value of double

;; Global uninitialized variables
section .bss
swarm   resb _MACRO_PSO3DIM_STATIC_PARTICLES * _TPARTICLE3DIM_SIZE ;; Array of TParticle3Dim

;; Global variables
section .data

;; Code
section .text

;; PSO3DIM_STATIC
;; Particle swarm optimization algorithm for 3 dimensional functions that does not use dynamical allocation
;;
;; @param
;;      func3dim function   - RDI - Function in which is optimization done
;;      double[2][2] bounds - RSI - Bounds of the function in which will be the function optimized.
;;                                  this should be 2 arrays of 2 values where the 1st one is
;;                                  the minimum and second one is the maximum. E.g.: for `x in <0, 5> &
;;                                  y in <-10, 10>` the bounds should be `{{0.0, 5.0}, {-10.0, 10.0}}`.
;;      fit_func fitness    - RDX - Fitness functions that determinates if passed in value is better
;;                                  than other passed in value
;;      ulong max_iter      - RCX - The amount of iterations that should be done.
;;                                  More results in better precision but longer calculation.
;; @return Struct with 2 doubles - the best found x and y coordinates.
;;         Returned x and y values are in xmm0 and xmm1 respectively.
;; @note The amount of particles is determinated by the value of `PSO3DIM_STATIC_PARTICLES`
;;
pso3dim_static:
        push rbp
        mov rbp, rsp
        and rsp, -16                            ;; Align stack for called functions
        ;; Stack frame end
        fninit                                  ;; Reset FPU stack

        mov rax, DBL_MAX 
        movq xmm0, rax
        ;; Leaving function
        pop rbp
        ret
;; end pso3dim_static