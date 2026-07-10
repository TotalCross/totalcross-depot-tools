#include <stdint.h>
#include "qrcodegen.h"

int main(void) {
  uint8_t temp[qrcodegen_BUFFER_LEN_MAX];
  uint8_t qr[qrcodegen_BUFFER_LEN_MAX];
  return qrcodegen_encodeText("TC", temp, qr, qrcodegen_Ecc_LOW, 1, 40,
    qrcodegen_Mask_AUTO, true) ? 0 : 1;
}
