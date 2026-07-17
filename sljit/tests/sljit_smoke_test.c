/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */
#include <stdio.h>

#include <sljitLir.h>

#if SLJIT_WX_EXECUTABLE_ALLOCATOR != 1
#error "The smoke test requires the W^X executable allocator"
#endif
#if SLJIT_PROT_EXECUTABLE_ALLOCATOR != 0
#error "The dual-map executable allocator must be disabled"
#endif
#if SLJIT_SINGLE_THREADED != 0
#error "The distributed library must retain multithreaded support"
#endif

typedef sljit_sw (*sljit_add3_fn)(sljit_sw, sljit_sw, sljit_sw);

int main(void)
{
  struct sljit_compiler *compiler = sljit_create_compiler(NULL);
  void *code;
  sljit_add3_fn add3;
  sljit_sw result;

  if (compiler == NULL) {
    fprintf(stderr, "[FAIL] sljit_create_compiler\n");
    return 1;
  }
  if (sljit_emit_enter(compiler, 0, SLJIT_ARGS3(W, W, W, W), 1, 3, 0) != SLJIT_SUCCESS ||
      sljit_emit_op2(compiler, SLJIT_ADD, SLJIT_R0, 0, SLJIT_S0, 0, SLJIT_S1, 0) != SLJIT_SUCCESS ||
      sljit_emit_op2(compiler, SLJIT_ADD, SLJIT_R0, 0, SLJIT_R0, 0, SLJIT_S2, 0) != SLJIT_SUCCESS ||
      sljit_emit_return(compiler, SLJIT_MOV, SLJIT_R0, 0) != SLJIT_SUCCESS) {
    fprintf(stderr, "[FAIL] SLJIT emitter\n");
    sljit_free_compiler(compiler);
    return 1;
  }
  code = sljit_generate_code(compiler, 0, NULL);
  if (code == NULL) {
    fprintf(stderr, "[FAIL] sljit_generate_code\n");
    sljit_free_compiler(compiler);
    return 1;
  }
  add3 = (sljit_add3_fn)code;
  result = add3(4, 5, 6);
  sljit_free_code(code, NULL);
  sljit_free_compiler(compiler);
  if (result != 15) {
    fprintf(stderr, "[FAIL] SLJIT generated add3 returned %ld\n", (long)result);
    return 1;
  }
  puts("[PASS] SLJIT generated add3(4, 5, 6) = 15");
  return 0;
}
