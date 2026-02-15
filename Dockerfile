FROM debian:trixie

LABEL maintainer="NucleOS Project"
LABEL description="NucleOS Debian 13 image builder environment"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    btrfs-progs \
    ca-certificates \
    coreutils \
    curl \
    debootstrap \
    dosfstools \
    e2fsprogs \
    fdisk \
    gnupg \
    grub-efi-amd64-bin \
    grub-efi-amd64-signed \
    kmod \
    mtools \
    parted \
    qemu-utils \
    shim-signed \
    squashfs-tools \
    systemd-container \
    util-linux \
    wget \
    xorriso \
    xz-utils \
    zstd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY scripts/  /build/scripts/
COPY config/   /build/config/
COPY overlay/  /build/overlay/
COPY assets/   /build/assets/

RUN chmod +x /build/scripts/*.sh

ENTRYPOINT ["/build/scripts/build.sh"]
