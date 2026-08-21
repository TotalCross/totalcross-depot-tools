/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */
#include <SDL2/SDL.h>

int main(void) {
  SDL_version version;
  SDL_GetVersion(&version);
  return version.major == 2 ? 0 : 1;
}
