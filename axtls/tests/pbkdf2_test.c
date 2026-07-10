#include <stdio.h>
#include <string.h>

#include "axtls_pbkdf2.h"
#include "crypto.h"

static int hex_equals(const uint8_t *actual, const char *expected)
{
    static const char hex[] = "0123456789abcdef";
    size_t i;
    for (i = 0; expected[i * 2]; i++)
        if (hex[actual[i] >> 4] != expected[i * 2] ||
            hex[actual[i] & 15] != expected[i * 2 + 1])
            return 0;
    return 1;
}

int main(void)
{
    uint8_t key[20];
    uint8_t long_key[80];
    uint8_t digest[SHA1_SIZE];
    memset(long_key, 0xaa, sizeof(long_key));
    hmac_sha1((const uint8_t *)"Test Using Larger Than Block-Size Key - Hash Key First", 54,
        long_key, sizeof(long_key), digest);
    if (!hex_equals(digest, "aa4ae5e15272d00e95705637ce8a3b55ed402112")) {
        fprintf(stderr, "HMAC-SHA1 long-key vector failed\n");
        return 1;
    }
    if (axtls_pbkdf2_sha1((const uint8_t *)"password", 8,
            (const uint8_t *)"salt", 4, key, sizeof(key), 1) ||
        !hex_equals(key, "0c60c80f961f0e71f3a9b524af6012062fe037a6")) {
        fprintf(stderr, "PBKDF2 RFC6070 iteration 1 failed\n");
        return 1;
    }
    if (axtls_pbkdf2_sha1((const uint8_t *)"password", 8,
            (const uint8_t *)"salt", 4, key, sizeof(key), 2) ||
        !hex_equals(key, "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957")) {
        fprintf(stderr, "PBKDF2 RFC6070 iteration 2 failed\n");
        return 1;
    }
    return 0;
}
