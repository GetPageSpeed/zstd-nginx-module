/*
 * Compile-surface shim for fuzzing — see ngx_config.h. The one function with
 * runtime behavior, ngx_strncasecmp(), is reproduced verbatim from nginx
 * src/core/ngx_string.c because the seam under test calls it on the fuzzed
 * path; everything else is type scaffolding that is compiled but never run.
 */

#ifndef _NGX_CORE_H_INCLUDED_
#define _NGX_CORE_H_INCLUDED_

#include <ngx_config.h>

#define NGX_OK          0
#define NGX_ERROR      -1
#define NGX_AGAIN      -2
#define NGX_BUSY       -3
#define NGX_DONE       -4
#define NGX_DECLINED   -5
#define NGX_ABORT      -6

typedef struct {
    size_t      len;
    u_char     *data;
} ngx_str_t;

#define ngx_str_set(str, text)                                               \
    (str)->len = sizeof(text) - 1; (str)->data = (u_char *) text

typedef struct ngx_list_part_s  ngx_list_part_t;

struct ngx_list_part_s {
    void             *elts;
    ngx_uint_t        nelts;
    ngx_list_part_t  *next;
};

typedef struct {
    ngx_list_part_t   part;
} ngx_list_t;

typedef struct ngx_table_elt_s  ngx_table_elt_t;

struct ngx_table_elt_s {
    ngx_uint_t        hash;
    ngx_str_t         key;
    ngx_str_t         value;
    ngx_table_elt_t  *next;
};

/* Compile-only: referenced by static helpers the fuzz target never calls. */
static inline void *
ngx_list_push(ngx_list_t *l)
{
    (void) l;
    return NULL;
}

/* Verbatim from nginx src/core/ngx_string.c — executed on the fuzzed path. */
static inline ngx_int_t
ngx_strncasecmp(u_char *s1, u_char *s2, size_t n)
{
    ngx_uint_t  c1, c2;

    while (n) {
        c1 = (ngx_uint_t) *s1++;
        c2 = (ngx_uint_t) *s2++;

        c1 = (c1 >= 'A' && c1 <= 'Z') ? (c1 | 0x20) : c1;
        c2 = (c2 >= 'A' && c2 <= 'Z') ? (c2 | 0x20) : c2;

        if (c1 == c2) {

            if (c1) {
                n--;
                continue;
            }

            return 0;
        }

        return c1 - c2;
    }

    return 0;
}

#endif /* _NGX_CORE_H_INCLUDED_ */
