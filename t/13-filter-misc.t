use Test::Nginx::Socket 'no_plan';

no_long_string();
no_shuffle();
run_tests();

__DATA__

=== TEST 1: zstd_min_length takes exactly one argument
The directive was declared NGX_CONF_1MORE, which accepts any number of
arguments and silently ignores all but the first.
--- config
    location /t {
        zstd on;
        zstd_min_length 10 20 30;
        return 200 'ok';
    }
--- must_die
--- error_log
invalid number of arguments in "zstd_min_length" directive



=== TEST 2: zstd_min_length still accepts a single argument
--- config
    location /t {
        zstd on;
        zstd_min_length 512;
        default_type text/plain;
        return 200 'short';
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
!Content-Encoding
--- no_error_log
[error]



=== TEST 3: application/wasm is compressed by default
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        default_type application/wasm;
        return 200 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
--- no_error_log
[error]



=== TEST 4: text/wgsl is compressed by default
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        default_type text/wgsl;
        return 200 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
--- no_error_log
[error]



=== TEST 5: text/html is still compressed by default
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        default_type text/html;
        return 200 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
--- no_error_log
[error]



=== TEST 6: an explicit zstd_types still overrides the defaults
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        default_type application/wasm;
        return 200 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
!Content-Encoding
--- no_error_log
[error]



=== TEST 7: a response large enough to recycle output buffers is intact
Exercises the free-list path in ngx_http_zstd_filter_get_buf(). A buffer coming
back round carries the flags it was last sent with, and a stale last_buf would
truncate the response.
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_buffers 4 4k;
        zstd_types text/plain;
        default_type text/plain;
        root html;
        try_files /../../../t/suite/test =404;
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
--- no_error_log
[error]



=== TEST 8: many sequential requests over one connection stay correct
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_buffers 4 4k;
        zstd_types text/plain;
        default_type text/plain;
        root html;
        try_files /../../../t/suite/test =404;
    }
--- pipelined_requests eval
["GET /t", "GET /t", "GET /t", "GET /t"]
--- more_headers
Accept-Encoding: zstd
--- error_code eval
[200, 200, 200, 200]
--- no_error_log
[error]
