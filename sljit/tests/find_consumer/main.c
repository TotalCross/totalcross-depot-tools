/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */
#include <stdio.h>

#include <sljitLir.h>

typedef sljit_sw (*sljit_identity_fn)(sljit_sw);

int main(void)
{
  struct sljit_compiler *compiler = sljit_create_compiler(NULL);
  void *code;
  sljit_identity_fn identity;
  sljit_sw result;

  if (compiler == NULL ||
      sljit_emit_enter(compiler, 0, SLJIT_ARGS1(W, W), 1, 1, 0) != SLJIT_SUCCESS ||
      sljit_emit_return(compiler, SLJIT_MOV, SLJIT_S0, 0) != SLJIT_SUCCESS) {
    fprintf(stderr, "[FAIL] SLJIT consumer emitter\n");
    if (compiler != NULL)
      sljit_free_compiler(compiler);
    return 1;
  }
  code = sljit_generate_code(compiler, 0, NULL);
  if (code == NULL) {
    sljit_free_compiler(compiler);
    fprintf(stderr, "[FAIL] SLJIT consumer code generation\n");
    return 1;
  }
  identity = (sljit_identity_fn)code;
  result = identity(42);
  sljit_free_code(code, NULL);
  sljit_free_compiler(compiler);
  if (result != 42) {
    fprintf(stderr, "[FAIL] SLJIT consumer returned %ld\n", (long)result);
    return 1;
  }
  puts("[PASS] SLJIT find consumer generated identity(42) = 42");
  return 0;
}
