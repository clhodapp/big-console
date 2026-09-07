# SPDX-License-Identifier: BSD-2-Clause-Patent
# Proves the big-glyph console fork works end to end in a VM. OVMF boots the
# UEFI shell from a FAT disk on a bochs-display whose VRAM (32M) caps the GOP
# mode list at exactly 3840x2160 — mirroring real GOP hardware, where the
# mode list is panel-derived and the highest mode is the native resolution
# (QEMU's virtio-gpu instead advertises up-to-8K virtual modes no panel has).
# startup.nsh records the stock console's text-mode table and loads
# BigGraphicsConsoleDxe.efi — load alone must flip the console: the driver's
# entry point evicts the incumbent from the GOP handle and re-runs the
# binding contest, which is exactly what the systemd-boot drivers-directory
# deployment relies on (systemd-boot's post-load reconnect never
# disconnects). It then records the new table, prints a sample line, and
# holds the screen while the host takes framebuffer screendumps.
# Verification asserts:
#   - the post-takeover mode table matches the driver's cell geometry
#     (columns = width / cellWidth, rows = height / cellHeight) at the
#     framebuffer resolution the screendump reveals,
#   - the framebuffer is 4K-class (>= 3840 px wide),
#   - rendered text lines actually fill the tall cells (the tallest lit-row
#     band spans most of a cell height),
#   - when integer magnification is in play (glyphScale >= 2), no foreground
#     pixel run is narrower than the scale factor — the base fonts have 1px
#     stems, so unmagnified rendering fails this immediately.
#
# The same check runs the AArch64 build: the firmware is then ArmVirtQemu
# (nixpkgs' OVMF for aarch64, cross-built), the shell the AArch64 one, the
# machine QEMU's `virt`, and the display virtio-gpu, since ArmVirtQemu
# carries no bochs-display driver. virtio-gpu advertises modes past 4K
# and the driver picks the highest, so that run's framebuffer is larger;
# the assertions derive their expectations from the dump's own size. One
# assertion changes: the `virt` machine's PL011 is a console device too,
# so the splitter's table is the intersection with TerminalDxe's fixed
# modes and its largest entry is the terminal's 160x42, not the
# full-screen grid (see the verifier).
{ pkgs, bigConsoleDxe }:
let
  inherit (bigConsoleDxe) cellWidth cellHeight glyphScale;
  python = pkgs.python3.withPackages (ps: [ ps.numpy ]);
  aarch64 = bigConsoleDxe.stdenv.hostPlatform.isAarch64;
  # Firmware and shell for the driver's own architecture: the host's
  # packages for x86-64, the cross set's for AArch64.
  targetPkgs = if aarch64 then pkgs.pkgsCross.aarch64-multiplatform else pkgs;
  ovmf = targetPkgs.OVMF;
  shell = targetPkgs.edk2-uefi-shell;
  bootFile = if aarch64 then "BOOTAA64.EFI" else "BOOTX64.EFI";
  qemu =
    if aarch64 then
      "qemu-system-aarch64 -machine virt -cpu cortex-a57 -device virtio-gpu-pci"
    else
      "qemu-system-x86_64 -machine q35 -device bochs-display,vgamem=32M";
in
pkgs.runCommand
  "big-console-vm-check-${toString cellWidth}x${toString cellHeight}${pkgs.lib.optionalString aarch64 "-aarch64"}"
  {
    nativeBuildInputs = [
      # qemu_test builds only the host's system emulator; the AArch64 run
      # needs the full package.
      (if aarch64 then pkgs.qemu else pkgs.qemu_test)
      pkgs.mtools
      pkgs.dosfstools
      pkgs.socat
      python
    ];
  }
  ''
    # --- FAT disk: shell as the default boot loader + driver + script -------
    truncate -s 16M esp.img
    mkfs.vfat esp.img
    mmd -i esp.img ::/EFI ::/EFI/BOOT

    cat > startup.nsh <<'EOF'
    @echo -off
    mode >a fs0:\before.txt
    load fs0:\BigGraphicsConsoleDxe.efi
    mode >a fs0:\after.txt
    echo "big-console sample: ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789"
    stall 30000000
    reset -s
    EOF
    sed -i 's/$/\r/' startup.nsh

    mcopy -i esp.img ${shell}/shell.efi ::/EFI/BOOT/${bootFile}
    mcopy -i esp.img ${bigConsoleDxe}/BigGraphicsConsoleDxe.efi ::/
    mcopy -i esp.img startup.nsh ::/
    mcopy -i esp.img startup.nsh ::/EFI/BOOT/

    # --- boot the firmware, poll the framebuffer over QMP --------------------
    install -m0644 ${ovmf.variables} vars.fd

    ${qemu} \
      -accel tcg -m 2048 -nodefaults \
      -drive if=pflash,format=raw,readonly=on,file=${ovmf.firmware} \
      -drive if=pflash,format=raw,file=vars.fd \
      -display none -serial none \
      -drive file=esp.img,format=raw,if=virtio \
      -qmp unix:qmp.sock,server,nowait &
    qemu_pid=$!

    for _ in $(seq 1 150); do
      sleep 2
      kill -0 "$qemu_pid" 2>/dev/null || break
      printf '%s%s' \
        '{"execute":"qmp_capabilities"}' \
        "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$PWD/dump.ppm\"}}" \
        | socat -t 3 - unix-connect:qmp.sock > /dev/null 2>&1 || true
      if [ -s dump.ppm ]; then
        cp dump.ppm last-any.ppm
        if python3 ${./big-console-vm-verify.py} --bright dump.ppm; then
          mv dump.ppm final.ppm
        fi
      fi
    done
    wait "$qemu_pid" || true

    # --- extract the shell's evidence and verify ----------------------------
    mcopy -i esp.img ::/before.txt before.txt
    mcopy -i esp.img ::/after.txt after.txt
    test -s final.ppm

    mkdir -p "$out"
    cp before.txt after.txt final.ppm "$out/"
    cp last-any.ppm "$out/" || true

    python3 ${./big-console-vm-verify.py} \
      after.txt final.ppm ${toString cellWidth} ${toString cellHeight} ${toString glyphScale} \
      ${pkgs.lib.optionalString aarch64 "--shared-terminal"} \
      | tee "$out/report.txt"
  ''
