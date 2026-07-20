# SPDX-License-Identifier: GPL-3.0-or-later
{ ... }:
{

  overlay = final: prev: {
    big-console = prev.big-console or { };
  };

}
