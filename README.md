# NucleOS

NucleOS is a Debian disk image made from scratch for Carrera de Informática - UMSA.

---

## ✨ Features

| Feature | Details |
|---|---|
| **Desktop** | KDE Plasma 6 |
| **Filesystem** | Btrfs with `zstd:3` compression |
| **Secure Boot** | Full SB support. Avoid an insecure BIOS configuration |
| **Auto-resize** | First-boot `growpart` + `btrfs filesystem resize max` fills the target disk |
| **Browsers** | Firefox ESR (uBlock Origin pre-installed) + Google Chrome (uBlock Origin Lite pre-installed) |
| **Virtualisation** | VirtualBox 7.1 |

---

## Status:

- UEFI Boot: OK
- UEFI Secure Boot on real hardware: NOT TESTED
- Debian Boot: OK
- VirtualBox 7.1 modules: OK
- VirtualBox 7.1 VMs: NOT TESTED
- Google Chrome: OK
- Firefox ESR: OK
- uBlock Origin: OK
- uBlock Origin Lite: OK
- KDE Plasma 6: OK
- Auto-resize: OK
- Snapshot & Rollback: NOT TESTED
- Package cache: OK
- Custom wallpaper: NOT WORKING
- Autologin: OK
- Zramswap: OK
- Desktop icons: OK
- Hostname: NOT TESTED


## 📋 Requirements for building a image

- Docker Engine ≥ 24.0
- Docker Compose
- ~20 GB free disk space (image + cache)
- Linux host (the builder runs `--privileged`)

---

## 🚀 Quick Start

```bash
git clone <repo-url> nucleos && cd nucleos

cp /path/to/my-wallpaper.png assets/wallpaper.png

nano config/nucleos.conf

make build
```

If the image is compressed:

```bash
zstdcat output/nucleos-debian13-*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress
```

The first build downloads ~2 GB of packages. Subsequent builds reuse the `apt-cacher-ng` cache and finish much faster.

You can test the image directly with QEMU:

```bash
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd ./MY_VARS.fd
sudo qemu-system-x86_64 -enable-kvm -cpu host -m 2G \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=./MY_VARS.fd \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -drive file=output/nucleos-debian13-DATE.img,format=raw
```

---


## 🔄 Snapshot & Rollback (untested)

### Rolling Back

**From GRUB** — select _"NucleOS — Restore to Initial State"_ to boot into the original build snapshot.

**From running system:**

```bash
# Restore to the initial NucleOS state
sudo nucleos-restore
```

---

## 🔐 Secure Boot

The image ships with `shim-signed` and `grub-efi-amd64-signed`, following Debian's
official Secure Boot chain. The EFI partition contains:

- `EFI/BOOT/shimx64.efi` — Microsoft-signed shim
- `EFI/BOOT/BOOTX64.EFI` — removable-media fallback

This works out of the box on systems with Secure Boot enabled.

---

## 🖥️ Make Targets

```
make build        Build the NucleOS image
make clean        Remove output images
make shell        Open a shell in the builder container
make cache-clean  Purge the apt-cacher-ng cache volume
make down         Stop all services
```

---

## 📝 License

MIT
