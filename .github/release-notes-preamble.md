Prebuilt UEFI drivers, for use without Nix.

| Artifact | Cell size | For |
|---|---|---|
| `bigconsolex64.efi` | 16x32 | The embedded font at its native size |
| `bigconsole2xx64.efi` | 32x64 | Panels or viewing distances where 16x32 reads small |

Verify a download against `SHA256SUMS` before installing it.

## Installing

The quickest path is the systemd-boot drop-in: copy one of the artifacts
to `EFI/systemd/drivers/` on your EFI System Partition, keeping the
`x64.efi` filename suffix, which systemd-boot requires. The driver takes
the console over when it loads, so nothing else needs configuring.

The other load paths (a `Driver####` NVRAM entry, or `load` from a UEFI
shell) work the same way. See the README for details.

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
