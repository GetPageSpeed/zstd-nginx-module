# Fuzzing

Coverage-guided fuzzing of the untrusted-input decision seam shared by both
modules:

- **`fuzz_accept_encoding`** → `ngx_http_zstd_accept_encoding()` in
  [`../ngx_http_zstd_accept_encoding.h`](../ngx_http_zstd_accept_encoding.h) —
  the RFC 9110 §12.5.3 Accept-Encoding / qvalue parser that decides, from
  attacker-controlled header bytes, whether a response gets zstd-encoded.

## The decision seam

The parser is a *seam function*: it takes a plain `ngx_str_t` view of raw
bytes and uses no nginx request/connection types. That shape is what makes
this harness honest — the target `#include`s the **real production header**
and compiles the exact code `filter/` and `static/` run in production:

- no sed/awk extraction step that can drift from the source;
- no reimplemented "test double" of the parser;
- the only scaffolding is [`nginx-shim/`](nginx-shim/), which supplies core
  typedefs (`ngx_str_t`, `ngx_int_t`, …) plus a verbatim copy of nginx's
  `ngx_strncasecmp()` — the one library call on the fuzzed path.

## What a crash would mean

The input is replayed from an exact-sized heap allocation, so any read past
the advertised `[data, data+len)` window is an immediate ASAN
heap-buffer-overflow (verified by temporarily over-stating `len` by one:
ASAN fires on the first unit). UBSan is compiled in non-recovering, so
qvalue arithmetic overflow aborts too. The harness additionally traps if the
parser ever returns anything but `NGX_OK`/`NGX_DECLINED`, or answers the
same bytes differently twice.

## Run locally

```bash
bash fuzz/build.sh          # needs clang with libFuzzer
cd fuzz
./fuzz_accept_encoding -max_total_time=60 corpus/
```

A crash drops a `crash-*` reproducer. Replay it with:

```bash
./fuzz_accept_encoding crash-<hash>
```

## CI

[`.github/workflows/fuzzing.yml`](../.github/workflows/fuzzing.yml):

- **Monthly** — 15-min discovery run, merges + uploads the grown corpus
- **Push/PR** — 2-min bounded regression run, *only* when the parser header,
  `fuzz/`, or the workflow changes (`paths:` filter)
- **Manual** — `workflow_dispatch` with a custom duration
