/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 *
 *
 * Derived from OpenBSD lib/libutil/pkcs5_pbkdf2.c. The original
 * implementation is documented at:
 * https://github.com/openbsd/src/blob/master/lib/libutil/pkcs5_pbkdf2.c
 */

/*-
 * Copyright (c) 2008 Damien Bergamini <damien.bergamini@free.fr>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "os_port.h"
#include "crypto.h"
#include "axtls_pbkdf2.h"

static void pbkdf2_zero(void *buffer, size_t length)
{
    volatile uint8_t *bytes = (volatile uint8_t *)buffer;
    while (length--)
        *bytes++ = 0;
}

static void pbkdf2_fail(uint8_t *output, size_t output_len)
{
    if (!output || output_len == 0)
        return;
    if (output_len <= INT_MAX && get_random((int)output_len, output) == 0)
        return;
    pbkdf2_zero(output, output_len);
}

int axtls_pbkdf2_sha1(const uint8_t *password, size_t password_len,
    const uint8_t *salt, size_t salt_len, uint8_t *output,
    size_t output_len, uint32_t rounds)
{
    uint8_t *salt_block = NULL;
    uint8_t digest[SHA1_SIZE], next[SHA1_SIZE], block_digest[SHA1_SIZE];
    uint32_t block = 1;
    size_t remaining = output_len, take;
    uint32_t iteration;
    int result = -1;

    if (!output || output_len == 0 || !salt || salt_len == 0 || rounds == 0 ||
        (password_len && !password) || password_len > INT_MAX ||
        salt_len > (size_t)INT_MAX - 4 || salt_len > SIZE_MAX - 4 ||
        output_len / SHA1_SIZE > UINT32_MAX ||
        (output_len / SHA1_SIZE == UINT32_MAX && output_len % SHA1_SIZE))
        goto cleanup;
    salt_block = malloc(salt_len + 4);
    if (!salt_block)
        goto cleanup;
    memcpy(salt_block, salt, salt_len);
    while (remaining) {
        salt_block[salt_len] = (uint8_t)(block >> 24);
        salt_block[salt_len + 1] = (uint8_t)(block >> 16);
        salt_block[salt_len + 2] = (uint8_t)(block >> 8);
        salt_block[salt_len + 3] = (uint8_t)block;
        hmac_sha1(salt_block, (int)(salt_len + 4), password,
            (int)password_len, digest);
        memcpy(block_digest, digest, sizeof(block_digest));
        for (iteration = 1; iteration < rounds; iteration++) {
            hmac_sha1(digest, sizeof(digest), password, (int)password_len, next);
            memcpy(digest, next, sizeof(digest));
            for (take = 0; take < sizeof(block_digest); take++)
                block_digest[take] ^= digest[take];
        }
        take = remaining < sizeof(block_digest) ? remaining : sizeof(block_digest);
        memcpy(output, block_digest, take);
        output += take;
        remaining -= take;
        if (remaining)
            block++;
    }
    result = 0;
cleanup:
    if (salt_block) {
        pbkdf2_zero(salt_block, salt_len + 4);
        free(salt_block);
    }
    pbkdf2_zero(digest, sizeof(digest));
    pbkdf2_zero(next, sizeof(next));
    pbkdf2_zero(block_digest, sizeof(block_digest));
    if (result)
        pbkdf2_fail(output, remaining);
    return result;
}
