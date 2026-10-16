#!/usr/bin/env bash
set -euo pipefail

PGLAB_TEST_ROOT=${PGLAB_TEST_ROOT:-/var/tmp}

if [[ ${EUID} -eq 0 ]]; then
    SUDO=()
else
    SUDO=(sudo)
fi

while read -r ns _; do
    [[ $ns == pglab-* ]] || continue
    echo "removing netns $ns"
    "${SUDO[@]}" ip netns del "$ns" 2>/dev/null || true
done < <("${SUDO[@]}" ip netns list 2>/dev/null || true)

"${SUDO[@]}" ip link del pglab0 2>/dev/null || true
"${SUDO[@]}" rm -rf /tmp/testgres-pglab /tmp/testgres-pglab-tmp

# Known bundle test directories.  Limit deletion to PgLab-specific names.
for pattern in \
    'pglab-smoke' \
    'pglab-pytest-*' \
    'pglab-faults-*' \
    'pglab-netem-*' \
    'pglab-netem-effects-*' \
    'pglab-frozen-close-*' \
    'pglab-boom-*' \
    'pglab-same-*'; do
    "${SUDO[@]}" find "$PGLAB_TEST_ROOT" -maxdepth 1 -type d -name "$pattern" \
        -exec rm -rf -- {} + 2>/dev/null || true
done

echo "PgLab leftovers cleaned (best effort)."
