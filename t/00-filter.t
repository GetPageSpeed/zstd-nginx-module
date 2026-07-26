use Test::Nginx::Socket 'no_plan';

no_long_string();
no_shuffle();
run_tests();

__DATA__

=== TEST 1: compresses when the client accepts zstd
--- config
    gzip_vary on;
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        default_type text/plain;
        return 200 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
Vary: Accept-Encoding
--- no_error_log
[error]



=== TEST 2: does not compress when the client does not accept zstd
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        default_type text/plain;
        return 200 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    }
--- request
GET /t
--- more_headers
Accept-Encoding: gzip, deflate
--- response_headers
!Content-Encoding
--- no_error_log
[error]



=== TEST 3: does not compress with no Accept-Encoding at all
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        default_type text/plain;
        return 200 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    }
--- request
GET /t
--- response_headers
!Content-Encoding
--- no_error_log
[error]



=== TEST 4: zstd off is not compressed
--- config
    location /t {
        zstd off;
        default_type text/plain;
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



=== TEST 5: a body shorter than zstd_min_length is not compressed
--- config
    location /t {
        zstd on;
        zstd_min_length 512;
        zstd_types text/plain;
        default_type text/plain;
        return 200 'short body';
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
!Content-Encoding
--- no_error_log
[error]



=== TEST 6: a MIME type outside zstd_types is not compressed
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        default_type application/octet-stream;
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



=== TEST 7: HEAD carries the same Content-Encoding a GET would
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        default_type text/plain;
        return 200 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    }
--- request
HEAD /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
--- response_body
--- no_error_log
[error]



=== TEST 8: an already-encoded upstream response is not re-compressed
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/origin;
    }

    location /origin {
        zstd off;
        default_type text/plain;
        add_header Content-Encoding br;
        return 200 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: br
--- no_error_log
[error]



=== TEST 9: compressing disables ranges, so no 206 is produced
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        default_type text/plain;
        root html;
        try_files /../../../t/suite/test =404;
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
Range: bytes=0-99
--- error_code: 200
--- response_headers
Content-Encoding: zstd
!Content-Range
--- no_error_log
[error]



=== TEST 10: an uncompressed range request still yields a clean 206
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        default_type text/plain;
        root html;
        try_files /../../../t/suite/test =404;
    }
--- request
GET /t
--- more_headers
Accept-Encoding: gzip
Range: bytes=0-99
--- error_code: 206
--- response_headers
!Content-Encoding
Content-Length: 100
--- no_error_log
[error]
