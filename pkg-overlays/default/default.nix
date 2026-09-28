# SPDX-License-Identifier: BSD-2-Clause-Patent
#
# The default package overlay: this flake's packages under
# `pkgs.big-console` (packages/default.nix lists them). A consumer that
# lists this flake in `projects` holds it as `big-console/default`,
# which its package sets apply by default. The scope name is bound here,
# so the packages land under `pkgs.big-console` in any consumer.
{ closure-lib, ... }:
{
  overlay = closure-lib.caisson.nixpkgs.mkPackagesOverlay (
    { callPackage, ... }: import ./packages { inherit callPackage; }
  ) "big-console";
}
