# SPDX-License-Identifier: BSD-2-Clause-Patent
# Builds BigGraphicsConsoleDxe.efi: a fork of edk2's GraphicsConsoleDxe
# (vendored under ./src from the nixpkgs edk2 tree) that renders the stock
# 8x19 font magnified by an integer factor, so the Simple Text Output console
# stays at native GOP resolution while the text becomes readable on HiDPI
# panels. Its driver-binding version is raised above the stock driver's, so
# loading it and reconnecting the GOP handle is enough to take the console
# over — no platform changes.
{
  lib,
  edk2,
  nasm,
  buildPackages,
  terminus_font,
  # PSF2 console font embedded as the console's base font, with its cell
  # geometry (must match the PSF; exposed via passthru for consumers/tests).
  psfFont ? "${terminus_font}/share/consolefonts/ter-v32n.psf.gz",
  psfFontName ? "ter-v32n",
  fontWidth ? 16,
  fontHeight ? 32,
  # Additional integer magnification on top of the embedded font.
  glyphScale ? 1,
}:
(edk2.mkDerivation "BigConsolePkg/BigConsolePkg.dsc" {
  pname = "big-console-dxe";
  inherit (edk2) version;

  nativeBuildInputs = [ nasm ];

  # Graft the fork into the edk2 workspace: BigConsolePkg lives out-of-tree
  # in this repo and resolves MdePkg/MdeModulePkg from the edk2 checkout.
  # BigFont.c is generated from the PSF so the font stays an upstream
  # artifact rather than vendored data.
  postPatch = ''
    cp -r ${./src}/BigConsolePkg BigConsolePkg
    chmod -R u+w BigConsolePkg
    ${buildPackages.python3.interpreter} ${./gen-font.py} \
      ${psfFont} ${psfFontName} \
      BigConsolePkg/BigGraphicsConsoleDxe/BigFont.c
  '';

  buildFlags = [
    "-D"
    "GLYPH_SCALE=${toString glyphScale}"
  ];

  installPhase = ''
    runHook preInstall
    install -D -m0644 Build/BigConsolePkg/RELEASE_*/X64/BigGraphicsConsoleDxe.efi \
      "$out/BigGraphicsConsoleDxe.efi"
    runHook postInstall
  '';

  passthru = {
    inherit glyphScale fontWidth fontHeight;
    cellWidth = fontWidth * glyphScale;
    cellHeight = fontHeight * glyphScale;
  };

  meta = {
    description = "edk2 GraphicsConsoleDxe fork with an embedded high-resolution font and integer glyph magnification (HiDPI UEFI text console)";
    # Driver: BSD-2-Clause-Patent (edk2); embedded Terminus glyphs: OFL-1.1.
    license = [
      lib.licenses.bsd2
      lib.licenses.ofl
    ];
    platforms = [ "x86_64-linux" ];
  };
})
