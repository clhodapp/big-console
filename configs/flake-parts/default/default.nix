# SPDX-License-Identifier: BSD-2-Clause-Patent
{ ... }:
{
  config,
  inputs,
  lib,
  self,
  ...
}:
{

  debug = false;
  systems = [ "x86_64-linux" ];

  caisson = {
    configInfo.configName = "big-console";
    libOverlays.exported = libOverlays: { inherit (libOverlays) default; };
    modules = {
      flake.exported = modules: { inherit (modules) default; };
    };
  };

  # The sole package overlay, registered with caisson's nixpkgs
  # integration: it adds the `big-console` scope to nixpkgs, and is
  # exported as-is so consumers take a plain overlay and nothing else.
  caisson.nixpkgs = {
    overlays.all = {
      packages = lib.caisson.nixpkgs.mkPackagesOverlay (
        { callPackage, ... }: import ../../../pkgs/big-console { inherit callPackage; }
      );
    };
    overlays.export = {
      enabled = true;
    };
    overlays.exported = overlays: {
      inherit (overlays) packages;
    };
    pkgSets.pkgs = {
      pkgFunction = import inputs.nixpkgs;
      overlayImports = overlays: [ overlays.packages ];
    };
    packages.export.enabled = true;
  };

  # checks and formatter live in isolated partitions; packages deliberately
  # do not: downstream flakes consume packages.* against this flake's main
  # lock (inherited locks), so dev-only inputs must not taint them.
  partitionedAttrs.checks = "checks";
  partitionedAttrs.formatter = "formatter";

  partitions.formatter = {
    extraInputs = lib.caisson-core.partitionExtraInputs ../../../tests/dependencies;
    module =
      { inputs, ... }:
      {
        imports = [ inputs.treefmt-nix.flakeModule ];
        perSystem.treefmt.programs.nixfmt.enable = true;
      };
  };

  partitions.checks = {
    extraInputs = lib.caisson-core.partitionExtraInputs ../../../tests/dependencies;
    module =
      { inputs, self, ... }:
      {
        imports = [ inputs.treefmt-nix.flakeModule ];
        perSystem =
          { pkgs, ... }:
          {
            checks = {
              smoke = pkgs.runCommand "big-console-smoke-check" { } ''
                touch "$out"
              '';
              # The driver takes over OVMF's console at 4K and renders
              # readable text (see tests/big-console-vm.nix): the default
              # build (embedded 16x32 font) and a 2x-magnified variant
              # (32x64 cells) exercising the scaler on top.
              big-console-vm = import ../../../tests/big-console-vm.nix {
                inherit pkgs;
                bigConsoleDxe = pkgs.big-console.big-console-dxe;
              };
              big-console-vm-scaled = import ../../../tests/big-console-vm.nix {
                inherit pkgs;
                bigConsoleDxe = pkgs.big-console.big-console-dxe.override {
                  glyphScale = 2;
                };
              };
            };
            treefmt.programs.nixfmt.enable = true;
          };
      };
  };

}
