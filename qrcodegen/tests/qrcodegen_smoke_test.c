/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */
#include <stdint.h>
#include "qrcodegen.h"

int main(void) {
  uint8_t temp[qrcodegen_BUFFER_LEN_MAX];
  uint8_t qr[qrcodegen_BUFFER_LEN_MAX];
  if (!qrcodegen_encodeText("TotalCross", temp, qr, qrcodegen_Ecc_MEDIUM,
      qrcodegen_VERSION_MIN, qrcodegen_VERSION_MAX, qrcodegen_Mask_AUTO, true))
    return 1;
  if (qrcodegen_getSize(qr) < 21)
    return 2;
  return qrcodegen_getModule(qr, 0, 0) ? 0 : 3;
}
