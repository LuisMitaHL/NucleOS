#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Phase 03 — Install packages.
# ─────────────────────────────────────────────────────────────

log "Updating package index..."
chroot "${ROOTFS}" apt-get update

log "Installing kernel and firmware..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    linux-headers-amd64 \
    firmware-linux \
    firmware-misc-nonfree \
    intel-microcode \
    amd64-microcode \
    zstd
CHROOTEOF

log "Installing KDE Plasma desktop (this may take a while)..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    task-kde-desktop \
    sddm \
    kde-plasma-desktop \
    plasma-workspace \
    plasma-nm \
    plasma-pa \
    konsole \
    dolphin \
    ark \
    kde-spectacle \
    kde-config-sddm \
    xdg-utils \
    xdg-user-dirs
CHROOTEOF

log "Installing system utilities..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    btrfs-progs \
    cloud-guest-utils \
    network-manager \
    pipewire \
    pipewire-pulse \
    wireplumber \
    efibootmgr \
    grub-efi-amd64-signed \
    shim-signed \
    os-prober \
    dkms \
    build-essential \
    git \
    nano \
    htop \
    bash-completion \
    zram-tools \
    fwupd \
    fwupd-amd64-signed \
    smartmontools \
    hw-probe
CHROOTEOF

log "Installing Firefox ESR..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'
DEBIAN_FRONTEND=noninteractive apt-get install -y firefox-esr
CHROOTEOF

log "Adding Google Chrome repository and installing..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg

cat > /etc/apt/sources.list.d/google-chrome.list << REPO
deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main
REPO

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y google-chrome-stable
CHROOTEOF

log "Adding VirtualBox repository and installing..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'
curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc \
    | gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox-2016.gpg

cat > /etc/apt/sources.list.d/virtualbox.list << REPO
deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian trixie contrib
REPO

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-7.1

usermod -aG vboxusers nucleos || true
CHROOTEOF


log "Installing snapshot tools..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    snapper
CHROOTEOF

log "Enabling services..."
chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'
systemctl enable sddm
systemctl enable NetworkManager
CHROOTEOF

log "Package installation complete."
