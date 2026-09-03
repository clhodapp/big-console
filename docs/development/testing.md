# Testing

From the repository root:

```bash
nix flake check
```

Checks (x86_64-linux, checks partition):

- `smoke` — trivial dev-partition smoke check
- `big-console-vm` / `big-console-vm-scaled` — boot OVMF's UEFI shell at
  3840x2160 (bochs-display with VRAM capped so the highest GOP mode is the
  panel resolution, as on real panel-derived mode lists), load the driver
  (takeover must happen from `load` alone), and verify from the mode table
  plus framebuffer screendumps: mode grid == cell geometry, text fills the
  tall cells, and (scaled build) no foreground run thinner than the scale
  factor. Artifacts (mode tables, screendump, report) land in the check
  output for inspection.

Gotchas: QEMU's virtio-gpu advertises up-to-8K virtual modes no panel has —
that is why the check uses bochs-display. The verifier reads raw PPM
screendumps polled over QMP while startup.nsh holds the final screen.
