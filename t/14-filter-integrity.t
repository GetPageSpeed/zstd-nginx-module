use Test::Nginx::Socket 'no_plan';
use Digest::SHA qw(sha1_hex sha256);
use File::Temp qw(tempfile);

sub zstd_decode {
    my ($compressed) = @_;
    my ($fh, $path) = tempfile();

    binmode $fh;
    print {$fh} $compressed or die "write compressed fixture: $!";
    close $fh or die "close compressed fixture: $!";

    open my $zstd, '-|', 'zstd', '--decompress', '--quiet', '--stdout', $path
        or die "start zstd: $!";
    binmode $zstd;

    local $/;
    my $decoded = <$zstd>;
    close $zstd or die "zstd rejected response body";
    unlink $path or die "remove compressed fixture: $!";

    return $decoded;
}

my $large_body = join '', map { sha256(pack('N', $_)) } 0 .. 8191;
our $large_sha1 = sha1_hex($large_body);

no_long_string();
no_shuffle();
run_tests();

__DATA__

=== TEST 1: a body larger than ZSTD_CStreamInSize decodes byte-for-byte
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_buffers 2 4k;
        zstd_types application/octet-stream;
        default_type application/octet-stream;
        output_buffers 1 512k;
        root html;
        try_files /../../../t/suite/large.bin =404;
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
--- response_body_filters eval
[\&::zstd_decode, 'sha1_hex']
--- response_body eval
$::large_sha1
--- no_error_log
[error]



=== TEST 2: proxy_buffering off produces a complete decodable frame
--- config
    location /t {
        zstd on;
        zstd_min_length 1;
        zstd_buffers 2 4k;
        zstd_types application/octet-stream;
        default_type application/octet-stream;
        proxy_buffering off;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/origin;
    }

    location /origin {
        zstd off;
        default_type application/octet-stream;
        output_buffers 1 512k;
        root html;
        try_files /../../../t/suite/large.bin =404;
    }
--- request
GET /t
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
--- response_body_filters eval
[\&::zstd_decode, 'sha1_hex']
--- response_body eval
$::large_sha1
--- no_error_log
[error]
