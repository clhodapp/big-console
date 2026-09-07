Prebuilt UEFI drivers, for use without Nix.

| Artifact | Cell size | For |
|---|---|---|
| `bigconsolex64.efi` | 16x32 | The embedded font at its native size |
| `bigconsole2xx64.efi` | 32x64 | Panels or viewing distances where 16x32 reads small |

Verify a download against `SHA256SUMS` before installing it.

## Supported platforms

x86-64 UEFI. The driver is verified on every change against TianoCore
edk2 (OVMF in QEMU at 3840x2160, both variants, loaded from the UEFI
shell) and is in use on one AMI Aptio V firmware, loaded by
systemd-boot. Firmware early-loading (a `Driver####` entry) has not been
exercised on real hardware. Other vendors' firmware should work by the
UEFI driver-binding rules the console takeover relies on, but has not
been tried. There is no AArch64 build yet.

From the moment it loads, everything that writes through Simple Text
Output renders big: systemd-boot, the UEFI shell, GRUB in `console`
mode, rEFInd in text mode, iPXE, shim and MokManager, and whatever those
chainload. Programs that draw their own pixels (GRUB `gfxterm`, rEFInd's
graphical mode, Limine, Windows Boot Manager) and the Linux console
after boot are unaffected.

## Provenance

The artifacts are the store paths the repository's CI built and pushed
to its binary cache for the tagged commit, copied out and renamed; they
are byte-identical to what `nix build .#big-console-dxe` (or
`-2x`) produces at that tag, which is one way to check a download
beyond `SHA256SUMS`.

## Installing

The quickest path is the systemd-boot drop-in: copy one of the artifacts
to `EFI/systemd/drivers/` on your EFI System Partition, keeping the
`x64.efi` filename suffix, which systemd-boot requires. The driver takes
the console over when it loads, so nothing else needs configuring.

rEFInd loads it from its `drivers_x64` directory, and a UEFI shell on
`load`. A `Driver####` NVRAM entry makes the firmware load it before its
own screens; that path is untested on real hardware. See the README for
details.

## Secure Boot

If Secure Boot is enabled, the driver must be signed by a key your
platform's signature database trusts, or the firmware will skip it and
boot with the stock console. Signing with your own db key:

```
sbsign --key db.key --cert db.crt \
  --output bigconsolex64.efi bigconsolex64.efi
```

A skipped driver is not fatal. Boot proceeds; the console is just the
small one again.
