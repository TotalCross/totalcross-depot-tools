/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */

#include <zlib.h>

int main(void) {
  return zlibVersion()[0] == '\0';
}
