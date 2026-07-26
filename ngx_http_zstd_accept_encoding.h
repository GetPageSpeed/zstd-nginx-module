
/*
 * Copyright (C) GetPageSpeed LLC
 */


#ifndef NGX_HTTP_ZSTD_ACCEPT_ENCODING_H_INCLUDED_
#define NGX_HTTP_ZSTD_ACCEPT_ENCODING_H_INCLUDED_


#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>


/*
 * Accept-Encoding parsing, per RFC 9110 section 12.5.3:
 *
 *     Accept-Encoding = #( codings [ weight ] )
 *     codings         = content-coding / "identity" / "*"
 *     weight          = OWS ";" OWS "q=" qvalue
 *     qvalue          = ( "0" [ "." 0*3DIGIT ] ) / ( "1" [ "." 0*3"0" ] )
 *
 * Both modules ask the same question of the same header, so the parser lives
 * here rather than being duplicated in each.
 *
 * Three properties matter and are easy to get wrong with a substring search:
 *
 *   - "zstd;q=0" means the client explicitly refuses zstd. It is not the same
 *     as the coding being absent.
 *   - "*" is a real wildcard, and an explicit entry for zstd overrides it in
 *     either direction ("*;q=0, zstd" accepts, "*, zstd;q=0" refuses).
 *   - Coding names are whole tokens. "zstd-foo" and "notzstd" are different
 *     codings that happen to contain "zstd" as a substring.
 */


#define NGX_HTTP_ZSTD_QVALUE_ABSENT  (-1)


static ngx_inline ngx_uint_t
ngx_http_zstd_is_tchar(u_char c)
{
    if ((c >= 'a' && c <= 'z')
        || (c >= 'A' && c <= 'Z')
        || (c >= '0' && c <= '9'))
    {
        return 1;
    }

    switch (c) {
    case '!': case '#': case '$': case '%': case '&': case '\'':
    case '*': case '+': case '-': case '.': case '^': case '_':
    case '`': case '|': case '~':
        return 1;
    default:
        return 0;
    }
}


static ngx_inline u_char *
ngx_http_zstd_skip_ows(u_char *p, u_char *last)
{
    while (p < last && (*p == ' ' || *p == '\t')) {
        p++;
    }

    return p;
}


/*
 * Parse a qvalue into thousandths, so 1 becomes 1000 and 0.001 becomes 1.
 *
 * The accumulator is ngx_int_t and the fraction is capped at three digits, so
 * a long run of digits is rejected outright rather than being folded into a
 * narrower type where it could wrap and turn a refusal into an acceptance.
 */
static ngx_inline ngx_int_t
ngx_http_zstd_parse_qvalue(u_char **pos, u_char *last, ngx_int_t *qvalue)
{
    u_char     *p;
    ngx_int_t   q, scale;
    ngx_uint_t  digits;

    p = *pos;

    if (p == last) {
        return NGX_ERROR;
    }

    if (*p == '1') {
        q = 1000;
        p++;

        if (p < last && *p == '.') {
            p++;

            /* only zeroes may follow 1., anything else exceeds 1 */

            for (digits = 0; p < last && *p >= '0' && *p <= '9'; p++) {
                if (++digits > 3 || *p != '0') {
                    return NGX_ERROR;
                }
            }
        }

    } else if (*p == '0') {
        q = 0;
        p++;

        if (p < last && *p == '.') {
            p++;

            for (digits = 0, scale = 100;
                 p < last && *p >= '0' && *p <= '9';
                 p++, scale /= 10)
            {
                if (++digits > 3) {
                    return NGX_ERROR;
                }

                q += (*p - '0') * scale;
            }
        }

    } else {
        return NGX_ERROR;
    }

    *pos = p;
    *qvalue = q;

    return NGX_OK;
}


/*
 * Advance past the remainder of the current list element. Quote-aware: a comma
 * inside a quoted-string does not end the element, and a backslash inside one
 * escapes the next octet.
 */
