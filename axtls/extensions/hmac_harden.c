/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 *
 *
 * The upstream axTLS hmac.c is compiled below with its SHA-1 entry point
 * renamed. This preserves the upstream MD5 and SHA-256 implementations while
 * replacing only SHA-1 with the RFC 2104 long-key handling used by OpenBSD.
 */

#define hmac_sha1 axtls_hmac_sha1_legacy
#include "hmac.c"
#undef hmac_sha1

void hmac_sha1(const uint8_t *msg, int length, const uint8_t *key,
        int key_len, uint8_t *digest)
{
    SHA1_CTX context;
    uint8_t ipad[64];
    uint8_t opad[64];
    uint8_t key_digest[SHA1_SIZE];
    int i;

    if (!digest || length < 0 || key_len < 0 ||
            (length > 0 && !msg) || (key_len > 0 && !key))
    {
        if (digest)
            memset(digest, 0, SHA1_SIZE);
        return;
    }
    if (key_len > (int)sizeof(ipad))
    {
        SHA1_Init(&context);
        SHA1_Update(&context, key, key_len);
        SHA1_Final(key_digest, &context);
        key = key_digest;
        key_len = SHA1_SIZE;
    }
    memset(ipad, 0, sizeof(ipad));
    memset(opad, 0, sizeof(opad));
    memcpy(ipad, key, key_len);
    memcpy(opad, key, key_len);
    for (i = 0; i < (int)sizeof(ipad); i++)
    {
        ipad[i] ^= 0x36;
        opad[i] ^= 0x5c;
    }
    SHA1_Init(&context);
    SHA1_Update(&context, ipad, sizeof(ipad));
    SHA1_Update(&context, msg, length);
    SHA1_Final(digest, &context);
    SHA1_Init(&context);
    SHA1_Update(&context, opad, sizeof(opad));
    SHA1_Update(&context, digest, SHA1_SIZE);
    SHA1_Final(digest, &context);
    memset(key_digest, 0, sizeof(key_digest));
    memset(ipad, 0, sizeof(ipad));
    memset(opad, 0, sizeof(opad));
}
