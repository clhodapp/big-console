# SPDX-License-Identifier: BSD-2-Clause-Patent
#
# The exported flake module, for consumers composing this flake with
# caisson. Consuming the driver needs none of it: `overlays.packages`
# is a plain nixpkgs overlay and `packages.<system>` holds the two
# build variants, so any flake can take either without adopting a
# framework.
{ mkModule, ... }:
{ ... }:
{
  imports = [
    (mkModule ./big-console)
  ];
}
