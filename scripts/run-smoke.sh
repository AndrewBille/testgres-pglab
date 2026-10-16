#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
: "${PG_BIN:?Set PG_BIN to the PostgreSQL bin directory}"
: "${PGLAB_OS_USER:?Set PGLAB_OS_USER to the Unix account that runs PostgreSQL}"
PGLAB_DB_USER=${PGLAB_DB_USER:-postgres}
PGLAB_TEST_ROOT=${PGLAB_TEST_ROOT:-/var/tmp}

if [[ ${EUID} -eq 0 ]]; then
    exec env \
        PG_BIN="$PG_BIN" \
        PGLAB_OS_USER="$PGLAB_OS_USER" \
        PGLAB_DB_USER="$PGLAB_DB_USER" \
        PGLAB_TEST_ROOT="$PGLAB_TEST_ROOT" \
        "$ROOT/.venv/bin/python" "$ROOT/smoke.py"
else
    exec sudo env \
        PG_BIN="$PG_BIN" \
        PGLAB_OS_USER="$PGLAB_OS_USER" \
        PGLAB_DB_USER="$PGLAB_DB_USER" \
        PGLAB_TEST_ROOT="$PGLAB_TEST_ROOT" \
        "$ROOT/.venv/bin/python" "$ROOT/smoke.py"
fi
