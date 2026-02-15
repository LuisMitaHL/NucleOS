#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Phase 07 — Finalize: clean up, unmount, compress
# ─────────────────────────────────────────────────────────────

# ── Create initial snapshot ──────────────────────────────────
log "Creating initial NucleOS snapshot..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'
snapper --no-dbus -c root create -d "NucleOS initial" --type single
CHROOTEOF

# ── GRUB rollback menu entry ────────────────────────────────
log "Adding GRUB rollback menu entry..."
cat > "${ROOTFS}/etc/grub.d/45_nucleos-rollback" << 'GRUBENTRY'
#!/bin/sh
set -e

. /usr/lib/grub/grub-mkconfig_lib

ROOT_UUID=$(grub-probe --target=fs_uuid /)

cat << EOF
menuentry "NucleOS — Restore to Initial State" --class recovery {
    insmod btrfs
    search --no-floppy --fs-uuid --set=root ${ROOT_UUID}
    linux /@snapshots/1/snapshot/vmlinuz root=UUID=${ROOT_UUID} rootflags=subvol=@snapshots/1/snapshot ro quiet splash
    initrd /@snapshots/1/snapshot/initrd.img
}
EOF
GRUBENTRY
chmod +x "${ROOTFS}/etc/grub.d/45_nucleos-rollback"

# Regenerate grub.cfg to include the rollback entry
chroot "${ROOTFS}" update-grub

# ── Clean up inside chroot ───────────────────────────────────
log "Cleaning up chroot environment..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'

# Remove build-time apt proxy
rm -f /etc/apt/apt.conf.d/01proxy

# Clean apt caches
apt-get clean
rm -rf /var/lib/apt/lists/*

# Clear machine-id so it regenerates on first boot
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Clear logs
find /var/log -type f -exec truncate -s 0 {} \;

# Clear temp
rm -rf /tmp/* /var/tmp/*

# Remove bash history
rm -f /root/.bash_history
rm -f /home/*/.bash_history

CHROOTEOF

# ── Unmount chroot pseudo-filesystems ────────────────────────
log "Unmounting chroot filesystems..."
for mp in dev/pts dev proc sys run; do
    mountpoint -q "${ROOTFS}/${mp}" && umount -lf "${ROOTFS}/${mp}" || true
done

# ── Unmount Btrfs subvolumes ────────────────────────────────
log "Unmounting Btrfs subvolumes..."
for mp in boot/efi var/cache var/log home .snapshots; do
    mountpoint -q "${ROOTFS}/${mp}" && umount -lf "${ROOTFS}/${mp}" || true
done
umount -lf "${ROOTFS}" || true

# ── Detach loop device ──────────────────────────────────────
log "Detaching loop device..."
if [[ -n "${LOOP_DEV}" ]]; then
    losetup -d "${LOOP_DEV}" || true
    LOOP_DEV=""  # prevent cleanup trap from trying again
fi

# ── Compress image ───────────────────────────────────────────
log "Compressing image with zstd (image already in output directory)..."
cd "${OUTPUT_DIR}"
#zstd -T0 -3 --rm "${FINAL_NAME}.img" --force

# Image is already in output directory, compressed in place
# The --rm flag removes the original .img file after compression

# ── Checksum ─────────────────────────────────────────────────
log "Generating SHA256 checksum..."
sha256sum "${FINAL_NAME}.img" > "${FINAL_NAME}.img.sha256"

log "Finalization complete."
log "  Image: ${OUTPUT_DIR}/${FINAL_NAME}.img"
log "  Size:  $(du -h "${FINAL_NAME}.img" | cut -f1)"
