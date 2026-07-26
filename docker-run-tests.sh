#!/usr/bin/env bash
set -euo pipefail

NGINX_SRC=${NGINX_SRC:-/opt/nginx-src}
MODULE_DIR=${MODULE_DIR:-/work}

ASAN=${ASAN:-0}

# gzip_static is needed by the zstd_static fallback tests; keep this list in
# sync with Dockerfile.tests-base.
CONFIGURE_ARGS=(
    --with-debug
    --with-compat
    --with-http_gzip_static_module
    --add-module="$MODULE_DIR"
)

cd "$NGINX_SRC"
rm -rf objs/addon objs/ngx_modules.c 2>/dev/null || true

if [ "$ASAN" = "1" ]; then
    # LSAN off, and it must be off before ./auto/configure runs, not just for
    # the test run: the module's libzstd feature test calls ZSTD_createCCtx()
    # without freeing it, so LeakSanitizer fails that probe at exit and nginx
    # reports "found but is not working" for both the static and shared library.
    # nginx also leaves benign allocations live at the point Test::Nginx kills
    # it. Reports go to per-pid files we scan after the run.
    rm -rf /tmp/asan
    mkdir -p /tmp/asan
    export ASAN_OPTIONS="detect_leaks=0:abort_on_error=1:log_path=/tmp/asan/asan"

    # Static --add-module build with AddressSanitizer. A dynamic module loaded
    # into a non-ASAN nginx cannot be sanitized, so we link everything into one
    # instrumented binary.
    ./auto/configure "${CONFIGURE_ARGS[@]}" \
        --with-cc-opt="-fsanitize=address -fno-omit-frame-pointer -g" \
        --with-ld-opt="-fsanitize=address"
    make -j"$(nproc)"
else
    ./auto/configure "${CONFIGURE_ARGS[@]}"
    make -j"$(nproc)"
fi

export TEST_NGINX_BINARY="$NGINX_SRC/objs/nginx"

cd "$MODULE_DIR"

# nginx derives ETag from "<hex mtime>-<hex size>", and git sets mtime to
# checkout time, so any assertion on a fixture's ETag is otherwise unstable
# across clones and CI runners. Pin the fixtures to the epoch the suite was
# originally written against (2018-11-06) to make those ETags deterministic.
if [ -d t/suite ]; then
    touch -d @1541504307 t/suite/test t/suite/test.zst 2>/dev/null || true
fi

TEST_FILE=${1:-t/*.t}

if [ "$ASAN" = "1" ]; then
    set +e
    prove -v $TEST_FILE
    rc=$?
    set -e
    # Fail the run if ASan/UBSan wrote any report, even when prove passed: a
    # sanitized worker can crash without failing every test assertion.
    #
    # The glob is "asan*", not "asan.*". Test::Nginx sets its own ASAN_OPTIONS
    # per test block and appends the block name to log_path, so reports land as
    # asan-<testfile>-t<n>.<pid> rather than asan.<pid>. Matching on "asan.*"
    # silently finds nothing and the gate never fires.
    if grep -q "AddressSanitizer\|runtime error" /tmp/asan/asan* 2>/dev/null; then
        echo "=== AddressSanitizer / UBSan reports detected ===" >&2
        cat /tmp/asan/asan* >&2
        exit 1
    fi
    exit $rc
fi

exec prove -v $TEST_FILE
