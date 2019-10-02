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
extern random_double

;; Macros
%define _PSO3DIM_STATIC_PARTICLES 20          ;; How many particles will be used in pso3dim_static function

;; typedef struct {
;;    double velocity[2];  //< Velocity for each dimension
;;    double position[2];  //< Position in each dimension
;;    double best_pos[2];  //< Best position
;;    double best_val;     //< Value of the best position
;; } TParticle3Dim;
%define _TPARTICLE3DIM_SIZE 56                      ;; Extra padding is added for alignment                 <<<<<<<??? Jde alignout
%define _TPARTICLE3DIM_VELOCITY0 0                  ;; Offsets of elements in particle struct
%define _TPARTICLE3DIM_VELOCITY1 8                  
%define _TPARTICLE3DIM_POSITION0 16                 
%define _TPARTICLE3DIM_POSITION1 24
%define _TPARTICLE3DIM_BEST_POS0 32
%define _TPARTICLE3DIM_BEST_POS1 40
%define _TPARTICLE3DIM_BEST_VAL  48

;; Function macros

;; INIT_PARTICLE3DIM
;; Initializes particle to random position and speed
;; @param
;;      1 Current particle struct address 
;;      2 Minimal X bound
;;      3 Maximal X bound
;;      4 Minimal Y bound
;;      5 Maximal Y bound
%macro init_particle3dim 5
        movq xmm0, [__CONST__1_0]               ;; Set -1 as minimum (for speed)
        movq xmm1, [__CONST_1_0]                ;; Set 1 as maximum (for speed)
        call random_double                      
        movq qword[%1+_TPARTICLE3DIM_VELOCITY0], xmm0 ;; Save generated value as velocity on X axis

        movq xmm0, [__CONST__1_0]               
        movq xmm1, [__CONST_1_0]                
        call random_double                      
        movq qword[%1+_TPARTICLE3DIM_VELOCITY1], xmm0 ;; Save generated value as velocity on Y axis
        
        movq xmm0, %2                           ;; Load bounds for random position generation
        movq xmm1, %3
        call random_double
        movq qword[%1+_TPARTICLE3DIM_POSITION0], xmm0
        movq qword[%1+_TPARTICLE3DIM_BEST_POS0], xmm0 ;; Set generated position also as the best one

        movq xmm0, %4
        movq xmm1, %5
        call random_double
        movq qword[%1+_TPARTICLE3DIM_POSITION1], xmm0
        movq qword[%1+_TPARTICLE3DIM_BEST_POS1], xmm0
%endmacro ;; init_particle3dim

;; Constants
DBL_MAX                     EQU 0x7FEFFFFFFFFFFFFF  ;; Maximal value of double

;; Global uninitialized variables
section .bss
swarm   resb _PSO3DIM_STATIC_PARTICLES * _TPARTICLE3DIM_SIZE ;; Array of TParticle3Dim

;; Global variables
section .data
__CONST__1_0     dq -1.0
__CONST_1_0      dq  1.0

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
        push r12
        push rbx
        ;; Stack frame end

        mov r12, rsi                            ;; Move bounds to callee saved register
        xor rbx, rbx
.swarm_init_loop:
        init_particle3dim swarm+rbx, qword[r12], qword[r12+8], qword[r12+16], qword[r12+24]
        add rbx, _TPARTICLE3DIM_SIZE
        cmp rbx, _TPARTICLE3DIM_SIZE*_PSO3DIM_STATIC_PARTICLES
        jb .swarm_init_loop                     ;; Initialize all particles

        ;; Leaving function
        pop rbx
        pop r12
        mov rsp, rbp
        pop rbp
        ret
;; end pso3dim_static