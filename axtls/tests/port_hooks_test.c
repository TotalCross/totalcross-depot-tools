#include <stdio.h>
#include <stdlib.h>

#include "axtls_port.h"

typedef struct {
    int allocations;
    int frees;
} hook_state;

static void *counted_malloc(void *user, size_t size, const char *file, int line)
{
    hook_state *state = user;
    (void)file; (void)line;
    state->allocations++;
    return malloc(size);
}

static void *counted_calloc(void *user, size_t count, size_t size,
        const char *file, int line)
{
    hook_state *state = user;
    (void)file; (void)line;
    state->allocations++;
    return calloc(count, size);
}

static void *counted_realloc(void *user, void *ptr, size_t size,
        const char *file, int line)
{
    hook_state *state = user;
    (void)file; (void)line;
    state->allocations++;
    return realloc(ptr, size);
}

static void counted_free(void *user, void *ptr, const char *file, int line)
{
    hook_state *state = user;
    (void)file; (void)line;
    state->frees++;
    free(ptr);
}

int main(void)
{
    hook_state first = {0, 0};
    hook_state second = {0, 0};
    AXTLS_PORT_HOOKS first_hooks;
    AXTLS_PORT_HOOKS second_hooks;
    const AXTLS_PORT_HOOKS *previous;
    void *first_memory;
    void *second_memory;

    axtls_port_hooks_init(&first_hooks);
    axtls_port_hooks_init(&second_hooks);
    first_hooks.user_data = &first;
    second_hooks.user_data = &second;
    first_hooks.malloc_fn = second_hooks.malloc_fn = counted_malloc;
    first_hooks.calloc_fn = second_hooks.calloc_fn = counted_calloc;
    first_hooks.realloc_fn = second_hooks.realloc_fn = counted_realloc;
    first_hooks.free_fn = second_hooks.free_fn = counted_free;

    previous = axtls_port_scope_push(&first_hooks);
    first_memory = axtls_port_calloc(1, 32, __FILE__, __LINE__);
    axtls_port_scope_pop(previous);
    previous = axtls_port_scope_push(&second_hooks);
    second_memory = axtls_port_malloc(32, __FILE__, __LINE__);
    axtls_port_free(second_memory, __FILE__, __LINE__);
    axtls_port_scope_pop(previous);
    previous = axtls_port_scope_push(&first_hooks);
    axtls_port_free(first_memory, __FILE__, __LINE__);
    axtls_port_scope_pop(previous);

    if (first.allocations != 1 || second.allocations != 1) {
        fprintf(stderr, "hook scopes crossed between contexts\n");
        return 1;
    }
    if (first.frees == 0 || second.frees == 0) {
        fprintf(stderr, "hooks did not free through their own tables\n");
        return 1;
    }
    return 0;
}
