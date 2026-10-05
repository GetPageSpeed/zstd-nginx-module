/*
 * libFuzzer target for the Accept-Encoding decision seam.
 *
 * ngx_http_zstd_accept_encoding() is a seam function: it takes a plain
 * ngx_str_t view of untrusted header bytes and no nginx request/connection
 * types, so this target #includes the REAL production header and calls the
 * exact code both modules run — no extracted copy, no reimplementation.
 * The shim headers in nginx-shim/ supply core typedefs only.
 *
 * The input is replayed from an exact-sized heap allocation so any read past
 * the header's [data, data+len) contract is an immediate ASAN report, even
 * when the overrun would land in readable memory.
 */

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

#include <stdlib.h>
#include <string.h>

#include "../ngx_http_zstd_accept_encoding.h"

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    u_char     *buf;
    ngx_str_t   ae;
    ngx_int_t   rc, rc2;

    buf = malloc(size ? size : 1);
    if (buf == NULL) {
        return 0;
    }

    memcpy(buf, data, size);

    ae.len = size;
    ae.data = buf;

    rc = ngx_http_zstd_accept_encoding(&ae);

    /* The seam's whole contract: accept or decline, nothing else. */
    if (rc != NGX_OK && rc != NGX_DECLINED) {
        abort();
    }

    /* Pure parser: same bytes must give the same answer. */
    rc2 = ngx_http_zstd_accept_encoding(&ae);
    if (rc2 != rc) {
        abort();
    }

    free(buf);

    return 0;
}
