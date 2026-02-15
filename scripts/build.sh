#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# NucleOS — Main build orchestrator
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/build"

# Source configuration
# shellcheck source=../config/nucleos.conf
source "${BUILD_DIR}/config/nucleos.conf"

# ── Globals ──────────────────────────────────────────────────
export BUILD_DIR SCRIPT_DIR
export WORK="/tmp/nucleos-work"
export ROOTFS="${WORK}/rootfs"

DATE_STAMP="$(date +%Y%m%d)"
FINAL_NAME="${IMAGE_NAME}-debian13-${DATE_STAMP}"

# Create image directly in output folder to avoid copying
export IMG_FILE="${OUTPUT_DIR}/${FINAL_NAME}.img"
export LOOP_DEV=""

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║            NucleOS Image Builder                 ║"
    echo "║         Debian 13 (Trixie) — KDE Plasma         ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log()   { echo -e "${GREEN}[NucleOS]${NC} $*"; }
warn()  { echo -e "${RED}[NucleOS WARN]${NC} $*" >&2; }
die()   { echo -e "${RED}[NucleOS FATAL]${NC} $*" >&2; exit 1; }
phase() { echo -e "\n${CYAN}${BOLD}══════ Phase: $* ══════${NC}\n"; }

# ── Cleanup trap ─────────────────────────────────────────────
cleanup() {
    local exit_code=$?
    log "Cleaning up..."

    # Unmount chroot binds
    for mp in dev/pts dev proc sys run; do
        mountpoint -q "${ROOTFS}/${mp}" 2>/dev/null && umount -lf "${ROOTFS}/${mp}" || true
    done

    # Unmount subvolumes (reverse order)
    for mp in boot/efi var/cache var/log home .snapshots ""; do
        mountpoint -q "${ROOTFS}/${mp}" 2>/dev/null && umount -lf "${ROOTFS}/${mp}" || true
    done

    # Detach loop device
    if [[ -n "${LOOP_DEV}" ]] && losetup "${LOOP_DEV}" &>/dev/null; then
        losetup -d "${LOOP_DEV}" || true
    fi

    if [[ ${exit_code} -ne 0 ]]; then
        warn "Build FAILED (exit code ${exit_code})"
    fi
    exit "${exit_code}"
}
trap cleanup EXIT

# ── Run phases ───────────────────────────────────────────────
banner
mkdir -p "${WORK}" "${ROOTFS}" "${OUTPUT_DIR}"

# ── Ensure loop devices (fix for Docker) ─────────────────────
ensure_loop_devices() {
    if [ ! -e /dev/loop-control ]; then
        log "Creating /dev/loop-control..."
        mknod /dev/loop-control c 10 237
    fi

    for i in {0..7}; do
        if [ ! -b "/dev/loop${i}" ]; then
            log "Creating /dev/loop${i}..."
            mknod "/dev/loop${i}" b 7 "${i}"
        fi
    done
}
ensure_loop_devices

phase "00 — Prepare disk image"
source "${SCRIPT_DIR}/00-prepare.sh"

phase "01 — Debootstrap base system"
source "${SCRIPT_DIR}/01-debootstrap.sh"

phase "02 — Configure system"
source "${SCRIPT_DIR}/02-configure.sh"

phase "03 — Install packages"
source "${SCRIPT_DIR}/03-packages.sh"

phase "04 — Bootloader (GRUB + Secure Boot)"
source "${SCRIPT_DIR}/04-bootloader.sh"

phase "05 — Btrfs snapshots & rollback"
source "${SCRIPT_DIR}/05-snapshots.sh"

phase "06 — Customization"
source "${SCRIPT_DIR}/06-customize.sh"

phase "07 — Finalize image"
source "${SCRIPT_DIR}/07-finalize.sh"

echo ""
log "✅ Build complete! Image: ${OUTPUT_DIR}/${FINAL_NAME}.img"
log "   SHA256: $(cat "${OUTPUT_DIR}/${FINAL_NAME}.img.sha256")"
