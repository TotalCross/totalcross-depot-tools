/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */
#include <stdint.h>
#include "qrcode.h"

int main(void) {
  QRCode qr;
  uint8_t modules[512];
  if (qrcode_initText(&qr, modules, 1, ECC_MEDIUM, "TotalCross") != 0)
    return 1;
  if (qr.size < 21)
    return 2;
  return qrcode_getModule(&qr, 0, 0) ? 0 : 3;
}
