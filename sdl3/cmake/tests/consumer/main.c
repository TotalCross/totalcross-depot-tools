/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */
#include <SDL3/SDL.h>

int main(void) {
  return SDL_GetVersion() >= SDL_VERSIONNUM(3, 4, 16) ? 0 : 1;
}
