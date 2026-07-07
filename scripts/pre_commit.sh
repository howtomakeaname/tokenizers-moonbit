#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.moon/bin:$PATH"

moon update
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
moon test --deny-warn --target wasm
moon test --deny-warn --target wasm-gc
moon test --deny-warn --target js
moon test --deny-warn --target native
