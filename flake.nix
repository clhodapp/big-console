# SPDX-License-Identifier: GPL-3.0-or-later
{

  description = "Big Console: a HiDPI UEFI text console driver (edk2 GraphicsConsoleDxe fork)";

  inputs = {
    caisson.url = "github:nix-caisson/caisson";
    ch-nixpkgs.url = "github:clhodapp/ch-nixpkgs";

    # Stable channel on purpose: a boot-path firmware artifact should churn
    # as little as possible, and nothing here needs bleeding-edge nixpkgs.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    inputs@{ caisson, ... }:
    let
      lib = caisson.lib.caisson-core.mkLib {
        inherit inputs;

        projects = {
          inherit caisson;
          ch-nixpkgs = inputs.ch-nixpkgs;
        };

        modules = lib: {
          flake = {
            default = lib.caisson.mkFlakeModule ./modules/flake-parts/default;
          };
        };

        libOverlays = mkLibOverlay: {
          default = mkLibOverlay ./lib-overlays/default;
        };
      };
    in
    lib.caisson.mkFlake {
      name = "big-console";
      configModule = lib.caisson.mkFlakeModule ./configs/flake-parts/default;
    };

}
