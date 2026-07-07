#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.moon/bin:$PATH"

if moon fmt --help | grep -q -- '--deny-warn'; then
  moon fmt --deny-warn
else
  moon fmt --check
fi
moon check --deny-warn
if moon info --help | grep -q -- '--deny-warn'; then
  moon info --deny-warn
else
  moon info
fi
moon test --target wasm
moon test --target wasm-gc
moon test --target js
moon test --target native
