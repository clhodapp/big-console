# SPDX-License-Identifier: GPL-3.0-or-later
{

  description = "Big Console: a HiDPI UEFI text console driver (edk2 GraphicsConsoleDxe fork)";

  inputs = {
    ch-flake.url = "github:clhodapp/ch-flake";
    ch-nixpkgs.url = "github:clhodapp/ch-nixpkgs";

    # Stable channel on purpose: a boot-path firmware artifact should churn
    # as little as possible, and nothing here needs bleeding-edge nixpkgs.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    flake-parts.follows = "ch-flake/flake-parts";
  };

  outputs =
    inputs@{
      ch-flake,
      flake-parts,
      self,
      ...
    }:
    let
      lib = ch-flake.lib.mkLib {
        inherit inputs;

        modules = lib: {
          flake = {
            default = lib.ch-flake.mkFlakeModule ./modules/flake-parts/default;
            partitions = flake-parts.flakeModules.partitions;
          };
        };

        libOverlays = mkLibOverlay: {
          default = mkLibOverlay ./lib-overlays/default;
          ch-nixpkgs = inputs.ch-nixpkgs.libOverlays.default;
        };
      };
    in
    lib.ch-flake.mkFlake {
      name = "big-console";
      configModule = lib.ch-flake.mkFlakeModule ./configs/flake-parts/default;
    };

}
