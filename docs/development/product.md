# Product

Big Console exists so that pre-boot text surfaces, the systemd-boot menu
first of all, are readable on HiDPI panels without switching the display
out of its native resolution. Dropping to a low-resolution text mode is
the usual workaround, and it costs a mode change (and the accompanying
flicker) on the way into the operating system. Replacing the console's
renderer avoids that: the framebuffer stays where it is and the glyphs
get bigger.

The driver is deliberately a small, conservative fork of edk2's
GraphicsConsoleDxe. Upstream logic is preserved wherever it is not the
point of the fork, which means the changes are confined to the embedded
font, the integer scaler, console takeover, and a few conformance fixes.

## Deployment

There are three ways to get the driver in front of the firmware console,
in increasing order of how much of the platform you have to control.

**ESP drop-in.** Place the signed driver in `\EFI\systemd\drivers\` on
the EFI System Partition, where systemd-boot loads it before drawing its
menu. This works on stock firmware and needs no NVRAM changes. It is the
reason the driver takes the console over at image start rather than
waiting to be connected: systemd-boot's `reconnect_all_drivers` only
connects drivers, it never disconnects the incumbent console, so a
passive driver placed here would sit idle.

**`Driver####` NVRAM entry.** Register the driver as a UEFI driver-load
option with `efibootmgr --driver --create`. The firmware loads it during
its own driver-connection phase, which covers pre-boot surfaces that
appear before any boot loader runs.

**Baked into firmware.** On platforms where you build the ROM, include
the driver in the firmware image itself. This is the only option that
covers the very earliest console output.

Under Secure Boot the driver must be signed with a key the platform's
signature database trusts, on any path that loads it from disk. An
unsigned driver is skipped and boot proceeds with the stock console.
