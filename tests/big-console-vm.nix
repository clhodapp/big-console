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
{ pkgs, bigConsoleDxe }:
let
  inherit (bigConsoleDxe) cellWidth cellHeight glyphScale;
  python = pkgs.python3.withPackages (ps: [ ps.numpy ]);
in
pkgs.runCommand "big-console-vm-check-${toString cellWidth}x${toString cellHeight}"
  {
    nativeBuildInputs = [
      pkgs.qemu_test
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

    mcopy -i esp.img ${pkgs.edk2-uefi-shell}/shell.efi ::/EFI/BOOT/BOOTX64.EFI
    mcopy -i esp.img ${bigConsoleDxe}/BigGraphicsConsoleDxe.efi ::/
    mcopy -i esp.img startup.nsh ::/
    mcopy -i esp.img startup.nsh ::/EFI/BOOT/

    # --- boot OVMF at 4K, poll the framebuffer over QMP ---------------------
    install -m0644 ${pkgs.OVMF.variables} vars.fd

    qemu-system-x86_64 \
      -machine q35 -accel tcg -m 2048 -nodefaults \
      -drive if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.firmware} \
      -drive if=pflash,format=raw,file=vars.fd \
      -device bochs-display,vgamem=32M \
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
      | tee "$out/report.txt"
  ''
