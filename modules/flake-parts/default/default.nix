# SPDX-License-Identifier: GPL-3.0-or-later
#
# The exported flake module. Consumers also need caisson's default
# flake module and ch-nixpkgs's default flake module applied, which
# any caisson composition selects from its own registry.
{ mkModule, ... }:
{ ... }:
{
  imports = [
    (mkModule ./big-console)
  ];
}
