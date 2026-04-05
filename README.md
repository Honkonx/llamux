# 🦙 llamux

**Wrangle GPU-accelerated llamas on Android**

[![CI](https://github.com/JediRhymeTrix/llamux/actions/workflows/ci.yml/badge.svg)](https://github.com/JediRhymeTrix/llamux/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

```
  _ _                            
 | | | __ _ _ __ ___  _   ___  __
 | | |/ _` | '_ ` _ \| | | \ \/ /
 | | | (_| | | | | | | |_| |>  < 
 |_|_|\__,_|_| |_| |_|\__,_/_/\_\
```

llamux is a CLI tool that automates building [Ollama](https://ollama.com) from source with **Vulkan GPU acceleration** on Android devices running [Termux](https://termux.dev). It handles dependency installation, source patching, compilation, installation, and rollback — all in one command.

## Why?

Ollama's official releases don't support Android. Unofficial binaries don't support GPU acceleration. Building from source on Termux requires several patches:

- **CMakeLists.txt** uses `RUNTIME_DEPENDENCIES` which Android's CMake doesn't support
- **Vulkan shader compilation** deadlocks on Android due to high concurrency defaults (`ASYNCIO_CONCURRENCY=64`)

llamux applies these patches automatically and builds a fully functional Ollama with Vulkan GPU support.

## Quick Start

### One-Click Bootstrap

Run this single command on a fresh Termux installation to get everything set up:

```bash
curl -fsSL https://raw.githubusercontent.com/JediRhymeTrix/llamux/main/bootstrap.sh | bash
```

This will:
- Install git if missing
- Clone llamux to `~/llamux`
- Add it to your PATH
- Verify the installation

Then just run:
```bash
source ~/.zshrc   # or ~/.bashrc
llamux install
```

### Manual Install

```bash
# Clone llamux
git clone https://github.com/JediRhymeTrix/llamux.git
cd llamux

# Build and install the latest Ollama with Vulkan GPU support
./llamux install
```

That's it. llamux will:
1. Install all build dependencies (cmake, go, vulkan-headers, shaderc, etc.)
2. Clone the latest Ollama release
3. Apply Android/Termux patches
4. Build native libraries with Vulkan support
5. Build the Go binary
6. Back up your current installation
7. Install the new build
8. Configure `OLLAMA_VULKAN=true` in your shell
9. Run a smoke test to verify everything works

## Installation

### Prerequisites

- Android device with **aarch64/arm64** processor
- [Termux](https://f-droid.org/en/packages/com.termux/) installed (F-Droid version recommended)
- Internet connection for downloading dependencies and Ollama source

### Install llamux

```bash
git clone https://github.com/JediRhymeTrix/llamux.git
cd llamux

# Option A: Run directly from the repo
./llamux install

# Option B: Install llamux system-wide
make install
llamux install
```

## Usage

### Build & Install Ollama

```bash
# Latest version with Vulkan GPU acceleration
llamux install

# Specific version
llamux install --version 0.20.2

# CPU-only (no Vulkan)
llamux install --no-vulkan

# Skip the post-install smoke test
llamux install --no-smoke

# Preview what would happen
llamux install --dry-run

# Set up auto-start on boot (requires Termux:Boot)
llamux install --boot-service

# Use more parallel build jobs (may cause OOM on low-RAM devices)
llamux install --jobs 2
```

### Other Commands

```bash
# Check installation status
llamux status

# Roll back to previous version
llamux rollback

# Install build dependencies only
llamux deps

# Clean up build artifacts
llamux clean

# Show version
llamux version

# Show help
llamux help
```

## What Gets Patched

### 1. CMakeLists.txt — RUNTIME_DEPENDENCIES Removal

Android's CMake doesn't support the `RUNTIME_DEPENDENCIES` parameter in `install(TARGETS)`. llamux removes this block so the build succeeds.

### 2. Vulkan Shader Concurrency Fix

The Vulkan shader generator (`vulkan-shaders-gen.cpp`) defaults to `ASYNCIO_CONCURRENCY=64`, which causes deadlocks on Android due to limited process resources. llamux reduces this to `1` to prevent the deadlock while still compiling all 2000+ shader variants.

## Architecture

```
llamux/
├── llamux              # Main CLI entry point
├── bootstrap.sh        # One-click installer for fresh Termux
├── lib/
│   ├── utils.sh        # Logging, colors, error handling, platform detection
│   ├── deps.sh         # Dependency detection & installation via pkg
│   ├── source.sh       # Git clone, version resolution, checkout
│   ├── patch.sh        # Android-specific source patches
│   ├── build.sh        # CMake configure + native build + Go build
│   ├── install.sh      # Backup, install, rollback, env setup
│   └── verify.sh       # Post-install verification & smoke test
├── tests/
│   ├── test_utils.bats # Utility function tests (12 tests)
│   ├── test_source.bats # Version resolution tests (6 tests)
│   ├── test_patch.bats  # Patch application tests (7 tests)
│   └── test_install.bats # Install/rollback tests (8 tests)
├── .github/workflows/
│   ├── ci.yml          # ShellCheck + bats tests on push/PR
│   └── release.yml     # Tag-based GitHub releases
├── Makefile            # install/uninstall/test/lint/clean targets
├── CONTRIBUTING.md     # Contribution guidelines
├── CHANGELOG.md        # Version history
└── README.md
```

## Development

### Running Tests

```bash
# Install bats-core (not available as a Termux package — install from source)
git clone --depth 1 https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh $PREFIX && cd .. && rm -rf bats-core

# Run all tests
make test

# Run specific test file
bats tests/test_patch.bats
```

### Linting

```bash
# Install shellcheck
pkg install shellcheck

# Lint all scripts
make lint
```

### Making a Release

```bash
git tag v0.1.0
git push origin v0.1.0
# GitHub Actions will create a release automatically
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_VULKAN` | `true` (set by llamux) | Enable Vulkan GPU acceleration |
| `LLAMUX_DEBUG` | `0` | Enable debug logging |

## Troubleshooting

### Build fails with "RUNTIME_DEPENDENCIES" error
This means the patch didn't apply correctly. Run `llamux clean` and try again.

### Shader compilation hangs/deadlocks
This is the concurrency bug that llamux fixes. If you see this, ensure the `ASYNCIO_CONCURRENCY` patch was applied: check that the value is `1` in the shader generator source.

### Out of memory during build
Try `llamux install --jobs 1` (default). Close other apps to free RAM. The Vulkan shader compilation is memory-intensive.

### Vulkan not detected at runtime
- Ensure `OLLAMA_VULKAN=true` is set: `echo $OLLAMA_VULKAN`
- Check if your device has Vulkan support: `vulkaninfo` (install with `pkg install vulkan-tools`)
- Some devices don't expose Vulkan drivers to Termux — in this case, Ollama will fall back to CPU

### Rollback to previous version
```bash
llamux rollback
```

## License

[MIT](LICENSE)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Acknowledgments

- [Ollama](https://ollama.com) — the LLM runner
- [Termux](https://termux.dev) — Android terminal emulator
- [ggml](https://github.com/ggerganov/ggml) — the tensor library with Vulkan backend