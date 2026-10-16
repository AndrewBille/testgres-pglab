#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
VENV=${VENV:-"$ROOT/.venv"}
PGLAB_TEST_ROOT=${PGLAB_TEST_ROOT:-/var/tmp}

fail=0
check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        printf 'OK   %-16s %s\n' "$1" "$(command -v "$1")"
    else
        printf 'FAIL %-16s missing\n' "$1"
        fail=1
    fi
}

for c in ip tc runuser findmnt iptables ping git; do
    check_cmd "$c"
done

if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    if grep -qw io /sys/fs/cgroup/cgroup.controllers; then
        echo "OK   cgroup           v2 with io controller"
    else
        echo "FAIL cgroup           v2 present, io controller unavailable"
        fail=1
    fi
elif [[ -d /sys/fs/cgroup/blkio ]]; then
    echo "OK   cgroup           v1/hybrid blkio"
else
    echo "FAIL cgroup           need cgroup v2 io or v1 blkio"
    fail=1
fi

# PgLab's automatic I/O throttling resolves the filesystem to a real block
# device.  tmpfs/overlay/network filesystems cannot be inferred for io.max.
probe="$PGLAB_TEST_ROOT"
while [[ ! -e "$probe" && "$probe" != / ]]; do
    probe=$(dirname "$probe")
done
storage=$(findmnt -n -o SOURCE,FSTYPE -T "$probe" 2>/dev/null || true)
source=${storage%% *}
fstype=${storage#* }
if [[ -n "$storage" && "$source" == /dev/* ]]; then
    printf 'OK   test storage     %s -> %s (%s)\n' "$PGLAB_TEST_ROOT" "$source" "$fstype"
else
    printf 'FAIL test storage     %s -> %s\n' "$PGLAB_TEST_ROOT" "${storage:-unknown}"
    echo "     cgroup I/O tests need a block-backed filesystem; set PGLAB_TEST_ROOT."
    fail=1
fi

if [[ -x "$VENV/bin/python" ]]; then
    "$VENV/bin/python" "$ROOT/tools/verify_install.py" || fail=1
else
    echo "FAIL venv             $VENV is missing; run ./setup.sh"
    fail=1
fi

if [[ -n ${PG_BIN:-} ]]; then
    for c in initdb pg_ctl postgres psql pg_basebackup; do
        if [[ -x "$PG_BIN/$c" ]]; then
            printf 'OK   PG %-13s %s\n' "$c" "$PG_BIN/$c"
        else
            printf 'FAIL PG %-13s missing under %s\n' "$c" "$PG_BIN"
            fail=1
        fi
    done
else
    echo "INFO PG_BIN           not set; PostgreSQL check skipped"
fi

exit "$fail"
