/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */

#include "include/gpu/GrDirectContext.h"

int main() {
    auto context = GrDirectContext::MakeMetal(nullptr, nullptr);
    return context ? 0 : 1;
}
