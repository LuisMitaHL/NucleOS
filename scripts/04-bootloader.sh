#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Phase 04 — Install GRUB with Secure Boot support
# ─────────────────────────────────────────────────────────────

log "Installing GRUB bootloader (EFI + Secure Boot)..."

chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'

# Install GRUB to the EFI partition
grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --no-nvram \
    --recheck --removable

# Copy the signed shim + grub to the removable media path
# so the image boots on any UEFI system with Secure Boot on.
mkdir -p /boot/efi/EFI/BOOT

# shim-signed provides shimx64.efi (Microsoft-signed)
if [[ -f /usr/lib/shim/shimx64.efi.signed ]]; then
    cp /usr/lib/shim/shimx64.efi.signed /boot/efi/EFI/BOOT/BOOTX64.EFI
elif [[ -f /usr/lib/shim/shimx64.efi ]]; then
    cp /usr/lib/shim/shimx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
fi

# Copy the signed GRUB binary as the shim chainloads it
if [[ -f /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed ]]; then
    cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed /boot/efi/EFI/BOOT/grubx64.efi
fi

# Also set up in NucleOS directory
if [[ -f /usr/lib/shim/shimx64.efi.signed ]]; then
    cp /usr/lib/shim/shimx64.efi.signed /boot/efi/EFI/BOOT/shimx64.efi
fi

cat > /etc/default/grub << 'GRUBCFG'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="NucleOS"
GRUB_CMDLINE_LINUX_DEFAULT="root=LABEL=NucleOS rootflags=subvol=@,compress=zstd:3"
GRUB_CMDLINE_LINUX=""
GRUB_ENABLE_CRYPTODISK=n
GRUBCFG

# Generate grub.cfg
update-grub

CHROOTEOF

log "Bootloader installation complete."
