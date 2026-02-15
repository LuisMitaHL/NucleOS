#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Phase 00 — Create disk image, partition, create Btrfs subvols
# ─────────────────────────────────────────────────────────────

log "Creating raw disk image (${IMAGE_SIZE})..."
qemu-img create -f raw "${IMG_FILE}" "${IMAGE_SIZE}"

log "Setting up loop device..."
LOOP_DEV="$(losetup --find --show --partscan "${IMG_FILE}")"
export LOOP_DEV
log "  → ${LOOP_DEV}"

log "Partitioning (GPT: EFI + Linux)..."
parted -s "${LOOP_DEV}" \
    mklabel gpt \
    mkpart "EFI"  fat32  1MiB   "${EFI_SIZE}" \
    set 1 esp on \
    mkpart "root" btrfs  "${EFI_SIZE}" 100%

# Wait for partition devices to appear
sleep 1
partprobe "${LOOP_DEV}" 2>/dev/null || true
sleep 1

# ── Ensure partition nodes (fix for Docker/udev missing) ──────
ensure_partition_nodes() {
    local loop_name
    loop_name=$(basename "${LOOP_DEV}")

    for i in 1 2; do
        local part_dev="${LOOP_DEV}p${i}"
        local sys_dev="/sys/class/block/${loop_name}/${loop_name}p${i}/dev"

        if [ ! -b "${part_dev}" ] && [ -f "${sys_dev}" ]; then
            log "Creating partition node ${part_dev}..."
            local maj_min
            maj_min=$(cat "${sys_dev}")
            local maj=${maj_min%:*}
            local min=${maj_min#*:}
            mknod "${part_dev}" b "${maj}" "${min}"
        fi
    done
}
ensure_partition_nodes

EFI_PART="${LOOP_DEV}p1"
ROOT_PART="${LOOP_DEV}p2"

log "Formatting EFI partition (FAT32)..."
mkfs.vfat -F 32 -n "EFI" "${EFI_PART}"

log "Formatting root partition (Btrfs)..."
mkfs.btrfs -f -L "NucleOS" "${ROOT_PART}"

# ── Create Btrfs subvolumes ──────────────────────────────────
log "Creating Btrfs subvolumes..."
mount "${ROOT_PART}" "${ROOTFS}"

btrfs subvolume create "${ROOTFS}/@"
btrfs subvolume create "${ROOTFS}/@home"
btrfs subvolume create "${ROOTFS}/@snapshots"
btrfs subvolume create "${ROOTFS}/@var_log"
btrfs subvolume create "${ROOTFS}/@var_cache"

umount "${ROOTFS}"

# ── Mount subvolumes with compression ────────────────────────
log "Mounting subvolumes with compress=${BTRFS_COMPRESS}..."
MOUNT_OPTS="compress=${BTRFS_COMPRESS},noatime"

mount -o "subvol=@,${MOUNT_OPTS}"          "${ROOT_PART}" "${ROOTFS}"

mkdir -p "${ROOTFS}/home"
mkdir -p "${ROOTFS}/.snapshots"
mkdir -p "${ROOTFS}/var/log"
mkdir -p "${ROOTFS}/var/cache"
mkdir -p "${ROOTFS}/boot/efi"

mount -o "subvol=@home,${MOUNT_OPTS}"      "${ROOT_PART}" "${ROOTFS}/home"
mount -o "subvol=@snapshots,${MOUNT_OPTS}" "${ROOT_PART}" "${ROOTFS}/.snapshots"
mount -o "subvol=@var_log,${MOUNT_OPTS}"   "${ROOT_PART}" "${ROOTFS}/var/log"
mount -o "subvol=@var_cache,${MOUNT_OPTS}" "${ROOT_PART}" "${ROOTFS}/var/cache"

mount "${EFI_PART}" "${ROOTFS}/boot/efi"

log "Disk preparation complete."
