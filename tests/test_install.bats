#!/usr/bin/env bats
# Tests for lib/install.sh

setup() {
    export LLAMUX_DEBUG=0
    export HOME="$(mktemp -d)"
    export PREFIX="$(mktemp -d)"
    mkdir -p "${PREFIX}/bin" "${PREFIX}/lib/ollama"
    source "${BATS_TEST_DIRNAME}/../lib/utils.sh"
    source "${BATS_TEST_DIRNAME}/../lib/install.sh"
}

teardown() {
    rm -rf "$HOME" "$PREFIX"
}

@test "backup_current skips when no binary exists" {
    run backup_current
    [ "$status" -eq 0 ]
    [[ "$output" =~ "skipping backup" ]]
}

@test "backup_current creates backup directory" {
    echo '#!/bin/sh' > "${PREFIX}/bin/ollama"
    chmod +x "${PREFIX}/bin/ollama"

    backup_current

    local backups
    backups="$(ls -1d "${HOME}/.llamux/backups"/*/ 2>/dev/null | wc -l)"
    [ "$backups" -ge 1 ]
}

@test "backup_current preserves binary" {
    echo '#!/bin/sh' > "${PREFIX}/bin/ollama"
    echo 'echo "version is 0.20.2"' >> "${PREFIX}/bin/ollama"
    chmod +x "${PREFIX}/bin/ollama"

    backup_current

    local backup_dir
    backup_dir="$(ls -1d "${HOME}/.llamux/backups"/*/ | head -1)"
    [ -f "${backup_dir}/ollama" ]
}

@test "backup_current preserves libraries" {
    echo '#!/bin/sh' > "${PREFIX}/bin/ollama"
    chmod +x "${PREFIX}/bin/ollama"
    echo "fake lib" > "${PREFIX}/lib/ollama/libggml-base.so"

    backup_current

    local backup_dir
    backup_dir="$(ls -1d "${HOME}/.llamux/backups"/*/ | head -1)"
    [ -f "${backup_dir}/lib/libggml-base.so" ]
}

@test "setup_environment adds OLLAMA_VULKAN to zshrc" {
    export SHELL="/bin/zsh"
    touch "${HOME}/.zshrc"

    setup_environment "true"

    grep -q "OLLAMA_VULKAN" "${HOME}/.zshrc"
}

@test "setup_environment is idempotent" {
    export SHELL="/bin/zsh"
    echo 'export OLLAMA_VULKAN=true' > "${HOME}/.zshrc"

    setup_environment "true"

    local count
    count="$(grep -c "OLLAMA_VULKAN" "${HOME}/.zshrc")"
    [ "$count" -eq 1 ]
}

@test "setup_boot_service creates boot script" {
    setup_boot_service

    [ -f "${HOME}/.termux/boot/ollama-serve" ]
    [ -x "${HOME}/.termux/boot/ollama-serve" ]
}

@test "list_backups handles no backups" {
    run list_backups
    [ "$status" -eq 0 ]
}