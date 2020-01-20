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
%define _TPARTICLE3DIM_SIZE 64                      ;; Extra padding is added for alignment
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

;; RND2RAX 
;; Saves random value to rax
;; @param
;;      1 Max value
%macro rnd2rax 1
        xorps xmm0, xmm0                        ;; Set 0 and 1 as the arguments
        movq xmm1, %1
        call random_double
        movq rax, xmm0                          ;; Save random value to rax
%endmacro ;; rnd2rax

;; UPDATE_PARTICLE3DIM
;; Update velocity and position of a particle based on best global best position found
;; Minimal X bound should be broadcasted into ymm11, maximal X into ymm12, minimal Y into ymm13, maxmial Y into ymm14
;; @param
;;      1 Current particle struct address 
;;      2 Minimal X bound
;;      3 Maximal X bound
;;      4 Minimal Y bound
;;      5 Maximal Y bound
;;      6 Best global position X
;;      7 Best global position Y
%macro update_particle3dim 7
        ;; Filling ymm0 with 4 random doubles
        ;; Moving doubles to xmm registers and then xmm registers to ymm
        ;; because there is no vpinsrq for avx registers
        rnd2rax [__CONST_1_0]                   ;; Generate random double <0, 1>
        vpinsrq xmm8, rax, 0x0
        rnd2rax [__CONST_1_0]                        
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm10, ymm3, xmm8, 0x1      ;; Move 2 doubles from xmm2 to upper half of ymm14

        rnd2rax [__CONST_1_0]
        vpinsrq xmm8, rax, 0x0
        rnd2rax [__CONST_1_0]
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm9, ymm10, xmm8, 0x0     ;; Move 2 doubles from xmm2 to lower half of ymm15

        ;; Filling ymm1 with 4 random doubles
        rnd2rax [__CONST_1_0]                   ;; Generate random double <0, 1>
        vpinsrq xmm8, rax, 0x0
        rnd2rax [__CONST_1_0]                        
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm9, ymm3, xmm8, 0x1      ;; Move 2 doubles from xmm2 to upper half of ymm14

        rnd2rax [__CONST_1_0]
        vpinsrq xmm8, rax, 0x0
        rnd2rax [__CONST_1_0]
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm8, ymm10, xmm8, 0x0     ;; Move 2 doubles from xmm2 to lower half of ymm13

        vmulpd ymm0, ymm9, [__COEFF_CP]        ;; Multiply random numbers by CP
        vmulpd ymm1, ymm8, [__COEFF_CG]        ;; Multiply random numbers by CG

        ;; Load x velocity to ymm registers
        vpinsrq xmm0, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0], 0x0
        vpinsrq xmm0, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE], 0x1
        vinserti128 ymm2, ymm10, xmm0, 0x1
        vpinsrq xmm0, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*2], 0x0
        vpinsrq xmm0, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*3], 0x1
        vinserti128 ymm3, ymm2, xmm0, 0x0
        
%endmacro

;; Constants
DBL_MAX                     EQU 0x7FEFFFFFFFFFFFFF  ;; Maximal value of double

;; Global uninitialized variables
section .bss
align 64
swarm   resb _PSO3DIM_STATIC_PARTICLES * _TPARTICLE3DIM_SIZE ;; Array of TParticle3Dim

;; Global variables
section .data
__CONST__1_0     dq -1.0
__CONST_1_0      dq  1.0
__COEFF_W        dq  0.5, 0.5, 0.5, 0.5
__COEFF_CP       dq  2.05, 2.05, 2.05, 2.05
__COEFF_CG       dq  2.05, 2.05, 2.05, 2.05

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
        sub rsp, 16                             ;; Space for best position
        push rcx                                ;; Save for checking if current iteration is the first one
        push rdi                                ;; Save function pointer
        push rdx                                ;; Save fitness function pointer
        
        %define best_pos_x   rbp - 8            ;; Defines for variables saved on stack
        %define best_pos_y   rbp - 16
        %define iter_counter rbp - 24
        %define function_ptr rbp - 32
        %define fitness_ptr  rbp - 40

        and rsp, -16                            ;; Align stack for called functions
        push r11
        push r12
        push r13
        push r14
        push r15
        push rbx
        ;; Stack frame end

        mov r12, rsi                            ;; Move bounds to callee saved register
        mov r13, rcx                            ;; Saving max iterations
        
        xor rbx, rbx
