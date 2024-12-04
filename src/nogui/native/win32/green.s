.intel_syntax noprefix

# wine/dlls/winecrt0/setjmp.c
# This is only for Windows x64
# rax -> return value
# rcx -> argument #1
# rdx -> argument #2
# r8  -> argument #3
.global win32_green_setctx
.global win32_green_jumpctx
.global win32_green_callctx

win32_green_callctx:
  mov rsp, rdx  # change stack
  sub rsp, 32   # reserve 32 bytes
  mov rdx, rcx  # call function
  mov rcx, r8
  call rdx      
  ret

win32_green_setctx:
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

win32_green_jumpctx:
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
