/*
 * Compile-surface shim for fuzzing — see ngx_config.h. Only the HTTP types
 * referenced by the Vary helpers in ../../ngx_http_zstd_accept_encoding.h
 * are sketched here so that header compiles whole. Those helpers are static
 * inline and the fuzz target never calls them, so none of this is executed;
 * the layouts are deliberately minimal, not faithful.
 */

#ifndef _NGX_HTTP_H_INCLUDED_
#define _NGX_HTTP_H_INCLUDED_

#include <ngx_config.h>
#include <ngx_core.h>

typedef struct {
    unsigned          gzip_vary:1;

    struct {
        ngx_list_t    headers;
    } headers_out;
} ngx_http_request_t;

typedef struct {
    ngx_flag_t        gzip_vary;
} ngx_http_core_loc_conf_t;

/*
 * The helpers only NULL-check the result before dereferencing, so a constant
 * NULL keeps them compiling without dragging in module/conf machinery.
 */
#define ngx_http_get_module_loc_conf(r, module)  (NULL)

#endif /* _NGX_HTTP_H_INCLUDED_ */
