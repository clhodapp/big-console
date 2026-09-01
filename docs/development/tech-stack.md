# Technology Stack

- **Nix** for package definitions and checks
- **caisson** for closed-input `mkLib` and class-keyed module exports
  ([github:nix-caisson/caisson](https://github.com/nix-caisson/caisson))
- **ch-nixpkgs** for package overlay composition
- **nixpkgs stable** (`nixos-26.05`): edk2 toolchain (`edk2.mkDerivation`),
  OVMF + qemu for the VM checks, terminus_font for the embedded glyphs
- **C (edk2 DXE driver)**: vendored fork under
  `pkgs/big-console/big-console-dxe/src/BigConsolePkg`, built as a
  standalone X64 UEFI driver against edk2 core via a minimal DSC
