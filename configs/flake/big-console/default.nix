# SPDX-License-Identifier: BSD-2-Clause-Patent
{ ... }:
{
  inputs,
  lib,
  ...
}:
{

  imports = [ inputs.flake-parts.flakeModules.partitions ];

  debug = false;
  caisson = {
    libOverlays.exported = libOverlays: { inherit (libOverlays) default; };
    modules = {
      flake.exported = modules: { inherit (modules) default; };
    };
  };

  # The sole package overlay is the `default` entry of this flake's
  # package overlay registry (pkg-overlays/, registered on mkLib): it adds
  # the `big-console` scope to nixpkgs, the package set applies it by
  # default, and the flake exports it as `pkgOverlays` and as the plain
  # `overlays.default`.
  caisson.nixpkgs = {
    packages.export.enabled = true;
  };

  # The checks of big-console, with the pins of tests/dependencies that
  # only the checks need (configs/flake/checks). The caisson top gathers
  # the checks of every configuration declared inside it into its
  # `checks` output. This selector passes the configuration up to
  # nothing, so a flake that reads the exports of big-console evaluates
  # neither the configuration nor its pins.
  caisson.flake-parts.configurations.checks = lib.caisson.flake-parts.mkConfiguration {
    inherit (lib.caisson.pins.flake-compat ../../../tests/dependencies) dependencies;
  };
  caisson.flake-parts.exported = _: { };

  # The formatter lives in an isolated partition; packages deliberately
  # do not: downstream flakes consume packages.* against this flake's main
  # lock (inherited locks), so dev-only inputs must not taint them.
  partitionedAttrs.formatter = "formatter";

  partitions.formatter = {
    extraInputs = (lib.caisson.pins.flake-compat ../../../tests/dependencies).dependencies;
    module =
      { inputs, ... }:
      {
        imports = [ inputs.treefmt-nix.flakeModule ];
        perSystem.treefmt.programs.nixfmt.enable = true;
      };
  };

}
