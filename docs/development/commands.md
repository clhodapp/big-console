# Commands

```bash
# Format
nix fmt

# Run checks
nix flake check

# Build the driver
nix build .#big-console-dxe
nix build .#big-console-dxe-2x
```

Local iteration from a consumer flake:

```bash
nix flake check --override-input big-console path:../big-console
```