.swarm_init_loop:
        init_particle3dim swarm+rbx, qword[r12], qword[r12+8], qword[r12+16], qword[r12+24]
        add rbx, _TPARTICLE3DIM_SIZE
        cmp rbx, _TPARTICLE3DIM_SIZE*_PSO3DIM_STATIC_PARTICLES
        jb .swarm_init_loop                     ;; Initialize all particles

        mov r14, DBL_MAX                        ;; Holds best value
.max_iter_loop:
        xor r15, r15                            ;; Counter
.for_each_particle:
        movq xmm0, qword[swarm + r15 + _TPARTICLE3DIM_POSITION0]
        mov rax, [function_ptr]                 ;; Load function pointer into RAX
        movq xmm1, qword[swarm + r15 + _TPARTICLE3DIM_POSITION1]
        call rax
        movq rbx, xmm0                          ;; Save returned value, but keep as argument

        mov rax, [fitness_ptr]                          ;; Load fitness function
        movq xmm1, qword[swarm + r15 + _TPARTICLE3DIM_BEST_VAL]
        call rax
        cmp rax, 1                              ;; If true then set this as personal best
        je .personal_best
        ;; Fitness function check is before checking first iteration,
        ;; because that will happen only once and will fail all the other times
        cmp r13, [iter_counter]                 ;; Check if this is the first iteration
        jne .personal_best_end
.personal_best:
        mov qword[swarm + r15 + _TPARTICLE3DIM_BEST_VAL], rbx
        mov rax, qword[swarm + r15 + _TPARTICLE3DIM_POSITION0]
        mov rcx, qword[swarm + r15 + _TPARTICLE3DIM_POSITION1]
        mov qword[swarm + r15 + _TPARTICLE3DIM_BEST_POS0], rax
        mov qword[swarm + r15 + _TPARTICLE3DIM_BEST_POS1], rcx

        movq xmm0, rbx                          ;; Load function value
        mov rax, [fitness_ptr]                  ;; Load fitness function
        movq xmm1, r14                          ;; Load best value
        call rax
        cmp rax, 0                              ;; If true then set this as global best
        je .personal_best_end

        mov r14, rbx                            ;; Set best value to current value
        mov rax, qword[swarm + r15 + _TPARTICLE3DIM_POSITION0]
        mov rcx, qword[swarm + r15 + _TPARTICLE3DIM_POSITION1] 
        mov qword[best_pos_x], rax              ;; Set best position to current one
        mov qword[best_pos_y], rcx
.personal_best_end:

        add r15, _TPARTICLE3DIM_SIZE
        cmp r15, _TPARTICLE3DIM_SIZE * _PSO3DIM_STATIC_PARTICLES
        jne .for_each_particle

        xor r15, r15
        mov rax, qword[best_pos_x]		;; Get best x and y positions into registers (to speed up calculations)
        mov rcx, qword[best_pos_y]

        vbroadcastsd ymm11, qword[r12]          ;; Fill ymm registers with bounds for bound comparison
        vbroadcastsd ymm12, qword[r12+8]
        vbroadcastsd ymm13, qword[r12+16]
        vbroadcastsd ymm14, qword[r12+24]
        vbroadcastsd ymm5, qword[best_pos_x]   ;; Fill ymm with best positions
        vbroadcastsd ymm6, qword[best_pos_y]
.particle_update:
	update_particle3dim swarm+r15, qword[r12], qword[r12+8], qword[r12+16], qword[r12+24], rax, rcx

        add r15, _TPARTICLE3DIM_SIZE * 4
        cmp r15, _TPARTICLE3DIM_SIZE * _PSO3DIM_STATIC_PARTICLES
        jne .particle_update

        dec r13
        jnz .max_iter_loop                      ;; CMP is left out because dec sets zero flag

.end:
        movq xmm0, qword[best_pos_x]
        movq xmm1, qword[best_pos_y]
        ;; Leaving function
        pop rbx
        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        mov rsp, rbp
        pop rbp
        ret
;; end pso3dim_static
