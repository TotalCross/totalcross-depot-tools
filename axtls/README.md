# axTLS 2.1.5

This package builds the axTLS 2.1.5 static library from the official source
archive and publishes repository-local prebuilts under
`local/<platform>/<arch>`.

## Port hooks

`axtls_port.h` adds an optional, dependency-free integration API. Initialise
`AXTLS_PORT_HOOKS`, replace the callbacks required by the host, and create
the context with `ssl_ctx_new_with_port()`. The hook table is copied into the
context and therefore different SSL contexts can use different allocators,
socket implementations, logs, and abort handlers. Existing
`ssl_ctx_new()` callers retain the native libc and socket defaults.

```c
AXTLS_PORT_HOOKS hooks;
axtls_port_hooks_init(&hooks);
hooks.user_data = state;
hooks.read_fn = host_read;
hooks.write_fn = host_write;
hooks.malloc_fn = host_malloc;
hooks.free_fn = host_free;
SSL_CTX *ctx = ssl_ctx_new_with_port(options, sessions, &hooks);
```

The caller keeps `hooks.user_data` alive until `ssl_ctx_free(ctx)`.
Use the `*_with_port` RSA constructors for standalone RSA operations that
also need custom allocation hooks.
