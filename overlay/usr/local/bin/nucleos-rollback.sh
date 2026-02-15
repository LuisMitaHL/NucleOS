#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# NucleOS — Snapshot rollback helper
# Usage: sudo nucleos-rollback <snapshot-number>
#
# Lists available snapshots or performs a rollback to a
# specific snapshot number, then regenerates GRUB.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
    echo -e "${BOLD}NucleOS Rollback Tool${NC}"
    echo ""
    echo "Usage:"
    echo "  $(basename "$0")             List available snapshots"
    echo "  $(basename "$0") <number>    Rollback to snapshot <number>"
    echo ""
    echo "After rollback, reboot to apply changes."
}

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root.${NC}" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo -e "${CYAN}${BOLD}Available NucleOS Snapshots:${NC}"
    echo ""
    snapper -c root list
    echo ""
    echo -e "Use ${GREEN}$(basename "$0") <number>${NC} to rollback to a snapshot."
    exit 0
fi

SNAP_NUM="$1"

if ! [[ "${SNAP_NUM}" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: '${SNAP_NUM}' is not a valid snapshot number.${NC}" >&2
    usage
    exit 1
fi

echo -e "${CYAN}Rolling back to snapshot #${SNAP_NUM}...${NC}"

# Verify snapshot exists
if ! snapper -c root list | grep -q "^ *${SNAP_NUM} "; then
    echo -e "${RED}Error: Snapshot #${SNAP_NUM} not found.${NC}" >&2
    snapper -c root list
    exit 1
fi

# Perform rollback: create a writable snapshot from the target
# and set it as the default subvolume
echo "Creating writable copy of snapshot #${SNAP_NUM}..."
snapper -c root undochange "${SNAP_NUM}..0"

echo "Regenerating GRUB configuration..."
update-grub

echo ""
echo -e "${GREEN}${BOLD}Rollback to snapshot #${SNAP_NUM} complete!${NC}"
echo -e "Please ${BOLD}reboot${NC} to apply changes."
echo ""
echo -e "If you need to boot into a snapshot directly, select it from"
echo -e "the ${CYAN}NucleOS Snapshots${NC} submenu in GRUB."
