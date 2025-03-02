.global green_setctx
.global green_jumpctx
.global green_callctx

# musl/src/setjmp/x86_64
# musl/src/setjmp/aarch64
# System-V Calling Convention
#if defined(__unix__)
  #if defined(__x86_64__)
  .intel_syntax noprefix

  green_callctx:
    mov rsp, rdx  # change stack
    sub rsp, 128  # reserve 128 bytes
    mov rdx, rdi  # call function
    mov rdi, rsi
    call rdx
    ret

  green_setctx:
    mov [rdi + 0], rbx
    mov [rdi + 8], rbp
    mov [rdi + 16], r12
    mov [rdi + 24], r13
    mov [rdi + 32], r14
    mov [rdi + 40], r15
    # Pointer Stack Store
    lea rdx, [rsp + 8]   # <- stack pointer
    mov [rdi + 48], rdx
    mov rdx, [rsp]       # <- return address
    mov [rdi + 56], rdx
    xor eax, eax
    ret

  green_jumpctx:
    mov rax, rsi
    mov rbx, [rdi + 0]
    mov rbp, [rdi + 8]
    mov r12, [rdi + 16]
    mov r13, [rdi + 24]
    mov r14, [rdi + 32]
    mov r15, [rdi + 40]
    # Pointer Stack Restore
    mov rsp, [rdi + 48] # <- stack pointer
    mov rdx, [rdi + 56] # <- return address
    jmp rdx

  # AArch64 Calling Convention
  #elif defined(__aarch64__)

  green_callctx:
    sub x2, x2, 128
    mov sp, x2
    mov x2, x0
    mov x0, x1
    br x2

  green_setctx:
    stp x19, x20, [x0,#0]
    stp x21, x22, [x0,#16]
    stp x23, x24, [x0,#32]
    stp x25, x26, [x0,#48]
    stp x27, x28, [x0,#64]
    stp x29, x30, [x0,#80]
    mov x2, sp
    str x2, [x0,#104]
    stp  d8,  d9, [x0,#112]
    stp d10, d11, [x0,#128]
    stp d12, d13, [x0,#144]
    stp d14, d15, [x0,#160]
    mov x0, #0
    ret

  green_jumpctx:
    ldp x19, x20, [x0,#0]
    ldp x21, x22, [x0,#16]
    ldp x23, x24, [x0,#32]
    ldp x25, x26, [x0,#48]
    ldp x27, x28, [x0,#64]
    ldp x29, x30, [x0,#80]
    ldr x2, [x0,#104]
    mov sp, x2
    ldp d8 , d9, [x0,#112]
    ldp d10, d11, [x0,#128]
    ldp d12, d13, [x0,#144]
    ldp d14, d15, [x0,#160]
    mov x0, x1
    br x30

  #else
    #error "Your CPU is not supported"
  #endif

# wine/dlls/winecrt0/setjmp.c
# Windows x64 Calling Convention
# rax -> return value
# rcx -> argument #1
# rdx -> argument #2
# r8  -> argument #3
#elif defined(WIN32) || defined(_WIN32)
  .intel_syntax noprefix
  #if defined(__aarch64__)
    #error "Windows ARM is not supported"
  #elif !defined(__x86_64__)
    #error "Windows i386 is not supported"
  #endif

green_callctx:
  mov rsp, r8   # change stack
  sub rsp, 32   # reserve 32 bytes
  mov r8, rcx   # call function
  mov rcx, rdx
  call r8
  ret

green_setctx:
  mov [rcx + 0x00], rdx
  mov [rcx + 0x08], rbx
  lea rax, [rsp + 0x08]
  mov [rcx + 0x10], rax
  mov [rcx + 0x18], rbp
  mov [rcx + 0x20], rsi
  mov [rcx + 0x28], rdi
  mov [rcx + 0x30], r12
  mov [rcx + 0x38], r13
  mov [rcx + 0x40], r14
  mov [rcx + 0x48], r15
  mov rax, [rsp + 0x00]
  mov [rcx + 0x50], rax
  stmxcsr [rcx + 0x58]
  fnstcw [rcx + 0x5c]
  # store simd instructions
  movdqa [rcx + 0x60], xmm6
  movdqa [rcx + 0x70], xmm7
  movdqa [rcx + 0x80], xmm8
  movdqa [rcx + 0x90], xmm9
  movdqa [rcx + 0xa0], xmm10
  movdqa [rcx + 0xb0], xmm11
  movdqa [rcx + 0xc0], xmm12
  movdqa [rcx + 0xd0], xmm13
  movdqa [rcx + 0xe0], xmm14
  movdqa [rcx + 0xf0], xmm15
  # return nothing
  xor rax, rax
  ret

green_jumpctx:
  mov rax, rdx
  mov rbx, [rcx + 0x08]
  mov rbp, [rcx + 0x18]
  mov rsi, [rcx + 0x20]
  mov rdi, [rcx + 0x28]
  mov r12, [rcx + 0x30]
  mov r13, [rcx + 0x38]
  mov r14, [rcx + 0x40]
  mov r15, [rcx + 0x48]
  ldmxcsr [rcx + 0x58]
  fnclex
  fldcw [rcx + 0x5C]
  # restore simd instructions
  movdqa xmm6, [rcx + 0x60]
  movdqa xmm7, [rcx + 0x70]
  movdqa xmm8, [rcx + 0x80]
  movdqa xmm9, [rcx + 0x90]
  movdqa xmm10, [rcx + 0xa0]
  movdqa xmm11, [rcx + 0xb0]
  movdqa xmm12, [rcx + 0xc0]
  movdqa xmm13, [rcx + 0xd0]
  movdqa xmm14, [rcx + 0xe0]
  movdqa xmm15, [rcx + 0xf0]
  # return to setjmp call
  mov rdx, [rcx + 0x50]
  mov rsp, [rcx + 0x10]
  jmp rdx

#else
  #error "Your OS is not supported"
#endif