static ngx_inline u_char *
ngx_http_zstd_skip_element(u_char *p, u_char *last)
{
    ngx_uint_t  quoted;

    for (quoted = 0; p < last; p++) {

        if (quoted) {
            if (*p == '\\' && p + 1 < last) {
                p++;

            } else if (*p == '"') {
                quoted = 0;
            }

            continue;
        }

        if (*p == '"') {
            quoted = 1;

        } else if (*p == ',') {
            return p;
        }
    }

    return last;
}


static ngx_inline ngx_int_t
ngx_http_zstd_accept_encoding(ngx_str_t *ae)
{
    u_char     *p, *last, *name, *param;
    size_t      len, param_len;
    ngx_int_t   q, zstd_q, wildcard_q;
    ngx_uint_t  seen_q, bad;

    if (ae == NULL || ae->data == NULL) {
        return NGX_DECLINED;
    }

    p = ae->data;
    last = ae->data + ae->len;

    zstd_q = NGX_HTTP_ZSTD_QVALUE_ABSENT;
    wildcard_q = NGX_HTTP_ZSTD_QVALUE_ABSENT;

    while (p < last) {

        /* OWS and empty list elements, which the grammar permits */

        while (p < last && (*p == ' ' || *p == '\t' || *p == ',')) {
            p++;
        }

        if (p == last) {
            break;
        }

        name = p;

        while (p < last && ngx_http_zstd_is_tchar(*p)) {
            p++;
        }

        len = p - name;

        if (len == 0) {
            /* not a token where a coding name is required */
            p = ngx_http_zstd_skip_element(p, last);
            continue;
        }

        q = 1000;               /* no weight present means q=1 */
        seen_q = 0;
        bad = 0;

        for ( ;; ) {
            p = ngx_http_zstd_skip_ows(p, last);

            if (p == last || *p != ';') {
                break;
            }

            p++;                                            /* ';' */
            p = ngx_http_zstd_skip_ows(p, last);

            param = p;

            while (p < last && ngx_http_zstd_is_tchar(*p)) {
                p++;
            }

            param_len = p - param;
            p = ngx_http_zstd_skip_ows(p, last);

            if (p == last || *p != '=') {
                /* a parameter with no value; nothing to interpret */
                if (param_len == 0) {
                    bad = 1;
                    break;
                }

                continue;
            }

            p++;                                            /* '=' */
            p = ngx_http_zstd_skip_ows(p, last);

            if (param_len == 1 && (*param == 'q' || *param == 'Q')) {

                /* a second q for one element is ambiguous, so reject it */

                if (seen_q
                    || ngx_http_zstd_parse_qvalue(&p, last, &q) != NGX_OK)
                {
                    bad = 1;
                    break;
                }

                seen_q = 1;
                continue;
            }

            /* some other parameter: step over its value */

            if (p < last && *p == '"') {
                p++;

                while (p < last && *p != '"') {
                    if (*p == '\\' && p + 1 < last) {
                        p++;
                    }

                    p++;
                }

                if (p < last) {
                    p++;                                    /* closing '"' */
                }

            } else {
                while (p < last && ngx_http_zstd_is_tchar(*p)) {
                    p++;
                }
            }
        }

        if (!bad) {
            if (len == 4 && ngx_strncasecmp(name, (u_char *) "zstd", 4) == 0) {
                zstd_q = q;

            } else if (len == 1 && *name == '*') {
                wildcard_q = q;
            }
        }

        p = ngx_http_zstd_skip_element(p, last);
    }

    /* an explicit entry for the coding always beats the wildcard */

    if (zstd_q != NGX_HTTP_ZSTD_QVALUE_ABSENT) {
        return zstd_q > 0 ? NGX_OK : NGX_DECLINED;
    }

    if (wildcard_q != NGX_HTTP_ZSTD_QVALUE_ABSENT) {
        return wildcard_q > 0 ? NGX_OK : NGX_DECLINED;
    }

    return NGX_DECLINED;
}


#endif /* NGX_HTTP_ZSTD_ACCEPT_ENCODING_H_INCLUDED_ */
