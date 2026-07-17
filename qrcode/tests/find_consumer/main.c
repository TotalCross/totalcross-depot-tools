/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */
#include <stdint.h>
#include "qrcode.h"

int main(void) {
  QRCode qr;
  uint8_t modules[512];
  return qrcode_initText(&qr, modules, 1, ECC_LOW, "TC");
}
