#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Phase 01 — Debootstrap the base Debian system
# ─────────────────────────────────────────────────────────────

DEBOOTSTRAP_MIRROR="${DEBIAN_MIRROR}"

# If apt-cacher-ng proxy is available, route through it
if [[ -n "${APT_PROXY}" ]]; then
    # Transform http://deb.debian.org/debian → http://apt-cache:3142/deb.debian.org/debian
    PROXY_HOST="${APT_PROXY#http://}"   # remove scheme
    PROXY_HOST="${PROXY_HOST%/}"        # remove trailing slash
    MIRROR_HOST="${DEBIAN_MIRROR#http://}"
    DEBOOTSTRAP_MIRROR="http://${PROXY_HOST}/${MIRROR_HOST}"
    log "Using apt-cacher-ng proxy: ${DEBOOTSTRAP_MIRROR}"
fi

log "Running debootstrap (${DEBIAN_SUITE}, amd64)..."
debootstrap \
    --arch=amd64 \
    --variant=minbase \
    --components="$(echo "${DEBIAN_COMPONENTS}" | tr ' ' ',')" \
    --include=apt-utils,locales,console-setup,sudo,systemd,dbus,wget,curl,ca-certificates,gnupg \
    "${DEBIAN_SUITE}" \
    "${ROOTFS}" \
    "${DEBOOTSTRAP_MIRROR}"

log "Debootstrap complete."
