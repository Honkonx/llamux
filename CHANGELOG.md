# Changelog

All notable changes to llamux will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-04-05

### Added
- Initial release of llamux
- `install` command: build and install any version of Ollama with Vulkan GPU support
- `rollback` command: restore previous installation from timestamped backups
- `status` command: show installed version, libraries, and Vulkan status
- `deps` command: install all required Termux build dependencies
- `clean` command: remove build artifacts
- Automatic patching of CMakeLists.txt (RUNTIME_DEPENDENCIES removal)
- Automatic patching of vulkan-shaders-gen.cpp (ASYNCIO_CONCURRENCY deadlock fix)
- Post-install smoke test with tiny model
- Optional Termux:Boot auto-start service (`--boot-service`)
- Dry-run mode (`--dry-run`)
- CPU-only build mode (`--no-vulkan`)
- Colored logging with debug mode (`LLAMUX_DEBUG=1`)
- bats-core test suite
- GitHub Actions CI (ShellCheck + bats) and release workflows
- Comprehensive README with troubleshooting guide