/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 *
 *
 * PBKDF2-HMAC-SHA1 derived from OpenBSD lib/libutil/pkcs5_pbkdf2.c.
 * Source: https://github.com/openbsd/src/blob/master/lib/libutil/pkcs5_pbkdf2.c
 */
#ifndef AXTLS_PBKDF2_H
#define AXTLS_PBKDF2_H

#include <stddef.h>
#include <stdint.h>

int axtls_pbkdf2_sha1(const uint8_t *password, size_t password_len,
    const uint8_t *salt, size_t salt_len, uint8_t *output,
    size_t output_len, uint32_t rounds);

#endif
