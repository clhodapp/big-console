# SPDX-License-Identifier: BSD-2-Clause-Patent
#
# The checks of big-console: a flake-parts configuration declared inside
# the flake-parts caisson top (configs/flake/big-console), whose
# dependencies are those of the caisson top with the pins of
# tests/dependencies beside them. The caisson top gathers the checks
# declared here into its `checks` output. A flake that lists big-console
# as an input reads nothing of this configuration, so it locks none of
# the pins of tests/dependencies.
{ ... }:
{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    let
      vmTest =
        bigConsoleDxe:
        import ../../../tests/big-console-vm.nix {
          inherit pkgs bigConsoleDxe;
        };
      scene = args: import ../../../tests/big-console-menu.nix ({ inherit pkgs; } // args);
    in
    {
      # Duplicated in the formatter partition of
      # configs/flake/big-console: the partition and this configuration
      # are separate evaluations.
      treefmt.programs.nixfmt.enable = true;

      caisson.checks = {
        treefmt = {
          category = "format";
          description = "the Nix files are formatted with nixfmt";
        };
        smoke = {
          derivation = pkgs.runCommand "big-console-smoke-check" { } ''
            touch "$out"
          '';
          category = "eval";
          description = "the flake evaluates";
        };
        # The driver takes over OVMF's console at 4K and renders
        # readable text (see tests/big-console-vm.nix): the default
        # build (embedded 16x32 font) and a 2x-magnified variant
        # (32x64 cells) exercising the scaler on top.
        big-console-vm = {
          derivation = vmTest pkgs.big-console.big-console-dxe;
          category = "qemu";
          description = "the x86_64 driver takes over the console of OVMF at 4K and renders readable text";
        };
        big-console-vm-scaled = {
          derivation = vmTest (pkgs.big-console.big-console-dxe.override { glyphScale = 2; });
          category = "qemu";
          description = "the x86_64 driver with its glyphs magnified twice renders readable text at 4K";
        };
        # The AArch64 builds, under ArmVirtQemu on an emulated `virt`
        # machine (see the test's header for what differs).
        big-console-vm-aarch64 = {
          derivation = vmTest pkgs.big-console.big-console-dxe-aarch64;
          category = "qemu";
          description = "the AArch64 driver renders readable text at 4K under ArmVirtQemu";
        };
        big-console-vm-scaled-aarch64 = {
          derivation = vmTest pkgs.big-console.big-console-dxe-2x-aarch64;
          category = "qemu";
          description = "the AArch64 driver with its glyphs magnified twice renders readable text at 4K under ArmVirtQemu";
        };
        # systemd-boot's menu at 4K, with the driver loaded from its
        # drivers directory (the deployment path) and without it. The
        # scenes' images are what the README shows.
        systemd-boot-menu = {
          derivation = pkgs.linkFarm "systemd-boot-menu" [
            {
              name = "stock";
              path = scene { name = "stock"; };
            }
            {
              name = "big-console";
              path = scene {
                name = "big-console";
                bigConsoleDxe = pkgs.big-console.big-console-dxe;
              };
            }
            {
              name = "big-console-max";
              path = scene {
                name = "big-console-max";
                bigConsoleDxe = pkgs.big-console.big-console-dxe;
                consoleMode = "max";
              };
            }
            {
              name = "big-console-2x";
              path = scene {
                name = "big-console-2x";
                bigConsoleDxe = pkgs.big-console.big-console-dxe-2x;
              };
            }
          ];
          category = "qemu";
          description = "the menu of systemd-boot at 4K renders with the driver loaded from its drivers directory and without it";
        };
      };
    };
}
