#!/usr/bin/env bash
# Single self-validation gate. Agents run this before declaring work done.
# Exits non-zero on the first failure.
set -euo pipefail

export PATH="$HOME/.rokit/bin:$PATH"
cd "$(dirname "$0")/.."

echo "▶ Wally packages"
if [ ! -d Packages ]; then
	wally install
fi

echo "▶ StyLua (format check)"
stylua --check src tests scripts

echo "▶ selene (lint)"
selene src

echo "▶ Rojo sourcemap"
rojo sourcemap default.project.json --output sourcemap.json >/dev/null

echo "▶ luau-lsp analyze (type-check)"
if [ -f globalTypes.d.luau ]; then
	luau-lsp analyze --sourcemap sourcemap.json --defs globalTypes.d.luau --ignore "Packages/**" --ignore "vendor/**" src
else
	echo "  (globalTypes.d.luau absent -> type-check limité à la logique pure)"
	luau-lsp analyze src/shared/Logic src/shared/Config
fi

echo "▶ Lune tests"
lune run scripts/run-tests

echo ""
echo "✅ Validation OK"
