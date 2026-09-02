use Test::More tests => 5;

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or die "open $path: $!";
    local $/;
    return <$fh>;
}

my $root = slurp('config');
my $filter = slurp('filter/config');
my $static = slurp('static/config');
my $module = slurp('filter/ngx_http_zstd_filter_module.c');
my $makefile = slurp('Makefile');

like($root, qr/^ngx_feature_run=no$/m,
    'libzstd feature probe is safe for cross-compilation');
like($filter, qr/ngx_http_brotli_filter_module/,
    'filter ordering accounts for brotli');
like($static, qr/ngx_http_brotli_static_module/,
    'static handler ordering accounts for brotli');
like($module, qr/\(uint64_t\)\s*ctx->bytes_in\s*\*\s*1000/,
    'ratio fraction widens before multiplication');
like($makefile, qr/^PULL \?=[^\n]*\n.*?\$\(DOCKER\) build \$\(PULL\)/ms,
    'tests use cached base image unless a registry refresh is requested');
