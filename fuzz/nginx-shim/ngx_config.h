/*
 * Compile-surface shim for fuzzing. This is NOT nginx: it supplies only the
 * core typedefs ../../ngx_http_zstd_accept_encoding.h needs so the REAL
 * production header compiles verbatim into the fuzz target. No parser logic
 * lives here — the decision seam under test is included, not copied.
 */

#ifndef _NGX_CONFIG_H_INCLUDED_
#define _NGX_CONFIG_H_INCLUDED_

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

typedef intptr_t   ngx_int_t;
typedef uintptr_t  ngx_uint_t;
typedef intptr_t   ngx_flag_t;

#define ngx_inline inline

/* New enough that the versioned branches in shared headers compile. */
#define nginx_version 1030004

#endif /* _NGX_CONFIG_H_INCLUDED_ */
