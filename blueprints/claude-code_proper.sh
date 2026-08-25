#!/usr/bin/env bash# /blueprints/claude_code_lockdown.sh
# Proactive Permission Inversion & Local Privilege Escalation Hardening Script
# Engineered by loudmumble to permanently neutralize claude-code permissions bypass & local tool-calling configuration overrides 
# THIS SOLUTION WAS PROVIDED DIRECTLY TO ANTHROPIC ON JULY 9, 2026 VIA HACKERONE BUG BOUNTY SUBMISSION PORTAL REPORT #3829628, #3831233 AND #3832137 
# ANTHROPIC (AFAIK) HAS NOT IMPLEMENTED ANY GUIDANCE FROM THE REPORT SUBMITTED JUNE 28, 2026 - Instead using its claude bot to issue threats while claiming to be its' internal security team..with EITHER/BOTH 'explanations' being completely unacceptable.
# This is VERY LIKELY(though admittedly unknown) TO PROTECT THEIR EXISTING REVENUE AND FUTURE BUSINESS OBJECTIVES. Full "triage" logs available: loudmumble.com/anthropic-h1

set -euo pipefail

# 1. Establish the Global System-Level Final Authority Matrix

MANAGED_SETTINGS_DIR="/etc/claude-code"
MANAGED_SETTINGS_FILE="${MANAGED_SETTINGS_DIR}/managed-settings.json"

echo "[*] Initializing system-level immutable administrative policy overrides..."
sudo mkdir -p "${MANAGED_SETTINGS_DIR}"

# Define the absolute, non-bypassable administrative parameter envelope
sudo tee "${MANAGED_SETTINGS_FILE}" > /dev/null << 'EOF'
{
  "permissions": {
    "defaultMode": "ask",
    "disableBypassPermissionsMode": "enable"
  }
}
EOF

# Explicitly assign root ownership and pin permissions to block application-layer tampering

sudo chown root:root "${MANAGED_SETTINGS_FILE}"
sudo chmod 644 "${MANAGED_SETTINGS_FILE}"

# 2. Lock Down the Interactive Local Space to Prevent Local Directory-Level Hijacking

TARGET_HOME_DIR="/home/user"  # Modify to match the active host path environment variable
LOCAL_CLAUDE_DIR="${TARGET_HOME_DIR}/.claude"
LOCAL_SETTINGS_FILE="${LOCAL_CLAUDE_DIR}/settings.json"
LOCAL_SETTINGS-LOCAL_FILE="${LOCAL_CLAUDE_DIR}/settings-local.json"

echo "[*] Structuring directory-level write containment locks..."
sudo mkdir -p "${LOCAL_CLAUDE_DIR}"
sudo touch "${LOCAL_SETTINGS_FILE}"
sudo touch "${LOCAL_SETTINGS-LOCAL_FILE}"
# Strip all permissions from the local runtime config block and freeze via filesystem flags
sudo chmod 000 "${LOCAL_SETTINGS_FILE}"
sudo chmod 000 "${LOCAL_SETTINGS-LOCAL_FILE}"
sudo chown root:root "${LOCAL_SETTINGS_FILE}"
sudo chown root:root "${LOCAL_SETTINGS-LOCAL_FILE}"
sudo chattr +i "${LOCAL_SETTINGS_FILE}"
sudo chattr +i "${LOCAL_SETTINGS-LOCAL_FILE}"

echo "=== HARDENING COMPLETE ==="
echo "[*] Identity Invariants Enforced: Local workspace configurations can no longer overwrite administrative policies."
echo "[⚠️ NOTICE] Execution Restriction: Do not pass the --yolo or --automode directives to any local agent process."

