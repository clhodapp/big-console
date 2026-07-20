# SPDX-License-Identifier: GPL-3.0-or-later
{ ... }:
{

  overlay = final: prev: {
    ch-firmware = prev.ch-firmware or { };
  };

}
