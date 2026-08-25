#!/usr/bin/env bash
# /home/operator/agent_workspace/audit_security_invariants.sh
# Automated Kernel Invariant Audit Pipeline for Sovereign Computing Verification

set -euo pipefail

MACHINE_NAME="local_agent"
ROOTFS_DIR="/var/lib/machines/local_agent_root"
SANDBOX_IO_DIR="/home/operator/agent_workspace/sandbox_io"

echo "=== STARTING KERNEL INVARIANT AUDIT FOR: ${MACHINE_NAME} ==="
# Test 1: Verify Process Namespace and User ID Mapping# The agent process inside the container must never execute under host UID 0 or host UID 1000
echo -n "[*] Checking user namespace separation... "
CONTAINER_PIDS=$(pgrep -f "secure_agent_loop.py" || true)if [ -z "${CONTAINER_PIDS}" ]; then
    echo "FAIL: Isolated agent runner process is not currently executing."
    exit 1fi
for PID in ${CONTAINER_PIDS}; do
    HOST_UID=$(ps -o uid= -p "${PID}" | tr -d ' ')
    # Check if the process accidentally maps to standard system privileges
    if [ "${HOST_UID}" -eq 0 ] || [ "${HOST_UID}" -eq 1000 ]; then
        echo "FAIL: Process running under unsafe host UID: ${HOST_UID}!"
        exit 1
    fidone
echo "PASS (Agent process is correctly isolated inside an unprivileged namespace)."
# Test 2: Verify Network Adapter Isolation# The network namespace inside the container must contain only the loopback device
echo -n "[*] Verifying network segmentation... "
NETWORK_INTERFACES=$(sudo systemd-run --machine="${MACHINE_NAME}" --quiet ip -br link show | awk '{print $1}')
INTERFACE_COUNT=$(echo "${NETWORK_INTERFACES}" | wc -l)if [ "${INTERFACE_COUNT}" -ne 1 ] || [ "${NETWORK_INTERFACES}" != "lo" ]; then
    echo "FAIL: External network adapters are accessible inside the container namespace!"
    exit 1fi
echo "PASS (Container network namespace is completely air-gapped)."
# Test 3: Verify Root Filesystem Immutability# The agent container must reject any direct write actions to its system root folders
echo -n "[*] Testing filesystem write protection... "
WRITE_TEST=$(sudo systemd-run --machine="${MACHINE_NAME}" --quiet touch /usr/bin/test_file 2>&1 || true)if [[ ! "${WRITE_TEST}" == *"Read-only file system"* ]]; then
    echo "FAIL: Container root filesystem allows write actions!"
    exit 1fi
echo "PASS (System root paths are securely mounted as read-only)."

echo "=== ALL SECURITY INVARIANTS VERIFIED SUCCESSFULLY ==="
