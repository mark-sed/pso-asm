;; Particle swarm algorithm module. 
;;
;; Compiler used: NASM version 2.13
;; Made for: 64-bit Linux with C caling convention
;;
;; @file pso.asm
;; @author Marek Sedlacek (xsedla1b)
;; @date March 2020
;; @email xsedla1b@fit.vutbr.cz 
;;        mr.mareksedlacek@gmail.com
;;

;; Exported functions
global pso3dim_static           ;; PSO algorithm for 3 dimensional function (does not use heap)
global fitness_less_than        ;; Fitness function (less than)
global fitness_greater_than     ;; Fitness function (greater than)
global seed

;; Macros
%define _PSO3DIM_STATIC_PARTICLES 40            ;; How many particles will be used in pso3dim_static function

;; typedef struct {
;;    double velocity[2];  //< Velocity for each dimension
;;    double position[2];  //< Position in each dimension
;;    double best_pos[2];  //< Best position
;;    double best_val;     //< Value of the best position
;; } TParticle3Dim;
%define _TPARTICLE3DIM_VELOCITY0 0              ;; Offsets of elements in particle struct
%define _TPARTICLE3DIM_VELOCITY1 1 * 8 * _PSO3DIM_STATIC_PARTICLES                 
%define _TPARTICLE3DIM_POSITION0 2 * 8 * _PSO3DIM_STATIC_PARTICLES                 
%define _TPARTICLE3DIM_POSITION1 3 * 8 * _PSO3DIM_STATIC_PARTICLES
%define _TPARTICLE3DIM_BEST_POS0 4 * 8 * _PSO3DIM_STATIC_PARTICLES
%define _TPARTICLE3DIM_BEST_POS1 5 * 8 * _PSO3DIM_STATIC_PARTICLES
%define _TPARTICLE3DIM_BEST_VAL  6 * 8 * _PSO3DIM_STATIC_PARTICLES

;; Function macros

;; RND2RAX 
;; Saves random value to rax
%macro rnd2rax 0
        mul rbx
        and rax, r11
        inc rax
        cvtsi2sd xmm0, rax
        divsd xmm0, xmm1
        movq rax, xmm0                          ;; Save random value to rax
%endmacro ;; rnd2rax

;; ADJUST_POS 
;; Adjust positions to bounds
;; @param
;;      1 Position
;;      2 Comparison mask
;;      3 Inverted comparison mask
;;      4 Bounds
%macro adjust_pos 4
        vandpd %1, %2, %1
        vandpd %3, %3, %4
        vaddpd %1, %3, %1
%endmacro ;; adjust_pos

;; Constants
DBL_MAX         EQU 0x7FEFFFFFFFFFFFFF          ;; Maximal value of double

;; Global uninitialized variables
section .bss
align 64
swarm    resb _PSO3DIM_STATIC_PARTICLES * 7 * 8 ;; Array of TParticle3Dim

;; Global variables
section .data
__CONST__1_0     dq -1.0
__CONST_1_0      dq  1.0
__CONST_2_0      dq  2.0
__COEFF_W        dq  0.5, 0.5, 0.5, 0.5
__COEFF_CP       dq  2.05, 2.05, 2.05, 2.05
__COEFF_CG       dq  2.05, 2.05, 2.05, 2.05
__TEST_VAL       dq -60.0, 2.0, 3.0, 87.0
seed             dq  123453443242342            ;; Starting value of pseudo-random generator
__RND_CONST      dq  69069                      ;; Random number multiplier
__ULONG_MAX_DBL  dq  9223372036854775808.0      ;; Maximal value of long as double

;; Code
section .text

;; LESS_THAN 
;; Fitness function (xmm0 < xmm1)
;; @param
;;      xmm0 - first value
;;      xmm1 - second value
;; @return
;;      rax - if xmm0 < xmm1 then rax = -1; else 0; 
fitness_less_than:
        cmppd xmm0, xmm1, 0x11
        movq rax, xmm0
        ret

;; GREATER_THAN 
;; Fitness function (xmm0 > xmm1)
;; @param
;;      xmm0 - first value
;;      xmm1 - second value
;; @return
;;      rax - if xmm0 > xmm1 then rax = -1; else 0; 
fitness_greater_than:
        cmppd xmm0, xmm1, 0x1e
        movq rax, xmm0
        ret

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
        movsd xmm1, [__ULONG_MAX_DBL]           ;; Load xmms for init_particle3dim
        movsd xmm2, [__CONST__1_0]
        movsd xmm3, [__CONST_2_0]
        movsd xmm4, qword[r12]                  ;; min x
        movsd xmm5, qword[r12+8]
        subsd xmm5, xmm4                        ;; max x - min x
        movsd xmm6, qword[r12+16]               ;; min y
        movsd xmm7, qword[r12+24]
        subsd xmm7, xmm6                        ;; max y - min y
        mov rax, qword[seed]
        mov r14, qword[__RND_CONST] 
        mov r11, 0x7fffffffffffffff
        ;; For better pseudorandomness one generation should be done
        mul r14                                                          
        inc rax       
