#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Phase 02 — Configure base system inside chroot
# ─────────────────────────────────────────────────────────────

# ── Mount pseudo-filesystems for chroot ──────────────────────
mount --bind /dev     "${ROOTFS}/dev"
mount --bind /dev/pts "${ROOTFS}/dev/pts"
mount -t proc  proc   "${ROOTFS}/proc"
mount -t sysfs sysfs  "${ROOTFS}/sys"
mount -t tmpfs tmpfs   "${ROOTFS}/run"

# ── Resolve nameserver inside chroot ─────────────────────────
cp /etc/resolv.conf "${ROOTFS}/etc/resolv.conf" 2>/dev/null || \
    echo "nameserver 8.8.8.8" > "${ROOTFS}/etc/resolv.conf"

# ── APT sources ──────────────────────────────────────────────
log "Configuring APT sources..."
cat > "${ROOTFS}/etc/apt/sources.list" << EOF
deb http://deb.debian.org/debian ${DEBIAN_SUITE} ${DEBIAN_COMPONENTS}
deb http://deb.debian.org/debian ${DEBIAN_SUITE}-updates ${DEBIAN_COMPONENTS}
deb http://security.debian.org/debian-security ${DEBIAN_SUITE}-security ${DEBIAN_COMPONENTS}
EOF

# Set apt proxy for build time (will be removed in finalize)
if [[ -n "${APT_PROXY}" ]]; then
    log "Setting build-time APT proxy..."
    cat > "${ROOTFS}/etc/apt/apt.conf.d/01proxy" << EOF
Acquire::http::Proxy "${APT_PROXY}";
EOF
fi

# ── Chroot configuration ────────────────────────────────────
log "Configuring hostname, locale, timezone..."
chroot "${ROOTFS}" /bin/bash -e << CHROOTEOF

# Hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME}
::1         localhost ip6-localhost ip6-loopback
HOSTS

# Locale
sed -i "s/^# *${LOCALE}/${LOCALE}/" /etc/locale.gen 2>/dev/null || \
    echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG="${LOCALE}"

# Timezone
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
echo "${TIMEZONE}" > /etc/timezone

# Console
echo 'KEYMAP="${KEYMAP}"' > /etc/vconsole.conf

CHROOTEOF

# ── fstab with Btrfs subvolumes ──────────────────────────────
log "Generating /etc/fstab..."

# Get the UUID of the root Btrfs partition
ROOT_UUID="$(blkid -s UUID -o value "${LOOP_DEV}p2")"
EFI_UUID="$(blkid -s UUID -o value "${LOOP_DEV}p1")"

cat > "${ROOTFS}/etc/fstab" << EOF
# <file system>                           <mount point>   <type>  <options>                                    <dump> <pass>
UUID=${ROOT_UUID}  /               btrfs   subvol=@,compress=${BTRFS_COMPRESS},noatime          0      0
UUID=${ROOT_UUID}  /home           btrfs   subvol=@home,compress=${BTRFS_COMPRESS},noatime      0      0
UUID=${ROOT_UUID}  /.snapshots     btrfs   subvol=@snapshots,compress=${BTRFS_COMPRESS},noatime 0      0
UUID=${ROOT_UUID}  /var/log        btrfs   subvol=@var_log,compress=${BTRFS_COMPRESS},noatime   0      0
UUID=${ROOT_UUID}  /var/cache      btrfs   subvol=@var_cache,compress=${BTRFS_COMPRESS},noatime 0      0
UUID=${EFI_UUID}   /boot/efi       vfat    umask=0077                                           0      1
tmpfs              /tmp            tmpfs   defaults,noatime,mode=1777                            0      0
EOF

# ── Create user ──────────────────────────────────────────────
log "Creating default user '${DEFAULT_USER}'..."
chroot "${ROOTFS}" /bin/bash -e << CHROOTEOF

# Set root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Create user
useradd -m -s /bin/bash -G sudo,adm,cdrom,audio,video,plugdev "${DEFAULT_USER}"
echo "${DEFAULT_USER}:${DEFAULT_PASSWORD}" | chpasswd

# Allow sudo without password (user can change later)
echo "${DEFAULT_USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/nucleos
chmod 440 /etc/sudoers.d/nucleos

CHROOTEOF

log "System configuration complete."
