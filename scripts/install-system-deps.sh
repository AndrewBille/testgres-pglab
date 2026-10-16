#!/usr/bin/env bash
set -euo pipefail

as_root() {
    if [[ ${EUID} -eq 0 ]]; then
        "$@"
    else
        command -v sudo >/dev/null 2>&1 || {
            echo "sudo is required to install system packages" >&2
            exit 1
        }
        sudo "$@"
    fi
}

if command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates git \
        python3 python3-venv python3-pip python3-dev build-essential \
        iproute2 iputils-ping util-linux iptables nftables procps kmod
elif command -v dnf >/dev/null 2>&1; then
    # RHEL/Alma/Rocky split tc into iproute-tc.
    as_root dnf install -y \
        ca-certificates git \
        python3 python3-pip python3-devel gcc \
        iproute iproute-tc iputils util-linux iptables nftables procps-ng kmod
elif command -v yum >/dev/null 2>&1; then
    as_root yum install -y \
        ca-certificates git \
        python3 python3-pip python3-devel gcc \
        iproute iproute-tc iputils util-linux iptables nftables procps-ng kmod
elif command -v zypper >/dev/null 2>&1; then
    as_root zypper --non-interactive install \
        ca-certificates git \
        python3 python3-pip python3-devel gcc \
        iproute2 iputils util-linux iptables nftables procps kmod
else
    echo "Unsupported package manager." >&2
    echo "Install manually: git, python3+venv/pip, compiler/python headers," >&2
    echo "iproute2 (ip/tc), iputils-ping, util-linux (runuser/findmnt)," >&2
    echo "iptables/nftables, procps and kmod." >&2
    exit 1
fi

# Usually autoloaded, but doing it here makes a fresh VM less surprising.
as_root modprobe sch_netem 2>/dev/null || true
as_root modprobe br_netfilter 2>/dev/null || true
