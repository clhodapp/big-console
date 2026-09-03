# SPDX-License-Identifier: BSD-2-Clause-Patent
{ ... }:
{

  overlay = final: prev: {
    big-console = prev.big-console or { };
  };

}
