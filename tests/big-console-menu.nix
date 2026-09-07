# SPDX-License-Identifier: BSD-2-Clause-Patent
# Boots systemd-boot from an ESP at 4K, the way the driver is deployed:
# BigGraphicsConsoleDxe.efi sits in EFI/systemd/drivers/ and systemd-boot
# loads it before drawing its menu. Nothing is loaded from a shell, so
# this is the drop-in path end to end. The scene without a driver is the
# stock console, kept for comparison.
#
# Output: the framebuffer as it showed the menu (screen.ppm, screen.png),
# a 1280-wide reduction of the whole frame (screen-1280.png), and a
# 1280x720 window at 1:1 around the rendered text (crop.png). The README's
# images come from here. Asserts that text was rendered at the cell height
# the scene expects: the tallest lit-row band fills most of a big cell with
# the driver, and stays within the stock 19-pixel glyph without it.
{
  pkgs,
  name,
  # null for the stock console
  bigConsoleDxe ? null,
  # systemd-boot's console-mode setting for loader.conf
  consoleMode ? "keep",
}:
let
  python = pkgs.python3.withPackages (ps: [ ps.numpy ]);
  systemdBoot = "${pkgs.systemd}/lib/systemd/boot/efi/systemd-bootx64.efi";
  cellHeight = if bigConsoleDxe == null then 19 else bigConsoleDxe.cellHeight;
