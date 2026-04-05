#!/usr/bin/env bats
# Tests for lib/source.sh

setup() {
    export LLAMUX_DEBUG=0
    source "${BATS_TEST_DIRNAME}/../lib/utils.sh"
    source "${BATS_TEST_DIRNAME}/../lib/source.sh"
}

@test "normalize_tag adds v prefix" {
    result="$(normalize_tag "0.20.2")"
    [ "$result" = "v0.20.2" ]
}

@test "normalize_tag preserves existing v prefix" {
    result="$(normalize_tag "v0.20.2")"
    [ "$result" = "v0.20.2" ]
}

@test "version_number strips v prefix" {
    result="$(version_number "v0.20.2")"
    [ "$result" = "0.20.2" ]
}

@test "version_number handles no prefix" {
    result="$(version_number "0.20.2")"
    [ "$result" = "0.20.2" ]
}

@test "resolve_version returns provided version" {
    result="$(resolve_version "v0.20.2")"
    [ "$result" = "v0.20.2" ]
}

@test "resolve_version fetches latest when empty" {
    # This test requires network access
    if ! command -v git &>/dev/null; then
        skip "git not available"
    fi
    result="$(resolve_version "")"
    [[ "$result" =~ ^v[0-9]+\.[0-9]+ ]]
}