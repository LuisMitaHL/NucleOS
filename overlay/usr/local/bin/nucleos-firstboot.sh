#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# NucleOS — First-boot script
# Resizes the root partition to fill the disk and creates
# the initial "factory" Btrfs snapshot.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

LOG_TAG="nucleos-firstboot"

log() { echo "$*" | systemd-cat -t "${LOG_TAG}"; echo "[${LOG_TAG}] $*"; }

MARKER="/var/lib/nucleos/firstboot-done"
if [[ -f "${MARKER}" ]]; then
    log "First boot already completed, skipping."
    exit 0
fi

# ── Detect root device ───────────────────────────────────────
ROOT_DEV="$(findmnt -n -o SOURCE /)"
# Extract the partition device (e.g., /dev/sda2, /dev/nvme0n1p2)
PART_DEV="$(echo "${ROOT_DEV}" | sed 's/\[.*\]//')"

# Determine the parent disk and partition number
if [[ "${PART_DEV}" =~ ^(/dev/nvme[0-9]+n[0-9]+)p([0-9]+)$ ]]; then
    DISK="${BASH_REMATCH[1]}"
    PARTNUM="${BASH_REMATCH[2]}"
elif [[ "${PART_DEV}" =~ ^(/dev/[a-z]+)([0-9]+)$ ]]; then
    DISK="${BASH_REMATCH[1]}"
    PARTNUM="${BASH_REMATCH[2]}"
else
    log "WARNING: Could not determine disk layout from ${PART_DEV}, skipping resize."
    DISK=""
    PARTNUM=""
fi

# ── Resize partition ─────────────────────────────────────────
if [[ -n "${DISK}" && -n "${PARTNUM}" ]]; then
    log "Expanding partition ${PART_DEV} to fill ${DISK}..."
    if command -v growpart &>/dev/null; then
        growpart "${DISK}" "${PARTNUM}" || log "growpart: partition may already be at max size"
    else
        log "WARNING: growpart not found, skipping partition resize"
    fi

    # ── Resize Btrfs filesystem ──────────────────────────────
    log "Resizing Btrfs filesystem to maximum..."
    btrfs filesystem resize max /
    log "Filesystem resize complete."
else
    log "Skipping resize (unknown disk layout)."
fi

# ── Create factory snapshot ──────────────────────────────────
log "Creating factory snapshot..."
if command -v snapper &>/dev/null; then
    snapper -c root create \
        --description "NucleOS Factory — initial state" \
        --cleanup-algorithm "number" \
        --type single \
        || log "WARNING: snapper create failed (non-fatal)"
    log "Factory snapshot created."
else
    log "WARNING: snapper not found, skipping factory snapshot."
fi

# ── Rebuild VirtualBox kernel modules ────────────────────────
log "Rebuilding VirtualBox kernel modules..."
if command -v vboxconfig &>/dev/null; then
    /sbin/vboxconfig || log "WARNING: vboxconfig failed (VirtualBox may not work)"
    log "VirtualBox kernel modules rebuilt."
else
    log "WARNING: vboxconfig not found, skipping VirtualBox module rebuild."
fi

# ── Mark first boot as done ──────────────────────────────────
mkdir -p "$(dirname "${MARKER}")"
touch "${MARKER}"
log "First boot tasks complete."