.swarm_init_loop:          
        mul r14                                 ;; seed * RND_CONST
        and rax, r11                            ;; remove possible overflow (negative value)
        inc rax                                 ;; seed * RND_CONST + 1
        cvtsi2sd xmm0, rax
        divsd xmm0, xmm1
        mulsd xmm0, xmm3                        ;; * 2
        addsd xmm0, xmm2                        ;; + -1                  
        movq qword[swarm+rbx+_TPARTICLE3DIM_VELOCITY0], xmm0 ;; Save generated value as velocity on X axis

        mul r14
        and rax, r11
        inc rax
        cvtsi2sd xmm0, rax
        divsd xmm0, xmm1
        mulsd xmm0, xmm3                        
        addsd xmm0, xmm2                                         
        movq qword[swarm+rbx+_TPARTICLE3DIM_VELOCITY1], xmm0 
        
        mul r14
        and rax, r11
        inc rax
        cvtsi2sd xmm0, rax
        divsd xmm0, xmm1
        mulsd xmm0, xmm5                        ;; rand() * (maxX-minX)
        addsd xmm0, xmm4                        ;; rand() * (maxX-minX) + minX
        movq qword[swarm+rbx+_TPARTICLE3DIM_POSITION0], xmm0
        movq qword[swarm+rbx+_TPARTICLE3DIM_BEST_POS0], xmm0

        mul r14
        and rax, r11
        inc rax
        cvtsi2sd xmm0, rax
        divsd xmm0, xmm1
        mulsd xmm0, xmm7                        ;; rand() * (maxY-minY)
        addsd xmm0, xmm6                        ;; rand() * (maxY-minY) + minY
        movq qword[swarm+rbx+_TPARTICLE3DIM_POSITION1], xmm0
        movq qword[swarm+rbx+_TPARTICLE3DIM_BEST_POS1], xmm0          

        add rbx, 8
        cmp rbx, 8*_PSO3DIM_STATIC_PARTICLES
        jb .swarm_init_loop                     ;; Initialize all particles

        mov qword[seed], rax                    ;; Save seed
        mov r14, DBL_MAX                        ;; Holds best value
.max_iter_loop:
        xor r15, r15                            ;; Counter
.for_each_particle:
        movq xmm0, qword[swarm + r15 + _TPARTICLE3DIM_POSITION0]
        mov rax, [function_ptr]                 ;; Load function pointer into RAX
        movq xmm1, qword[swarm + r15 + _TPARTICLE3DIM_POSITION1]
        call rax
        movq rbx, xmm0                          ;; Save returned value, but keep as argument

        mov rax, [fitness_ptr]                  ;; Load fitness function
        movq xmm1, qword[swarm + r15 + _TPARTICLE3DIM_BEST_VAL]
        call rax
        cmp rax, 0                              ;; If true then set this as personal best
        jne .personal_best
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
        add r15, 8
        cmp r15, 8 * _PSO3DIM_STATIC_PARTICLES
        jne .for_each_particle

        xor r15, r15
        mov rax, qword[best_pos_x]              ;; Get best x and y positions into registers (to speed up calculations)
        mov rcx, qword[best_pos_y]

        vbroadcastsd ymm11, qword[r12]          ;; Fill ymm registers with bounds for bound comparison
        vbroadcastsd ymm12, qword[r12+8]
        vbroadcastsd ymm13, qword[r12+16]
        vbroadcastsd ymm14, qword[r12+24]
        mov rax, qword[seed]
        mov r11, 0x7fffffffffffffff
        mov rbx, [__RND_CONST]
