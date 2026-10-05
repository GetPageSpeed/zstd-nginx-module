#!/usr/bin/env bash
#
# Build the Accept-Encoding seam libFuzzer target.
# Usage: fuzz/build.sh [output-dir]
#
# Requires clang with libFuzzer (clang >= 6). CC/CFLAGS overridable for
# OSS-Fuzz / ClusterFuzzLite, which pass their own sanitizer flags.
#
# Unlike extraction-based harnesses there is no generate step: the target
# compiles ../ngx_http_zstd_accept_encoding.h — the shipped production file —
# directly, against the tiny type shims in nginx-shim/.

set -euo pipefail

FUZZ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${CC:-}" ]; then
    CC=clang
    # Xcode 26's Apple clang accepts -fsanitize=fuzzer but no longer ships the
    # macOS libFuzzer archive. Prefer an already-installed Homebrew LLVM on
    # Darwin when the default compiler cannot resolve that runtime. Explicit
    # CC always wins, and non-Darwin/CI behavior is unchanged.
    if [ "$(uname -s)" = Darwin ] \
       && [ ! -f "$("$CC" -print-file-name=libclang_rt.fuzzer_osx.a)" ] \
       && command -v brew >/dev/null 2>&1
    then
        LLVM_PREFIX="$(brew --prefix llvm 2>/dev/null || true)"
        if [ -x "$LLVM_PREFIX/bin/clang" ]; then
            CC="$LLVM_PREFIX/bin/clang"
        fi
    fi
fi

# OSS-Fuzz sets $LIB_FUZZING_ENGINE and its own $CFLAGS; honour them.
ENGINE="${LIB_FUZZING_ENGINE:--fsanitize=fuzzer}"
CFLAGS="${CFLAGS:--g -O1 -fsanitize=address,undefined -fno-sanitize-recover=undefined}"

DIR="${1:-$FUZZ_DIR}"

# shellcheck disable=SC2086
"$CC" $CFLAGS $ENGINE -I"$FUZZ_DIR/nginx-shim" \
    "$FUZZ_DIR/fuzz_accept_encoding.c" -o "$DIR/fuzz_accept_encoding"
echo "✓ built fuzz target: $DIR/fuzz_accept_encoding"
