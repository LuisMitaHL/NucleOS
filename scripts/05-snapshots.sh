#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Phase 05 — Configure Btrfs snapshots & rollback
# ─────────────────────────────────────────────────────────────

log "Configuring snapper for Btrfs snapshots..."

chroot "${ROOTFS}" /bin/bash -e << 'CHROOTEOF'

# ── Snapper config for root ──────────────────────────────────
# We manually configure snapper below, avoiding 'create-config'
# which tries to create /.snapshots (already mounted).

# ── Snapper settings ────────────────────────────────────────
# Adjust retention policy
mkdir -p /etc/snapper/configs
cat > /etc/snapper/configs/root << 'SNAPCFG'
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""

# Timeline snapshots
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="2"
TIMELINE_LIMIT_YEARLY="0"

# Number snapshots (apt hooks)
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="5"

# Permissions
ALLOW_USERS=""
ALLOW_GROUPS=""
SYNC_ACL="no"

# Empty pre-post cleanup
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
SNAPCFG

# Ensure snapper knows about this config
sed -i 's/^SNAPPER_CONFIGS=.*/SNAPPER_CONFIGS="root"/' /etc/default/snapper 2>/dev/null || \
    echo 'SNAPPER_CONFIGS="root"' > /etc/default/snapper

# ── Enable snapper timers ────────────────────────────────────
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

CHROOTEOF

# ── Install apt hooks for pre/post snapshots ─────────────────
log "Installing apt snapshot hooks..."
cat > "${ROOTFS}/etc/apt/apt.conf.d/80snapper" << 'APTSNAP'
DPkg::Pre-Invoke  { "if [ -x /usr/bin/snapper ]; then snapper --no-dbus -c root create -d 'apt pre' --type pre --print-number > /tmp/.snapper-apt-pre-num; fi"; };
DPkg::Post-Invoke { "if [ -x /usr/bin/snapper ] && [ -f /tmp/.snapper-apt-pre-num ]; then snapper --no-dbus -c root create -d 'apt post' --type post --pre-number $(cat /tmp/.snapper-apt-pre-num); rm -f /tmp/.snapper-apt-pre-num; fi"; };
APTSNAP

log "Snapshot configuration complete."
