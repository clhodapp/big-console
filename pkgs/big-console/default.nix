# SPDX-License-Identifier: BSD-2-Clause-Patent
{ callPackage, ... }:
{
  # The driver at the embedded font's native cell size (Terminus 16x32).
  big-console-dxe = callPackage ./big-console-dxe { };

  # Same driver with the embedded font magnified 2x (32x64 cells): for
  # panels/viewing distances where native 16x32 is still too small.
  big-console-dxe-2x = callPackage ./big-console-dxe { glyphScale = 2; };
}
