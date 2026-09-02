#!/usr/bin/env bash
set -euo pipefail

HELIX_RUNTIME="${HELIX_RUNTIME:-/opt/helix/runtime}"

mkdir -p "${HOME}/.config/helix"
ln -sfn "${HELIX_RUNTIME}" "${HOME}/.config/helix/runtime"

echo "hx      : $(hx --version | head -n1)"
echo "steel   : $(steel --version 2>/dev/null | head -n1 || echo 'unknown')"
echo "forge   : $(forge --version 2>/dev/null | head -n1 || echo 'unknown')"

if hx --health cpp >/dev/null 2>&1; then
  echo "grammar : cpp ok"
else
  echo "grammar : WARNING - 'hx --health cpp' failed" >&2
fi

cat <<'EOF'

Ready. The workspace ships .helix/{helix.scm,init.scm}, which Helix picks up
automatically for any file under this repo, so edits are live with no install.

  ./tests/run.sh                 pure Steel suites
  hx tests/fixtures/sample.cpp   then :doxygen-selftest for the parser suite
EOF
