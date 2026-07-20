# SPDX-License-Identifier: GPL-3.0-or-later
{ closure-inputs, mkModule, ... }:
{ ... }:
{
  imports = [
    (mkModule ./big-console)
    closure-inputs.ch-flake.flakeModules.default
    closure-inputs.ch-nixpkgs.flakeModules.default
  ];
}
