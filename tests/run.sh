#!/bin/sh
# Runs the plugin's pure test suites. Requires `steel` on PATH; does not require
# Helix, because these modules avoid `helix/*` imports entirely.
set -e

cd "$(dirname "$0")/.."
FAILED=0

run() {
	echo
	echo "== $1 =="
	shift
	if ! "$@"; then FAILED=1; fi
}

run "string helpers" steel tests/strings-test.scm
run "block rendering" steel tests/render-test.scm

echo
if [ "$FAILED" -eq 0 ]; then
	echo "all suites completed"
else
	echo "some suites reported failures"
	exit 1
fi
