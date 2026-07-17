/*
 * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
 * SPDX-License-Identifier: MIT
 */
#include "axtls_port.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
# include <winsock2.h>
#else
# include <unistd.h>
#endif

#if defined(_MSC_VER)
# define AXTLS_THREAD_LOCAL __declspec(thread)
#else
# define AXTLS_THREAD_LOCAL _Thread_local
#endif

static void *default_malloc(void *user_data, size_t size,
        const char *file, int line)
{
    (void)user_data; (void)file; (void)line;
    return malloc(size);
}

static void *default_calloc(void *user_data, size_t count, size_t size,
        const char *file, int line)
{
    (void)user_data; (void)file; (void)line;
    return calloc(count, size);
}

static void *default_realloc(void *user_data, void *ptr, size_t size,
        const char *file, int line)
{
    (void)user_data; (void)file; (void)line;
    return realloc(ptr, size);
}

static void default_free(void *user_data, void *ptr, const char *file, int line)
{
    (void)user_data; (void)file; (void)line;
    free(ptr);
}

static int default_read(void *user_data, int fd, void *buffer, int length)
{
    (void)user_data;
#if defined(_WIN32)
    return recv(fd, (char *)buffer, length, 0);
#else
    return (int)read(fd, buffer, (size_t)length);
#endif
}

static int default_write(void *user_data, int fd, const void *buffer, int length)
{
    (void)user_data;
#if defined(_WIN32)
    return send(fd, (const char *)buffer, length, 0);
#else
    return (int)write(fd, buffer, (size_t)length);
#endif
}

static int default_close(void *user_data, int fd)
{
    (void)user_data;
#if defined(_WIN32)
    return closesocket(fd);
#else
    return close(fd);
#endif
}

static int default_vlog(void *user_data, const char *format, va_list args)
{
    (void)user_data;
    return vfprintf(stderr, format, args);
}

static void default_abort(void *user_data, const char *message,
        const char *file, int line)
{
    (void)user_data;
    fprintf(stderr, "axTLS abort: %s (%s:%d)\n", message ? message : "",
            file ? file : "", line);
    abort();
}

static const AXTLS_PORT_HOOKS default_hooks = {
    AXTLS_PORT_HOOKS_VERSION, sizeof(AXTLS_PORT_HOOKS), NULL,
    default_malloc, default_calloc, default_realloc, default_free,
    default_read, default_write, default_close, default_vlog, default_abort
};

static AXTLS_THREAD_LOCAL const AXTLS_PORT_HOOKS *active_hooks;

const AXTLS_PORT_HOOKS *axtls_port_hooks_default(void)
{
    return &default_hooks;
}

void axtls_port_hooks_init(AXTLS_PORT_HOOKS *hooks)
{
    if (hooks)
        *hooks = default_hooks;
}

int axtls_port_hooks_copy(AXTLS_PORT_HOOKS *destination,
        const AXTLS_PORT_HOOKS *source)
{
    if (!destination)
        return -1;
    if (!source) {
        *destination = default_hooks;
        return 0;
    }
    if (source->version != AXTLS_PORT_HOOKS_VERSION ||
            source->struct_size < sizeof(AXTLS_PORT_HOOKS))
        return -1;
    *destination = default_hooks;
    memcpy(destination, source, sizeof(AXTLS_PORT_HOOKS));
    destination->version = AXTLS_PORT_HOOKS_VERSION;
    destination->struct_size = sizeof(AXTLS_PORT_HOOKS);
    if (!destination->malloc_fn) destination->malloc_fn = default_malloc;
    if (!destination->calloc_fn) destination->calloc_fn = default_calloc;
    if (!destination->realloc_fn) destination->realloc_fn = default_realloc;
    if (!destination->free_fn) destination->free_fn = default_free;
    if (!destination->read_fn) destination->read_fn = default_read;
    if (!destination->write_fn) destination->write_fn = default_write;
    if (!destination->close_fn) destination->close_fn = default_close;
    if (!destination->vlog_fn) destination->vlog_fn = default_vlog;
    if (!destination->abort_fn) destination->abort_fn = default_abort;
    return 0;
}

static const AXTLS_PORT_HOOKS *current_hooks(void)
{
    return active_hooks ? active_hooks : &default_hooks;
}

const AXTLS_PORT_HOOKS *axtls_port_scope_push(const AXTLS_PORT_HOOKS *hooks)
{
    const AXTLS_PORT_HOOKS *previous = active_hooks;
    active_hooks = hooks ? hooks : &default_hooks;
    return previous;
}

void axtls_port_scope_pop(const AXTLS_PORT_HOOKS *previous)
{
    active_hooks = previous;
}

void *axtls_port_malloc(size_t size, const char *file, int line)
{
    const AXTLS_PORT_HOOKS *hooks = current_hooks();
    return hooks->malloc_fn(hooks->user_data, size, file, line);
}

void *axtls_port_calloc(size_t count, size_t size, const char *file, int line)
{
    const AXTLS_PORT_HOOKS *hooks = current_hooks();
    return hooks->calloc_fn(hooks->user_data, count, size, file, line);
}

void *axtls_port_realloc(void *ptr, size_t size, const char *file, int line)
{
    const AXTLS_PORT_HOOKS *hooks = current_hooks();
    return hooks->realloc_fn(hooks->user_data, ptr, size, file, line);
}

void axtls_port_free(void *ptr, const char *file, int line)
{
    const AXTLS_PORT_HOOKS *hooks = current_hooks();
    hooks->free_fn(hooks->user_data, ptr, file, line);
}

int axtls_port_read(int fd, void *buffer, int length)
{
    const AXTLS_PORT_HOOKS *hooks = current_hooks();
    return hooks->read_fn(hooks->user_data, fd, buffer, length);
}

int axtls_port_write(int fd, const void *buffer, int length)
{
    const AXTLS_PORT_HOOKS *hooks = current_hooks();
    return hooks->write_fn(hooks->user_data, fd, buffer, length);
}

int axtls_port_close(int fd)
{
    const AXTLS_PORT_HOOKS *hooks = current_hooks();
    return hooks->close_fn(hooks->user_data, fd);
}

int axtls_port_printf(const char *format, ...)
{
    const AXTLS_PORT_HOOKS *hooks = current_hooks();
    int result;
    va_list args;
    va_start(args, format);
    result = hooks->vlog_fn(hooks->user_data, format, args);
    va_end(args);
    return result;
}

void axtls_port_abort(const char *message, const char *file, int line)
{
    const AXTLS_PORT_HOOKS *hooks = current_hooks();
    hooks->abort_fn(hooks->user_data, message, file, line);
}
