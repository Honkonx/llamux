# Contributing to llamux

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

```bash
git clone https://github.com/llamux/llamux.git
cd llamux

# Install ShellCheck
pkg install shellcheck

# Install bats-core from source (not in Termux repos)
git clone --depth 1 https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh $PREFIX && cd .. && rm -rf bats-core
```

## Running Tests

```bash
# Install bats-core (not available as a Termux package — install from source)
git clone --depth 1 https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh $PREFIX && cd .. && rm -rf bats-core

# Run all tests (33 tests across 4 test files)
make test

# Run a specific test file
bats tests/test_patch.bats

# Lint all scripts with ShellCheck
make lint
```

## Code Style

- All scripts use **Bash** (`#!/usr/bin/env bash`)
- Use `set -euo pipefail` at the top of every script
- Follow [ShellCheck](https://www.shellcheck.net/) recommendations
- Use descriptive function names with module prefix context
- Add comments for non-obvious logic

## Adding a New Patch

1. Add the patch logic to `lib/patch.sh`
2. Add a corresponding test in `tests/test_patch.bats`
3. Document the patch in `README.md` under "What Gets Patched"

## Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes and add tests
4. Run `make lint && make test`
5. Commit with a descriptive message: `git commit -m "feat: add XYZ support"`
6. Push and open a Pull Request

## Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation only
- `test:` — Adding or updating tests
- `chore:` — Maintenance tasks
- `refactor:` — Code restructuring without behavior change

## Reporting Issues

Please include:
- Device model and Android version
- Termux version
- Output of `llamux status`
- Full error output (with `LLAMUX_DEBUG=1`)