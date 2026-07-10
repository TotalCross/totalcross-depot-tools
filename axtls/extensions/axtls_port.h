/*
 * axTLS portable integration hooks.
 *
 * Create a hook table and pass it to ssl_ctx_new_with_port(). Hooks are
 * copied into the SSL_CTX and apply to every SSL object created from it.
 * The user_data pointer remains owned by the caller and must remain valid
 * until ssl_ctx_free().
 *
 * A process that does not need integration can keep using ssl_ctx_new(); it
 * uses the libc and native socket defaults.
 */
#ifndef AXTLS_PORT_H
#define AXTLS_PORT_H

#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

#define AXTLS_PORT_HOOKS_VERSION 1u

typedef void *(*axtls_port_malloc_fn)(void *user_data, size_t size,
        const char *file, int line);
typedef void *(*axtls_port_calloc_fn)(void *user_data, size_t count,
        size_t size, const char *file, int line);
typedef void *(*axtls_port_realloc_fn)(void *user_data, void *ptr,
        size_t size, const char *file, int line);
typedef void (*axtls_port_free_fn)(void *user_data, void *ptr,
        const char *file, int line);
typedef int (*axtls_port_read_fn)(void *user_data, int fd, void *buffer,
        int length);
typedef int (*axtls_port_write_fn)(void *user_data, int fd,
        const void *buffer, int length);
typedef int (*axtls_port_close_fn)(void *user_data, int fd);
typedef int (*axtls_port_vlog_fn)(void *user_data, const char *format,
        va_list args);
typedef void (*axtls_port_abort_fn)(void *user_data, const char *message,
        const char *file, int line);

typedef struct AXTLS_PORT_HOOKS {
    uint32_t version;
    size_t struct_size;
    void *user_data;
    axtls_port_malloc_fn malloc_fn;
    axtls_port_calloc_fn calloc_fn;
    axtls_port_realloc_fn realloc_fn;
    axtls_port_free_fn free_fn;
    axtls_port_read_fn read_fn;
    axtls_port_write_fn write_fn;
    axtls_port_close_fn close_fn;
    axtls_port_vlog_fn vlog_fn;
    axtls_port_abort_fn abort_fn;
} AXTLS_PORT_HOOKS;

/* Initialise a table with the current ABI version and native defaults. */
void axtls_port_hooks_init(AXTLS_PORT_HOOKS *hooks);

/* Internal entry points used by axTLS source and available to integrations. */
int axtls_port_hooks_copy(AXTLS_PORT_HOOKS *destination,
        const AXTLS_PORT_HOOKS *source);
const AXTLS_PORT_HOOKS *axtls_port_hooks_default(void);
const AXTLS_PORT_HOOKS *axtls_port_scope_push(
        const AXTLS_PORT_HOOKS *hooks);
void axtls_port_scope_pop(const AXTLS_PORT_HOOKS *previous);
void *axtls_port_malloc(size_t size, const char *file, int line);
void *axtls_port_calloc(size_t count, size_t size, const char *file, int line);
void *axtls_port_realloc(void *ptr, size_t size, const char *file, int line);
void axtls_port_free(void *ptr, const char *file, int line);
int axtls_port_read(int fd, void *buffer, int length);
int axtls_port_write(int fd, const void *buffer, int length);
int axtls_port_close(int fd);
int axtls_port_printf(const char *format, ...);
void axtls_port_abort(const char *message, const char *file, int line);

#endif
