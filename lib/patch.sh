#!/usr/bin/env bash
# llamux/lib/patch.sh — Apply Android/Termux-specific patches to ollama source

# ── Patch: Remove RUNTIME_DEPENDENCIES from CMakeLists.txt ──────────────────
# Android's CMake doesn't support RUNTIME_DEPENDENCIES in install(TARGETS).
# This patch removes those lines so the build succeeds on Termux.
patch_cmakelists_runtime_deps() {
    local src_dir="$1"
    local cmake_file="${src_dir}/CMakeLists.txt"

    if [[ ! -f "$cmake_file" ]]; then
        die "CMakeLists.txt not found at: $cmake_file"
    fi

    if ! grep -q "RUNTIME_DEPENDENCIES" "$cmake_file"; then
        log_info "CMakeLists.txt: RUNTIME_DEPENDENCIES not present (already patched or not needed)"
        return 0
    fi

    log_step "Patching CMakeLists.txt: removing RUNTIME_DEPENDENCIES..."

    # Remove the RUNTIME_DEPENDENCIES block (multi-line)
    # Pattern: RUNTIME_DEPENDENCIES followed by PRE_EXCLUDE_REGEXES/POST_INCLUDE_REGEXES lines
    sed -i '/RUNTIME_DEPENDENCIES/,/POST_INCLUDE_REGEXES.*$/d' "$cmake_file"

    # Also remove any standalone RUNTIME_DEPENDENCIES lines that might remain
    sed -i '/RUNTIME_DEPENDENCIES/d' "$cmake_file"

    if grep -q "RUNTIME_DEPENDENCIES" "$cmake_file"; then
        die "Failed to fully remove RUNTIME_DEPENDENCIES from CMakeLists.txt"
    fi

    log_ok "CMakeLists.txt patched: RUNTIME_DEPENDENCIES removed"
}

# ── Patch: Reduce shader compilation concurrency ────────────────────────────
# The Vulkan shader generator (vulkan-shaders-gen.cpp) uses ASYNCIO_CONCURRENCY=64
# by default, which causes deadlocks on Android due to limited process/thread
# resources. Reducing to 1 prevents the deadlock.
patch_shader_concurrency() {
    local src_dir="$1"
    local shader_gen="${src_dir}/ml/backend/ggml/ggml/src/ggml-vulkan/vulkan-shaders/vulkan-shaders-gen.cpp"

    if [[ ! -f "$shader_gen" ]]; then
        log_warn "vulkan-shaders-gen.cpp not found (Vulkan backend may not be present)"
        return 0
    fi

    local current
    current="$(grep -oP '#define ASYNCIO_CONCURRENCY \K\d+' "$shader_gen" 2>/dev/null || echo "")"

    if [[ -z "$current" ]]; then
        log_info "ASYNCIO_CONCURRENCY not found in shader gen (may be a different version)"
        return 0
    fi

    if [[ "$current" == "1" ]]; then
        log_info "Shader concurrency already set to 1"
        return 0
    fi

    log_step "Patching vulkan-shaders-gen.cpp: ASYNCIO_CONCURRENCY $current → 1..."
    sed -i "s/#define ASYNCIO_CONCURRENCY ${current}/#define ASYNCIO_CONCURRENCY 1/" "$shader_gen"

    local after
    after="$(grep -oP '#define ASYNCIO_CONCURRENCY \K\d+' "$shader_gen")"
    if [[ "$after" != "1" ]]; then
        die "Failed to patch ASYNCIO_CONCURRENCY"
    fi

    log_ok "Shader concurrency patched: $current → 1"
}

# ── Apply all patches ───────────────────────────────────────────────────────
apply_patches() {
    local src_dir="$1"
    local enable_vulkan="${2:-true}"

    log_step "Applying Android/Termux patches..."

    patch_cmakelists_runtime_deps "$src_dir"

    if [[ "$enable_vulkan" == "true" ]]; then
        patch_shader_concurrency "$src_dir"
    fi

    log_ok "All patches applied successfully"
}

# ── Verify patches were applied ──────────────────────────────────────────────
verify_patches() {
    local src_dir="$1"
    local ok=true

    # Check RUNTIME_DEPENDENCIES is gone
    if grep -q "RUNTIME_DEPENDENCIES" "${src_dir}/CMakeLists.txt" 2>/dev/null; then
        log_error "RUNTIME_DEPENDENCIES still present in CMakeLists.txt"
        ok=false
    fi

    # Check shader concurrency
    local shader_gen="${src_dir}/ml/backend/ggml/ggml/src/ggml-vulkan/vulkan-shaders/vulkan-shaders-gen.cpp"
    if [[ -f "$shader_gen" ]]; then
        local conc
        conc="$(grep -oP '#define ASYNCIO_CONCURRENCY \K\d+' "$shader_gen" 2>/dev/null || echo "")"
        if [[ -n "$conc" && "$conc" != "1" ]]; then
            log_error "ASYNCIO_CONCURRENCY is $conc, expected 1"
            ok=false
        fi
    fi

    [[ "$ok" == "true" ]]
}