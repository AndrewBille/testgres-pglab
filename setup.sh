#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
VENV="$ROOT/.venv"
PYTHON=python3
TESTGRES_DIR="${PGLAB_TESTGRES_DIR:-}"
INSTALL_SYSTEM_DEPS=1

usage() {
    cat <<USAGE
Usage: ./setup.sh [options]

Options:
  --skip-system-deps     do not install OS packages
  --python PATH          Python executable (default: python3)
  --venv PATH            venv directory (default: ./.venv)
  --testgres-dir PATH    install Testgres editable from this checkout
  -h, --help             show this help

Until the target-execution-context API is available in a released Testgres,
use --testgres-dir with a compatible checkout.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-system-deps)
            INSTALL_SYSTEM_DEPS=0
            shift
            ;;
        --python)
            PYTHON="$2"
            shift 2
            ;;
        --venv)
            VENV="$2"
            shift 2
            ;;
        --testgres-dir)
            TESTGRES_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ $INSTALL_SYSTEM_DEPS -eq 1 ]]; then
    "$ROOT/scripts/install-system-deps.sh"
fi

command -v "$PYTHON" >/dev/null 2>&1 || {
    echo "Python executable not found: $PYTHON" >&2
    exit 1
}

if [[ ! -x "$VENV/bin/python" ]]; then
    "$PYTHON" -m venv "$VENV"
fi

"$VENV/bin/python" -m pip install --upgrade pip setuptools wheel

if [[ -n "$TESTGRES_DIR" ]]; then
    TESTGRES_DIR=$(cd -- "$TESTGRES_DIR" && pwd)
    echo "==> Installing Testgres from $TESTGRES_DIR"
    "$VENV/bin/python" -m pip install -e "$TESTGRES_DIR"
fi

"$VENV/bin/python" -m pip install -e "$ROOT[test]"
"$VENV/bin/python" -m pip check
"$VENV/bin/python" "$ROOT/tools/verify_install.py"

cat <<DONE

Setup complete.

Virtual environment:
  $VENV

For integration tests:
  export PG_BIN=/path/to/postgres/bin
  export PGLAB_OS_USER=postgres
  export PGLAB_DB_USER=postgres
  export PGLAB_TEST_ROOT=/var/tmp

  ./scripts/doctor.sh
  ./scripts/run-smoke.sh
  ./scripts/run-tests.sh
DONE
