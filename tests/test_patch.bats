#!/usr/bin/env bats
# Tests for lib/patch.sh

setup() {
    export LLAMUX_DEBUG=0
    source "${BATS_TEST_DIRNAME}/../lib/utils.sh"
    source "${BATS_TEST_DIRNAME}/../lib/patch.sh"
    TEST_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "patch_cmakelists_runtime_deps removes RUNTIME_DEPENDENCIES" {
    cat > "${TEST_DIR}/CMakeLists.txt" <<'CMAKE'
install(TARGETS ollama
    RUNTIME_DEPENDENCIES
        PRE_EXCLUDE_REGEXES ".*"
        POST_INCLUDE_REGEXES "libggml"
)
CMAKE
    patch_cmakelists_runtime_deps "$TEST_DIR"
    ! grep -q "RUNTIME_DEPENDENCIES" "${TEST_DIR}/CMakeLists.txt"
}

@test "patch_cmakelists_runtime_deps is idempotent" {
    cat > "${TEST_DIR}/CMakeLists.txt" <<'CMAKE'
install(TARGETS ollama)
CMAKE
    run patch_cmakelists_runtime_deps "$TEST_DIR"
    [ "$status" -eq 0 ]
}

@test "patch_shader_concurrency reduces to 1" {
    local shader_dir="${TEST_DIR}/ml/backend/ggml/ggml/src/ggml-vulkan/vulkan-shaders"
    mkdir -p "$shader_dir"
    echo '#define ASYNCIO_CONCURRENCY 64' > "${shader_dir}/vulkan-shaders-gen.cpp"

    patch_shader_concurrency "$TEST_DIR"

    result="$(grep -oP '#define ASYNCIO_CONCURRENCY \K\d+' "${shader_dir}/vulkan-shaders-gen.cpp")"
    [ "$result" = "1" ]
}

@test "patch_shader_concurrency is idempotent" {
    local shader_dir="${TEST_DIR}/ml/backend/ggml/ggml/src/ggml-vulkan/vulkan-shaders"
    mkdir -p "$shader_dir"
    echo '#define ASYNCIO_CONCURRENCY 1' > "${shader_dir}/vulkan-shaders-gen.cpp"

    run patch_shader_concurrency "$TEST_DIR"
    [ "$status" -eq 0 ]

    result="$(grep -oP '#define ASYNCIO_CONCURRENCY \K\d+' "${shader_dir}/vulkan-shaders-gen.cpp")"
    [ "$result" = "1" ]
}

@test "patch_shader_concurrency handles missing file gracefully" {
    run patch_shader_concurrency "$TEST_DIR"
    [ "$status" -eq 0 ]
}

@test "verify_patches passes after patching" {
    # Set up CMakeLists without RUNTIME_DEPENDENCIES
    cat > "${TEST_DIR}/CMakeLists.txt" <<'CMAKE'
install(TARGETS ollama)
CMAKE

    # Set up shader gen with concurrency=1
    local shader_dir="${TEST_DIR}/ml/backend/ggml/ggml/src/ggml-vulkan/vulkan-shaders"
    mkdir -p "$shader_dir"
    echo '#define ASYNCIO_CONCURRENCY 1' > "${shader_dir}/vulkan-shaders-gen.cpp"

    run verify_patches "$TEST_DIR"
    [ "$status" -eq 0 ]
}

@test "verify_patches fails with unpatched RUNTIME_DEPENDENCIES" {
    cat > "${TEST_DIR}/CMakeLists.txt" <<'CMAKE'
install(TARGETS ollama
    RUNTIME_DEPENDENCIES
        PRE_EXCLUDE_REGEXES ".*"
)
CMAKE

    run verify_patches "$TEST_DIR"
    [ "$status" -ne 0 ]
}