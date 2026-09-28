# SPDX-License-Identifier: BSD-2-Clause-Patent
{ callPackage, ... }:
{
  # The driver at the embedded font's native cell size (Terminus 16x32).
  big-console-dxe = callPackage ./big-console-dxe { };

  # Same driver with the embedded font magnified 2x (32x64 cells): for
  # panels/viewing distances where native 16x32 is still too small.
  big-console-dxe-2x = callPackage ./big-console-dxe { glyphScale = 2; };

  # The same two, cross-compiled for AArch64 UEFI: the driver is
  # architecture-neutral C and edk2 selects the target from the host
  # platform, so the AArch64 package set's callPackage is the whole
  # difference. Built from x86-64 (the CI runner) with nixpkgs' cross
  # toolchain.
  big-console-dxe-aarch64 = callPackage (
    { pkgsCross }: pkgsCross.aarch64-multiplatform.callPackage ./big-console-dxe { }
  ) { };
  big-console-dxe-2x-aarch64 = callPackage (
    { pkgsCross }: pkgsCross.aarch64-multiplatform.callPackage ./big-console-dxe { glyphScale = 2; }
  ) { };
}
