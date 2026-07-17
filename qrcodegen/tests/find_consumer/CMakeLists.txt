# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.16)
project(qrcodegen-find-consumer LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
find_package(QRCodeGen REQUIRED)
add_executable(qrcodegen-find-consumer main.c)
target_link_libraries(qrcodegen-find-consumer PRIVATE QRCodeGen::QRCodeGen)
