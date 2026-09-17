/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */

#include <inttypes.h>
#include <png.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define PNG_SIGNATURE_SIZE 8U

static int decode_fixture(const char *path) {
  FILE *file = NULL;
  png_structp png_ptr = NULL;
  png_infop info_ptr = NULL;
  png_bytep *rows = NULL;
  png_uint_32 width = 0;
  png_uint_32 height = 0;
  int bit_depth = 0;
  int color_type = 0;
  int interlace_method = 0;
  int compression_method = 0;
  int filter_method = 0;
  int has_transparency = 0;
  size_t rowbytes = 0;
  size_t allocated_rows = 0;
  uint64_t checksum = UINT64_C(0);
  int status = EXIT_FAILURE;
  png_byte signature[PNG_SIGNATURE_SIZE];

  file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "cannot open PNG fixture: %s\n", path);
    goto cleanup;
  }

  if (fread(signature, 1, sizeof(signature), file) != sizeof(signature) ||
      png_sig_cmp(signature, 0, sizeof(signature)) != 0) {
    fprintf(stderr, "invalid PNG signature: %s\n", path);
    goto cleanup;
  }

  png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if (png_ptr == NULL) {
    fprintf(stderr, "cannot create libpng read state: %s\n", path);
    goto cleanup;
  }
  info_ptr = png_create_info_struct(png_ptr);
  if (info_ptr == NULL) {
    fprintf(stderr, "cannot create libpng image state: %s\n", path);
    goto cleanup;
  }

  if (setjmp(png_jmpbuf(png_ptr)) != 0) {
    fprintf(stderr, "libpng rejected PNG fixture: %s\n", path);
    goto cleanup;
  }

  png_init_io(png_ptr, file);
  png_set_sig_bytes(png_ptr, PNG_SIGNATURE_SIZE);
  png_read_info(png_ptr, info_ptr);

  width = png_get_image_width(png_ptr, info_ptr);
  height = png_get_image_height(png_ptr, info_ptr);
  bit_depth = png_get_bit_depth(png_ptr, info_ptr);
  color_type = png_get_color_type(png_ptr, info_ptr);
  png_get_IHDR(png_ptr, info_ptr, &width, &height, &bit_depth, &color_type,
               &interlace_method, &compression_method, &filter_method);
  if (width == 0 || height == 0 || bit_depth <= 0) {
    fprintf(stderr, "invalid PNG dimensions or bit depth: %s\n", path);
    goto cleanup;
  }

  has_transparency = png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS) != 0;
  if (color_type == PNG_COLOR_TYPE_PALETTE) {
    png_set_palette_to_rgb(png_ptr);
  }
  if (has_transparency) {
    png_set_tRNS_to_alpha(png_ptr);
  }
  if (color_type == PNG_COLOR_TYPE_GRAY ||
      color_type == PNG_COLOR_TYPE_GRAY_ALPHA) {
    png_set_gray_to_rgb(png_ptr);
  }
  if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8) {
    png_set_expand_gray_1_2_4_to_8(png_ptr);
  }
  if (bit_depth == 16) {
    png_set_strip_16(png_ptr);
  }
  if ((color_type & PNG_COLOR_MASK_ALPHA) == 0 && !has_transparency) {
    png_set_add_alpha(png_ptr, 0xff, PNG_FILLER_AFTER);
  }
  if (interlace_method != PNG_INTERLACE_NONE &&
      png_set_interlace_handling(png_ptr) <= 0) {
    fprintf(stderr, "cannot enable PNG interlace handling: %s\n", path);
    goto cleanup;
  }

  png_read_update_info(png_ptr, info_ptr);
  if (png_get_bit_depth(png_ptr, info_ptr) != 8 ||
      png_get_color_type(png_ptr, info_ptr) != PNG_COLOR_TYPE_RGB_ALPHA ||
      png_get_channels(png_ptr, info_ptr) != 4) {
    fprintf(stderr, "unsafe PNG normalization result: %s\n", path);
    goto cleanup;
  }

  if ((size_t)width > SIZE_MAX / 4U) {
    fprintf(stderr, "PNG row size overflows host size_t: %s\n", path);
    goto cleanup;
  }
  rowbytes = png_get_rowbytes(png_ptr, info_ptr);
  if (rowbytes != (size_t)width * 4U || rowbytes == 0) {
    fprintf(stderr, "unexpected PNG row size: %s\n", path);
    goto cleanup;
  }
  if ((size_t)height > SIZE_MAX / sizeof(*rows)) {
    fprintf(stderr, "PNG row allocation overflows host size_t: %s\n", path);
    goto cleanup;
  }

  rows = (png_bytep *)calloc((size_t)height, sizeof(*rows));
  if (rows == NULL) {
    fprintf(stderr, "cannot allocate PNG row pointers: %s\n", path);
    goto cleanup;
  }
  while (allocated_rows < (size_t)height) {
    rows[allocated_rows] = (png_bytep)malloc(rowbytes);
    if (rows[allocated_rows] == NULL) {
      fprintf(stderr, "cannot allocate PNG row buffer: %s\n", path);
      goto cleanup;
    }
    allocated_rows++;
  }

  png_read_image(png_ptr, rows);
  png_read_end(png_ptr, NULL);

  for (size_t row = 0; row < (size_t)height; row++) {
    for (size_t byte = 0; byte < rowbytes; byte++) {
      checksum = (checksum * UINT64_C(33)) ^ rows[row][byte];
    }
  }

  printf("PASS fixture=%s width=%" PRIu32 " height=%" PRIu32
         " bit_depth=%d color_type=%d interlace=%d compression=%d filter=%d"
         " rowbytes=%zu checksum=%" PRIu64 "\n",
         path, width, height, bit_depth, color_type, interlace_method,
         compression_method, filter_method, rowbytes, checksum);
  status = EXIT_SUCCESS;

cleanup:
  if (rows != NULL) {
    for (size_t row = 0; row < allocated_rows; row++) {
      free(rows[row]);
    }
  }
  free(rows);
  png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
  if (file != NULL) {
    fclose(file);
  }
  return status;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s PNG_FILE\n", argv[0]);
    return EXIT_FAILURE;
  }
  return decode_fixture(argv[1]);
}
