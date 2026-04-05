#!/usr/bin/env bats
# Tests for lib/utils.sh

setup() {
    export LLAMUX_DEBUG=0
    source "${BATS_TEST_DIRNAME}/../lib/utils.sh"
}

@test "has_cmd finds existing commands" {
    run has_cmd bash
    [ "$status" -eq 0 ]
}

@test "has_cmd fails for nonexistent commands" {
    run has_cmd __nonexistent_command_xyz__
    [ "$status" -ne 0 ]
}

@test "get_nproc returns a number" {
    result="$(get_nproc)"
    [[ "$result" =~ ^[0-9]+$ ]]
}

@test "ensure_dir creates directory" {
    local tmpdir
    tmpdir="$(mktemp -d)/llamux_test_dir"
    ensure_dir "$tmpdir"
    [ -d "$tmpdir" ]
    rm -rf "$(dirname "$tmpdir")"
}

@test "cleanup_dir removes directory" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    mkdir -p "${tmpdir}/subdir"
    touch "${tmpdir}/subdir/file"
    cleanup_dir "$tmpdir"
    [ ! -d "$tmpdir" ]
}

@test "cleanup_dir handles nonexistent directory" {
    run cleanup_dir "/tmp/__nonexistent_llamux_test__"
    [ "$status" -eq 0 ]
}

@test "normalize color variables are set" {
    # In non-tty mode, colors should be empty strings
    [[ -n "${RED+x}" ]]
    [[ -n "${GREEN+x}" ]]
    [[ -n "${RESET+x}" ]]
}

@test "log_info does not crash" {
    run log_info "test message"
    [ "$status" -eq 0 ]
}

@test "log_error does not crash" {
    run log_error "test error"
    [ "$status" -eq 0 ]
}

@test "log_ok does not crash" {
    run log_ok "test ok"
    [ "$status" -eq 0 ]
}

@test "LLAMUX_DATA_DIR is set" {
    [[ -n "$LLAMUX_DATA_DIR" ]]
}

@test "LLAMUX_BUILD_DIR is set" {
    [[ -n "$LLAMUX_BUILD_DIR" ]]
}