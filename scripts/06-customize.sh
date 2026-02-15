#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Phase 06 — Customization: wallpaper, browser policies, overlay
# ─────────────────────────────────────────────────────────────

# ── Copy overlay tree ────────────────────────────────────────
log "Installing overlay files..."
if [[ -d "${BUILD_DIR}/overlay" ]]; then
    cp -a "${BUILD_DIR}/overlay/." "${ROOTFS}/"
fi

# Set permissions on scripts
chmod +x "${ROOTFS}/usr/local/bin/nucleos-firstboot.sh" 2>/dev/null || true
chmod +x "${ROOTFS}/usr/local/bin/nucleos-restore"     2>/dev/null || true

# ── Enable first-boot service ────────────────────────────────
log "Enabling first-boot service..."
chroot "${ROOTFS}" systemctl enable nucleos-firstboot.service 2>/dev/null || true

# ── Custom wallpaper ─────────────────────────────────────────
log "Installing custom wallpaper..."
WALLPAPER_DEST_DIR="${ROOTFS}/usr/share/wallpapers/NucleOS/contents/images"
mkdir -p "${WALLPAPER_DEST_DIR}"

if [[ -f "${BUILD_DIR}/assets/wallpaper.png" ]]; then
    cp "${BUILD_DIR}/assets/wallpaper.png" "${WALLPAPER_DEST_DIR}/3840x2160.png"
    # Also copy at common resolutions
    cp "${BUILD_DIR}/assets/wallpaper.png" "${WALLPAPER_DEST_DIR}/1920x1080.png"
    log "  → Custom wallpaper installed"
else
    log "  → No custom wallpaper found in assets/, using NucleOS default"
    # Generate a simple placeholder SVG-like wallpaper info
fi

# Wallpaper metadata for KDE
cat > "${ROOTFS}/usr/share/wallpapers/NucleOS/metadata.json" << 'WPJSON'
{
    "KPlugin": {
        "Id": "NucleOS",
        "Name": "NucleOS",
        "Authors": [{ "Name": "NucleOS Project" }]
    }
}
WPJSON

# ── Set KDE default wallpaper ────────────────────────────────
log "Setting NucleOS as default KDE wallpaper..."
mkdir -p "${ROOTFS}/etc/xdg"
cat > "${ROOTFS}/etc/xdg/plasmarc" << 'PLASMARC'
[Theme]
name=default

[Wallpapers]
defaultWallpaperTheme=NucleOS
defaultFileSuffix=.png
defaultWidth=1920
defaultHeight=1080
PLASMARC

# Also set it via a look-and-feel default
mkdir -p "${ROOTFS}/etc/skel/.config"
cat > "${ROOTFS}/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'APPSRC'
# Combined default Plasma config: desktop wallpaper + panel with pinned Firefox
# Containment 1 = Desktop (wallpaper)
[Containments][1]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.desktopcontainment
wallpaperplugin=org.kde.image

[Containments][1][Wallpaper][org.kde.image][General]
# explicit file URI to the wallpaper image (must exist in the runtime FS)
Image=file:///usr/share/wallpapers/NucleOS/contents/images/1920x1080.png
# FillMode: 0=Scaled, 1=Centered, 2=KeepAspectCrop (common choice)
FillMode=2

# Containment 2 = Panel (taskbar) with pinned app(s)
[Containments][2]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel

# Add Applet index 2 as the task manager (this index is arbitrary but consistent)
[Containments][2][Applets][2]
plugin=org.kde.plasma.taskmanager

[Containments][2][Applets][2][Configuration][General]
# Pin the Debian-packaged launcher for Firefox ESR
launchers=applications:firefox-esr.desktop
APPSRC

# ── Ensure browser policy directories exist ──────────────────
log "Verifying browser policy files..."
mkdir -p "${ROOTFS}/etc/firefox/policies"
mkdir -p "${ROOTFS}/etc/opt/chrome/policies/managed"

# Firefox policies.json should already be in overlay
if [[ -f "${ROOTFS}/etc/firefox/policies/policies.json" ]]; then
    log "  → Firefox uBlock Origin policy: OK"
else
    warn "  → Firefox policy file missing!"
