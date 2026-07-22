# Copilot instructions for rust-bitcoinkernel

## Build, test, and lint

- Build the main crate: `cargo build --locked`
- Build/test the full workspace: `cargo build --all-features --locked` and `cargo test --all-features --locked`
- Run one integration test: `cargo test --test test test_validate_any`
- Build the example crate: `cd examples && cargo build --verbose`
- Check formatting: `cargo fmt -- --check`
- Check the Nix files when touching `flake.nix`: `nix flake check`, `nix run nixpkgs#nixfmt -- --check flake.nix`, `nix run nixpkgs#statix -- check flake.nix`
- Fuzz a target when working on fuzz code: `cargo fuzz run script_verify`

## High-level architecture

- `bitcoinkernel` is the safe wrapper crate. `libbitcoinkernel-sys` is the raw FFI layer and builds the vendored Bitcoin Core subtree with CMake in `libbitcoinkernel-sys/build.rs`.
- The top-level crate is organized around `core`, `state`, `notifications`, `log`, and `prelude`, with most public types re-exported from `src/lib.rs`.
- `core` contains owned/borrowed block, transaction, script, and verification wrappers plus extension traits for shared behavior.
- `state` owns `Context`, `ChainParams`, and `ChainstateManager`; `Context` is configured through a builder and should stay alive for anything that depends on it.
- `notifications` and `log` are callback-based FFI adapters. Validation and logging behavior is usually wired through `ContextBuilder` and `Logger`.
- `tests/` is an integration-test crate that uses `tests/block_data.txt` and shared temp-dir helpers. `examples/` is a separate Cargo package. `xcode/` is a separate Swift/Xcode demo with its own Makefile and build script.

## Key conventions

- Prefer the builder APIs (`Context::builder()`, `ChainstateManager::builder()`) over direct construction when config is involved.
- Keep `Context` alive for at least as long as any `ChainstateManager` or other context-dependent object.
- Use `prelude::*` in examples/tests when you need the extension traits for owned and borrowed wrapper types.
- FFI wrapper types follow the sealed `AsPtr` / `AsMutPtr` / `FromPtr` / `FromMutPtr` pattern and clean up resources in `Drop`.
- Owned and borrowed wrappers are both tested; use the shared `TempDir` helper for filesystem-backed tests.
- When adding or changing validation/logging behavior, follow the existing callback style instead of introducing new side channels.
