# Product

Big Console exists so the personal fleet's pre-boot surfaces (systemd-boot
menu first of all) are readable on HiDPI panels without a resolution
switch — the console half of the workspace's flickerless-boot goal. The
driver is deliberately a small, conservative fork of edk2's
GraphicsConsoleDxe: upstream logic is preserved wherever it is not the
point of the fork (font, scaling, takeover, and conformance fixes).

Deployment rungs (see the workspace `docs/development/flickerless-boot.md`):
ESP drop-in for stock-firmware machines (live, via ch-boot-integrity's
`espDrivers`), `Driver####` NVRAM, and baking into ch-firmware ROMs.