fi

# Chrome managed policy should already be in overlay
if [[ -f "${ROOTFS}/etc/opt/chrome/policies/managed/nucleos-extensions.json" ]]; then
    log "  → Chrome uBlock Origin Lite policy: OK"
else
    warn "  → Chrome policy file missing!"
fi


mkdir -p "${ROOTFS}/etc/sddm.conf.d"

log "Setting autologin for user nucleos..."

cat > "${ROOTFS}/etc/sddm.conf.d/autologin.conf" <<'EOF'
[Autologin]
User=nucleos
Session=plasma
Relogin=false
EOF

log "Setting zramswap..."

cat > "${ROOTFS}/etc/default/zramswap" <<'EOF'
ALGO=zstd
PERCENT=60
EOF

log "Copying icons from Firefox, Chrome and Virtualbox to the desktop..."
mkdir -p "${ROOTFS}/home/nucleos/Escritorio/"
cp "${ROOTFS}/usr/share/applications/virtualbox.desktop" "${ROOTFS}/home/nucleos/Escritorio/"
cp "${ROOTFS}/usr/share/applications/google-chrome.desktop" "${ROOTFS}/home/nucleos/Escritorio/"
cp "${ROOTFS}/usr/share/applications/firefox-esr.desktop" "${ROOTFS}/home/nucleos/Escritorio/"
chmod +x "${ROOTFS}/home/nucleos/Escritorio/virtualbox.desktop"
chmod +x "${ROOTFS}/home/nucleos/Escritorio/google-chrome.desktop"
chmod +x "${ROOTFS}/home/nucleos/Escritorio/firefox-esr.desktop"
chown -R 1000:1000 "${ROOTFS}/home/nucleos"

log "Setting hostname to dhcp..."
mkdir -p "${ROOTFS}/etc/NetworkManager/conf.d"

cat > "${ROOTFS}/etc/NetworkManager/conf.d/10-dhcp-hostname.conf" <<'EOF'
[main]
hostname-mode=dhcp
EOF

log "Disabling suspend, hibernate and lock on idle..."

# 1) systemd: make system ignore idle action (no suspend/hibernate/lock)
mkdir -p "${ROOTFS}/etc/systemd"
# Ensure logind config dir exists and write override
mkdir -p "${ROOTFS}/etc/systemd/logind.conf.d"
cat > "${ROOTFS}/etc/systemd/logind.conf.d/disable-idle.conf" <<'EOF'
[Login]
# Do not perform any action on idle (inactivity)
IdleAction=ignore
# Consider idle only when user session is truly inactive; keep default timeout
# IdleActionSec=30min   # leave default or set to large value if you prefer
EOF
chmod 0644 "${ROOTFS}/etc/systemd/logind.conf.d/disable-idle.conf"
log "Wrote /etc/systemd/logind.conf.d/disable-idle.conf"

# 2) KDE: disable KScreenLocker systemwide and for new users via /etc/skel
# Systemwide config so Plasma picks it up even when user config missing
mkdir -p "${ROOTFS}/etc/xdg"
cat > "${ROOTFS}/etc/xdg/kscreenlockerrc" <<'EOF'
[Daemon]
# Do not automatically lock the session
Autolock=false
# Don't lock when resuming from suspend/hibernate
LockOnResume=false
# Disable the locker (some KDE builds respect this)
Enable=false
# locker mode: 0 = default
LockerMode=0

[Greeter]
# no greeter by default
EOF
chmod 0644 "${ROOTFS}/etc/xdg/kscreenlockerrc"
log "Wrote systemwide /etc/xdg/kscreenlockerrc"

# Also put the same file into /etc/skel/.config so all new users start unlocked
mkdir -p "${ROOTFS}/etc/skel/.config"
cat > "${ROOTFS}/etc/skel/.config/kscreenlockerrc" <<'EOF'
[Daemon]
Autolock=false
LockOnResume=false
Enable=false
LockerMode=0
EOF
chmod 0644 "${ROOTFS}/etc/skel/.config/kscreenlockerrc"
log "Wrote /etc/skel/.config/kscreenlockerrc"


log "Customization complete."
