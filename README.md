# Big Console

A UEFI DXE driver that makes pre-boot text readable on HiDPI displays,
without leaving native resolution.

Firmware text consoles draw a hardcoded 8×19 pixel font. On a 4K panel that
means unreadably tiny text in every pre-boot surface that uses the Simple
Text Output protocol — most notably the systemd-boot menu, whose only
alternative (a low-resolution text mode) forces a resolution switch and the
accompanying flicker on the way into the OS. Big Console replaces the
console's renderer instead: the framebuffer stays at native resolution and
the glyphs get bigger.

## What it is

A fork of TianoCore edk2's `GraphicsConsoleDxe`
(`MdeModulePkg/Universal/Console/GraphicsConsoleDxe`) with:

- **An embedded high-resolution font.** Glyph bitmaps are generated at build
  time from a PSF2 console font (Terminus 16×32 by default) and drawn
  directly by the driver. Characters the font lacks fall back to the
  platform's HII 8×19 glyphs, stretched to the cell.
- **Integer magnification on top** (`GLYPH_SCALE`), for panels or viewing
  distances where even 16×32 reads small. A 2× build (32×64 cells) is
  provided. On panels too small for an 80×25 grid of big cells the driver
  degrades to the stock 8×19 rendering path.
- **Console takeover.** The driver binding registers at version `0xFFFFFFF0`
  (the UEFI spec's platform-reserved band, above any IHV-range version a
  firmware console uses — edk2 binds at 0xa, AMI Aptio V at 0x10). At image
  start the driver evicts the incumbent console from every GOP handle,
  re-runs the binding contest it now wins, and re-syncs the system console's
  current mode. Loading the driver is sufficient; no platform modification
  and no explicit reconnect step is required.

The text-mode table keeps the UEFI-mandated 80×25 (and 80×50 where it
fits), the stock driver's historical preset grids, and a computed
full-screen mode — e.g. 240×67 on 3840×2160 with 16×32 cells.

## Supported platforms

x86-64 UEFI. The driver is verified on every change against TianoCore
edk2 (OVMF in QEMU at 3840×2160, both variants) and has been used on
one AMI Aptio V firmware. Other vendors' firmware should work by the
UEFI driver-binding rules the console takeover relies on, but has not
been tried. There is no AArch64 build yet: the driver is
architecture-neutral C and upstream edk2 builds the console it forks for
AARCH64, so the port is build plumbing plus a hardware test, and neither
has been done.

## Using it

Prebuilt drivers for both scale variants are attached to each release,
with checksums, if you would rather not build anything. Each release
artifact is the store path CI built for the tagged commit, so it is
byte-identical to what `nix build` produces at that tag.

Build (Nix): `nix build .#big-console-dxe` (or `.#big-console-dxe-2x`).
The output is a single `BigGraphicsConsoleDxe.efi`.

The driver is a standard UEFI driver; any of the usual load paths work:

- **systemd-boot drop-in:** place it on the ESP as
  `\EFI\systemd\drivers\<name>x64.efi` (the `x64.efi` suffix is required).
  Under Secure Boot it must be signed with a db-trusted key; an unsigned
  driver is skipped and boot proceeds with the stock console.
- **`Driver####` boot variable:** `efibootmgr --driver --create ...`.
- **UEFI shell:** `load BigGraphicsConsoleDxe.efi` — takeover happens at
  load.

## Verification

`nix flake check` boots OVMF in QEMU at 3840×2160, loads the driver from a
UEFI shell, and asserts — from the mode table and framebuffer screendumps —
that the console was taken over, the mode grid matches the cell geometry,
and rendered text actually fills the tall cells (with a no-thin-stems check
for magnified builds). Both the 1× and 2× builds are exercised.

In CI the same `nix flake check` runs with the Nix store cached between
runs, since a cold runner builds the edk2 toolchain and both variants
before it can boot OVMF. A pull request that leaves `.github/` alone is
checked by `main`'s copy of the workflow, in `main`'s context once its
own check completes, and adds its build to the shared cache; one that
changes the pipeline is checked by its own copy, under a cache only it
can see. The comments at the top of the two workflow files say why that
split is what makes the cache safe to write from a pull request.

## Binary cache

What `main` builds, both driver variants included, is pushed to the
`clhodapp` cachix cache, signed with its key, so `nix build` at the same
pins downloads the driver instead of building the edk2 toolchain. That
cache skips paths its upstreams already hold, so using it means using
them too:

| Substituter | Public key |
|---|---|
| `https://clhodapp.cachix.org` | `clhodapp.cachix.org-1:EW/0conxH0OQyo0o4ub/grdkFspholmQMSnQyj0vrZI=` |
| `https://nix-community.cachix.org` | `nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=` |
| `https://numtide.cachix.org` | `numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=` |

Add all three to `extra-substituters` and `extra-trusted-public-keys`.

## Licensing

Everything in this repository is BSD-2-Clause-Patent, matching upstream
edk2: the driver sources (`pkgs/big-console/big-console-dxe/src`, forked
from edk2, per the headers in each file) and the Nix build scaffolding
and tests alike. See `LICENSE` for the terms and `NOTICE` for what came
from where.

The one exception is the font: the glyph bitmaps embedded in the built
driver are generated from Terminus and carry the SIL Open Font License
1.1. See `LICENSES/OFL-1.1.txt`.