.particle_update:
        movsd xmm1, [__ULONG_MAX_DBL]

        rnd2rax                                 ;; Generate random double <0, 1>
        vpinsrq xmm8, rax, 0x0
        rnd2rax                        
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm10, ymm3, xmm8, 0x1      ;; Move 2 doubles from xmm2 to upper half of ymm10

        rnd2rax
        vpinsrq xmm8, rax, 0x0
        rnd2rax
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm9, ymm10, xmm8, 0x0      ;; Move 2 doubles from xmm2 to lower half of ymm9

        ;; Filling ymm1 with 4 random doubles
        rnd2rax                                 
        vpinsrq xmm8, rax, 0x0
        rnd2rax                       
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm5, ymm3, xmm8, 0x1       ;; Move 2 doubles from xmm2 to upper half of ymm5

        rnd2rax
        vpinsrq xmm8, rax, 0x0
        rnd2rax
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm1, ymm5, xmm8, 0x0       ;; Move 2 doubles from xmm2 to lower half of ymm1

        vmulpd ymm0, ymm9, [__COEFF_CP]         ;; Multiply random numbers by CP into ymm0
        vmulpd ymm1, ymm1, [__COEFF_CG]         ;; Multiply random numbers by CG into ymm1

        vbroadcastsd ymm5, qword[best_pos_x]    ;; Fill ymm with best positions
        vbroadcastsd ymm6, qword[best_pos_y]

        vmovupd ymm3, [swarm+r15+_TPARTICLE3DIM_VELOCITY0]
        vmovupd ymm4, [swarm+r15+_TPARTICLE3DIM_VELOCITY1]
        vmovupd ymm7, [swarm+r15+_TPARTICLE3DIM_POSITION0]
        vmovupd ymm8, [swarm+r15+_TPARTICLE3DIM_POSITION1]

        vsubpd ymm5, ymm5, ymm7                 ;; Subtract best x position and x position (pos_diff0)
        vsubpd ymm6, ymm6, ymm8                 ;; Subtract best y position and y position (pos_diff1)

        vmulpd ymm3, ymm3, [__COEFF_W]          ;; Multiply velocity by CW (p->velocity[0] * COEFF_W)
        vmulpd ymm4, ymm4, [__COEFF_W]          ;; (p->velocity[1] * COEFF_W)

        vmovapd ymm9, ymm5                      ;; Copy position differences
        vmovapd ymm10, ymm6

        vmulpd ymm5, ymm5, ymm0                 ;; Multiply random value with position difference (pos_diff0 * rp)
        vmulpd ymm6, ymm6, ymm1                 ;; (pos_diff1 * rg)
        vmulpd ymm10, ymm10, ymm0               ;; (pos_diff1 * rp)
        vmulpd ymm9, ymm9, ymm1                 ;; (pos_diff0 * rg)
        
        vaddpd ymm3, ymm3, ymm5                 ;; Add velocity * CW to pos_diff
        vaddpd ymm4, ymm4, ymm6
        vaddpd ymm3, ymm3, ymm9                 ;; Add random * pos_diff to it
        vaddpd ymm4, ymm4, ymm10

        vaddpd ymm7, ymm7, ymm3                 ;; Add velocity to x position
        vaddpd ymm8, ymm8, ymm4                 ;; Add velocity to y position

        ;; Checking bounds (ordered non-signaling)
        vcmppd ymm0, ymm7, ymm11, 0x1d          ;; ymm7 >= ymm11
        vcmppd ymm1, ymm7, ymm11, 0x11          ;; ymm7 < ymm11
        adjust_pos ymm7, ymm0, ymm1, ymm11      ;; Adjust position based on bounds

        vcmppd ymm0, ymm7, ymm12, 0x12          ;; ymm7 <= ymm12
        vcmppd ymm1, ymm7, ymm12, 0x1e          ;; ymm7 > ymm12
        adjust_pos ymm7, ymm0, ymm1, ymm12

        vcmppd ymm0, ymm8, ymm13, 0x1d          
        vcmppd ymm1, ymm8, ymm13, 0x11          
        adjust_pos ymm8, ymm0, ymm1, ymm13      

        vcmppd ymm0, ymm8, ymm14, 0x12          
        vcmppd ymm1, ymm8, ymm14, 0x1e          
        adjust_pos ymm8, ymm0, ymm1, ymm14

        ;; Update positional values
        vmovupd [swarm+r15+_TPARTICLE3DIM_POSITION0], ymm7
        vmovupd [swarm+r15+_TPARTICLE3DIM_POSITION1], ymm8

        ;; Update velocity values
        vmovupd [swarm+r15+_TPARTICLE3DIM_VELOCITY0], ymm3
        vmovupd [swarm+r15+_TPARTICLE3DIM_VELOCITY1], ymm4

        add r15, 8
        cmp r15, 8 * _PSO3DIM_STATIC_PARTICLES
        jne .particle_update
        mov qword[seed], rax

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
; end pso3dim_static