in
pkgs.runCommand "big-console-menu-${name}"
  {
    nativeBuildInputs = [
      pkgs.qemu_test
      pkgs.mtools
      pkgs.dosfstools
      pkgs.socat
      pkgs.imagemagick
      python
    ];
  }
  ''
    # --- ESP: systemd-boot, a loader.conf, two entries, the driver -----------
    truncate -s 32M esp.img
    mkfs.vfat esp.img
    mmd -i esp.img ::/EFI ::/EFI/BOOT ::/EFI/systemd ::/EFI/systemd/drivers \
      ::/EFI/nixos ::/loader ::/loader/entries

    cat > loader.conf <<EOF
    timeout 120
    console-mode ${consoleMode}
    editor no
    EOF
    cat > gen-42.conf <<'EOF'
    title NixOS
    version 26.05 (Generation 42)
    linux /EFI/nixos/kernel.efi
    options init=/nix/store/...-nixos-system-desktop-26.05/init
    EOF
    cat > gen-41.conf <<'EOF'
    title NixOS
    version 26.05 (Generation 41)
    linux /EFI/nixos/kernel.efi
    options init=/nix/store/...-nixos-system-desktop-26.05/init
    EOF
    sed -i 's/$/\r/' loader.conf gen-42.conf gen-41.conf

    mcopy -i esp.img ${systemdBoot} ::/EFI/BOOT/BOOTX64.EFI
    # An entry's kernel must exist for systemd-boot to list it; the stub
    # stands in, since nothing is ever booted.
    mcopy -i esp.img ${pkgs.systemd}/lib/systemd/boot/efi/linuxx64.efi.stub ::/EFI/nixos/kernel.efi
    mcopy -i esp.img loader.conf ::/loader/loader.conf
    mcopy -i esp.img gen-42.conf ::/loader/entries/nixos-generation-42.conf
    mcopy -i esp.img gen-41.conf ::/loader/entries/nixos-generation-41.conf
    ${pkgs.lib.optionalString (bigConsoleDxe != null) ''
      mcopy -i esp.img ${bigConsoleDxe}/BigGraphicsConsoleDxe.efi ::/EFI/systemd/drivers/bigconsolex64.efi
    ''}

    # --- stage 1: make OVMF's own console run at 4K -------------------------
    # OVMF's stock console takes its resolution from the PlatformConfig
    # variable (what its setup screen's "preferred resolution" writes; two
    # little-endian UINT32s, horizontal then vertical), and defaults to a
    # small mode otherwise. Real firmware runs the panel natively, so a
    # first boot into the shell stores 3840x2160 there and resets; the
    # variables persist in vars.fd for the boot that matters.
    install -m0644 ${pkgs.OVMF.variables} vars.fd
    truncate -s 16M shell.img
    mkfs.vfat shell.img
    mmd -i shell.img ::/EFI ::/EFI/BOOT
    cat > startup.nsh <<'EOF'
    @echo -off
    setvar PlatformConfig -guid 7235c51c-0c80-4cab-87ac-3b084a6304b1 -bs -rt -nv =000F000070080000
    reset -s
    EOF
    sed -i 's/$/\r/' startup.nsh
    mcopy -i shell.img ${pkgs.edk2-uefi-shell}/shell.efi ::/EFI/BOOT/BOOTX64.EFI
    mcopy -i shell.img startup.nsh ::/
    mcopy -i shell.img startup.nsh ::/EFI/BOOT/
    timeout 300 qemu-system-x86_64 \
      -machine q35 -accel tcg -m 2048 -nodefaults \
      -drive if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.firmware} \
      -drive if=pflash,format=raw,file=vars.fd \
      -device bochs-display,vgamem=32M \
      -display none -serial none \
      -drive file=shell.img,format=raw,if=virtio

    # --- stage 2: boot systemd-boot at 4K and dump the framebuffer ----------
    qemu-system-x86_64 \
      -machine q35 -accel tcg -m 2048 -nodefaults \
      -drive if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.firmware} \
      -drive if=pflash,format=raw,file=vars.fd \
      -device bochs-display,vgamem=32M \
      -display none -serial none \
      -drive file=esp.img,format=raw,if=virtio \
      -qmp unix:qmp.sock,server,nowait &
    qemu_pid=$!

    # The menu redraws as it comes up; keep dumping until three consecutive
    # dumps have been lit, so the last one is the settled menu.
    lit=0
    for _ in $(seq 1 120); do
      sleep 2
      kill -0 "$qemu_pid" 2>/dev/null || break
      printf '%s%s' \
        '{"execute":"qmp_capabilities"}' \
        "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$PWD/dump.ppm\"}}" \
        | socat -t 3 - unix-connect:qmp.sock > /dev/null 2>&1 || true
      if [ -s dump.ppm ] && python3 ${./big-console-vm-verify.py} --bright dump.ppm; then
        lit=$((lit + 1))
        cp dump.ppm screen.ppm
        [ "$lit" -ge 3 ] && break
      fi
    done
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
    test -s screen.ppm

    # --- assert the glyph height, then produce the images --------------------
    band=$(python3 ${./big-console-vm-verify.py} --band screen.ppm)
    echo "tallest lit-row band: $band (expected cell height ${toString cellHeight})"
    ${
      if bigConsoleDxe == null then
        ''
          [ "$band" -le ${toString cellHeight} ] || { echo "stock console drew taller than $band px"; exit 1; }
        ''
      else
        ''
          [ $((band * 100)) -ge $((${toString cellHeight} * 55)) ] || { echo "text band $band px too short for ${toString cellHeight} px cells"; exit 1; }
        ''
    }

    mkdir -p "$out"
    cp screen.ppm "$out/"
    magick screen.ppm "$out/screen.png"
    magick screen.ppm -resize 1280x "$out/screen-1280.png"
    # A 1:1 window around whatever was drawn, so the glyphs can be compared
    # at their real size across scenes.
    read -r x0 y0 x1 y1 < <(python3 ${./big-console-vm-verify.py} --bbox screen.ppm)
    w=$(magick identify -format %w screen.ppm)
    h=$(magick identify -format %h screen.ppm)
    cx=$(( (x0 + x1) / 2 )); cy=$(( (y0 + y1) / 2 ))
    ox=$(( cx - 640 )); oy=$(( cy - 360 ))
    [ "$ox" -ge 0 ] || ox=0
    [ "$oy" -ge 0 ] || oy=0
    [ $((ox + 1280)) -le "$w" ] || ox=$((w - 1280))
    [ $((oy + 720)) -le "$h" ] || oy=$((h - 720))
    magick screen.ppm -crop "1280x720+$ox+$oy" +repage "$out/crop.png"
    echo "band=$band bbox=$x0,$y0,$x1,$y1 crop=+$ox+$oy" > "$out/report.txt"
  ''
