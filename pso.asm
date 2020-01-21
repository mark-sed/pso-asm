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
global swarm

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
%endmacro

;; UPDATE_PARTICLE3DIM
;; Update velocity and position of a particle based on best global best position found
;; Minimal X bound should be broadcasted into ymm11, maximal X into ymm12, minimal Y into ymm13, maxmial Y into ymm14
;; @param
;;      1 Current particle struct address 
%macro update_particle3dim 1
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

        vbroadcastsd ymm5, qword[best_pos_x]   ;; Fill ymm with best positions
        vbroadcastsd ymm6, qword[best_pos_y]

        vmulpd ymm0, ymm9, [__COEFF_CP]        ;; Multiply random numbers by CP
        vmulpd ymm1, ymm8, [__COEFF_CG]        ;; Multiply random numbers by CG

        ;; Load x velocity to ymm registers
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_VELOCITY0], 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE], 0x1
        vinserti128 ymm2, ymm10, xmm0, 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*2], 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*3], 0x1
        vinserti128 ymm3, ymm2, xmm0, 0x1

        ;; Load y velocity to ymm registers
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_VELOCITY1], 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE], 0x1
        vinserti128 ymm2, ymm10, xmm0, 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE*2], 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE*3], 0x1
        vinserti128 ymm4, ymm2, xmm0, 0x1

        ;; Load x position to ymm registers
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_POSITION0], 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE], 0x1
        vinserti128 ymm2, ymm10, xmm0, 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE*2], 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE*3], 0x1
        vinserti128 ymm7, ymm2, xmm0, 0x1

        ;; Load y position to ymm registers
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_POSITION1], 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE], 0x1
        vinserti128 ymm2, ymm10, xmm0, 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE*2], 0x0
        vpinsrq xmm0, qword[%1+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE*3], 0x1
        vinserti128 ymm8, ymm2, xmm0, 0x1
        
        vsubpd ymm5, ymm5, ymm7                 ;; Subtract best x position and x position
        vsubpd ymm6, ymm6, ymm8                 ;; Subtract best y position and y position

        vmulpd ymm3, ymm3, [__COEFF_W]          ;; Multiply velocity by CW
        vmulpd ymm4, ymm4, [__COEFF_W]

        vmovapd ymm9, ymm5                      ;; Copy position differences
        vmovapd ymm10, ymm6

        vmulpd ymm5, ymm5, ymm0                 ;; Multiply random value with position difference
        vmulpd ymm6, ymm6, ymm1
        vmulpd ymm10, ymm10, ymm0
        vmulpd ymm9, ymm9, ymm1
        
        vaddpd ymm3, ymm3, ymm5                 ;; Add velocity * CW to pos_diff
        vaddpd ymm4, ymm4, ymm6
        vaddpd ymm3, ymm3, ymm9                 ;; Add random * pos_diff to it
        vaddpd ymm4, ymm4, ymm10

        vaddpd ymm7, ymm7, ymm3                 ;; Add velocity to x position
        vaddpd ymm8, ymm8, ymm4                 ;; Add velocity to y position

        ;; Checking bounds (unordered non-signaling)
        vcmppd ymm0, ymm7, ymm11, 0x19          ;; !(ymm7 >= ymm11)
        vcmppd ymm1, ymm7, ymm11, 0x15          ;; !(ymm7 < ymm11)
        adjust_pos ymm7, ymm0, ymm1, ymm11      ;; Adjust position based on bounds

        vcmppd ymm0, ymm7, ymm12, 0x1e          ;; ymm7 > ymm12
        vcmppd ymm1, ymm7, ymm12, 0x1a          ;; !(ymm7 > ymm12)
        adjust_pos ymm7, ymm0, ymm1, ymm12

        vcmppd ymm0, ymm8, ymm13, 0x19          
        vcmppd ymm1, ymm8, ymm13, 0x15          
        adjust_pos ymm8, ymm0, ymm1, ymm13      

        vcmppd ymm0, ymm8, ymm14, 0x1e          
        vcmppd ymm1, ymm8, ymm14, 0x1a          
        adjust_pos ymm8, ymm0, ymm1, ymm14

        ;; Update positional values
        vextracti128 xmm0, ymm7, 0x0            ;; Extract values from ymm into xmm0 and xmm1
        vextracti128 xmm1, ymm7, 0x1
        vpextrq qword[%1+r15+_TPARTICLE3DIM_POSITION0], xmm0, 0x0 ;; Save new position into particle
        vpextrq qword[%1+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE], xmm0, 0x1
        vpextrq qword[%1+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE*2], xmm1, 0x0 
        vpextrq qword[%1+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE*3], xmm1, 0x1

        vextracti128 xmm0, ymm8, 0x0            
        vextracti128 xmm1, ymm8, 0x1
        vpextrq qword[%1+r15+_TPARTICLE3DIM_POSITION1], xmm0, 0x0
        vpextrq qword[%1+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE], xmm0, 0x1
        vpextrq qword[%1+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE*2], xmm1, 0x0 
        vpextrq qword[%1+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE*3], xmm1, 0x1

        ;; Update velocity values
        vextracti128 xmm0, ymm3, 0x0            
        vextracti128 xmm1, ymm3, 0x1
        vpextrq qword[%1+r15+_TPARTICLE3DIM_VELOCITY0], xmm0, 0x0 
        vpextrq qword[%1+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE], xmm0, 0x1
        vpextrq qword[%1+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*2], xmm1, 0x0 
        vpextrq qword[%1+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*3], xmm1, 0x1

        vextracti128 xmm0, ymm4, 0x0            
        vextracti128 xmm1, ymm4, 0x1
        vpextrq qword[%1+r15+_TPARTICLE3DIM_VELOCITY1], xmm0, 0x0
        vpextrq qword[%1+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE], xmm0, 0x1
        vpextrq qword[%1+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE*2], xmm1, 0x0 
        vpextrq qword[%1+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE*3], xmm1, 0x1
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
__TEST_VAL       dq  -60.0, 2.0, 3.0, 87.0

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
.particle_update:
	;update_particle3dim swarm+r15

        rnd2rax [__CONST_1_0]                   ;; Generate random double <0, 1>
        vpinsrq xmm8, rax, 0x0
        rnd2rax [__CONST_1_0]                        
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm10, ymm3, xmm8, 0x1      ;; Move 2 doubles from xmm2 to upper half of ymm10

        rnd2rax [__CONST_1_0]
        vpinsrq xmm8, rax, 0x0
        rnd2rax [__CONST_1_0]
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm9, ymm10, xmm8, 0x0     ;; Move 2 doubles from xmm2 to lower half of ymm9

        ;; Filling ymm1 with 4 random doubles
        rnd2rax [__CONST_1_0]                   ;; Generate random double <0, 1>
        vpinsrq xmm8, rax, 0x0
        rnd2rax [__CONST_1_0]                        
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm5, ymm3, xmm8, 0x1      ;; Move 2 doubles from xmm2 to upper half of ymm5

        rnd2rax [__CONST_1_0]
        vpinsrq xmm8, rax, 0x0
        rnd2rax [__CONST_1_0]
        vpinsrq xmm8, rax, 0x1
        vinserti128 ymm1, ymm5, xmm8, 0x0     ;; Move 2 doubles from xmm2 to lower half of ymm1

        vmulpd ymm0, ymm9, [__COEFF_CP]        ;; Multiply random numbers by CP into ymm0
        vmulpd ymm1, ymm1, [__COEFF_CG]        ;; Multiply random numbers by CG into ymm1

        vbroadcastsd ymm5, qword[best_pos_x]   ;; Fill ymm with best positions
        vbroadcastsd ymm6, qword[best_pos_y]

        ;; Load x velocity to ymm registers
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0], 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE], 0x0
        vinserti128 ymm2, ymm10, xmm15, 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*2], 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*3], 0x0
        vinserti128 ymm3, ymm2, xmm15, 0x0

        ;; Load y velocity to ymm registers
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY1], 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE], 0x0
        vinserti128 ymm2, ymm10, xmm15, 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE*2], 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE*3], 0x0
        vinserti128 ymm4, ymm2, xmm15, 0x0

        ;; Load x position to ymm registers
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_POSITION0], 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE], 0x0
        vinserti128 ymm2, ymm10, xmm15, 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE*2], 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE*3], 0x0
        vinserti128 ymm7, ymm2, xmm15, 0x0

        ;; Load y position to ymm registers
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_POSITION1], 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE], 0x0
        vinserti128 ymm2, ymm10, xmm15, 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE*2], 0x1
        vpinsrq xmm15, qword[swarm+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE*3], 0x0
        vinserti128 ymm8, ymm2, xmm15, 0x0
        
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
        vextracti128 xmm0, ymm7, 0x0            ;; Extract values from ymm into xmm0 and xmm1
        vextracti128 xmm1, ymm7, 0x1
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_POSITION0], xmm1, 0x1 ;; Save new position into particle
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE], xmm1, 0x0
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE*2], xmm0, 0x1 
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_POSITION0+_TPARTICLE3DIM_SIZE*3], xmm0, 0x0

        vextracti128 xmm0, ymm8, 0x0            
        vextracti128 xmm1, ymm8, 0x1
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_POSITION1], xmm1, 0x1
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE], xmm1, 0x0
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE*2], xmm0, 0x1 
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_POSITION1+_TPARTICLE3DIM_SIZE*3], xmm0, 0x0

        ;; Update velocity values
        vextracti128 xmm0, ymm3, 0x0            
        vextracti128 xmm1, ymm3, 0x1
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0], xmm1, 0x1 
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE], xmm1, 0x0
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*2], xmm0, 0x1 
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_VELOCITY0+_TPARTICLE3DIM_SIZE*3], xmm0, 0x0

        vextracti128 xmm0, ymm4, 0x0            
        vextracti128 xmm1, ymm4, 0x1
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_VELOCITY1], xmm1, 0x1
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE], xmm1, 0x0
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE*2], xmm0, 0x1 
        vpextrq qword[swarm+r15+_TPARTICLE3DIM_VELOCITY1+_TPARTICLE3DIM_SIZE*3], xmm0, 0x0

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
