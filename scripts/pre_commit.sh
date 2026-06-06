#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.moon/bin:$PATH"

moon fmt
moon check
moon test --target wasm
moon test --target wasm-gc
moon test --target js
moon test --target native

