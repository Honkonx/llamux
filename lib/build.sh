#!/usr/bin/env bash
# llamux/lib/build.sh — CMake configure, native library build, Go binary build

# ── CMake configure ──────────────────────────────────────────────────────────
cmake_configure() {
    local src_dir="$1"
    local build_dir="${src_dir}/build"
    local enable_vulkan="${2:-true}"

    log_step "Configuring CMake build..."

    local cmake_args=(
        -B "$build_dir"
        -DGGML_CCACHE=OFF
    )

    if [[ "$enable_vulkan" != "true" ]]; then
        cmake_args+=(-DGGML_VULKAN=OFF)
    fi

    if ! cmake -S "$src_dir" "${cmake_args[@]}" 2>&1; then
        die "CMake configuration failed"
    fi

    # Verify Vulkan was detected if requested
    if [[ "$enable_vulkan" == "true" ]]; then
        if ! cmake -S "$src_dir" "${cmake_args[@]}" 2>&1 | grep -q "Vulkan found"; then
            log_warn "Vulkan may not have been detected. Check cmake output."
        fi
    fi

    log_ok "CMake configured successfully"
}

# ── Native library build ────────────────────────────────────────────────────
build_native() {
    local src_dir="$1"
    local build_dir="${src_dir}/build"
    local jobs="${2:-1}"

    log_step "Building native libraries (jobs=$jobs)..."
    log_info "This may take 10-30 minutes for Vulkan shader compilation..."

    if ! cmake --build "$build_dir" -j"$jobs" 2>&1; then
        die "Native library build failed"
    fi

    # Verify output libraries exist
    local lib_dir="${build_dir}/lib/ollama"
    if [[ ! -f "${lib_dir}/libggml-base.so.0.0.0" ]]; then
        die "Build completed but libggml-base.so not found"
    fi
    if [[ ! -f "${lib_dir}/libggml-cpu.so" ]]; then
        die "Build completed but libggml-cpu.so not found"
    fi

    log_ok "Native libraries built successfully"

    # Report what was built
    log_info "Built libraries:"
    for lib in "${lib_dir}"/*.so*; do
        if [[ -f "$lib" && ! -L "$lib" ]]; then
            local size
            size="$(du -h "$lib" | cut -f1)"
            log_info "  $(basename "$lib") ($size)"
        fi
    done
}

# ── Go binary build ─────────────────────────────────────────────────────────
build_go_binary() {
    local src_dir="$1"
    local version="$2"

    local ver_num
    ver_num="$(version_number "$version")"

    log_step "Building Go binary (version $ver_num)..."

    local ldflags="-s -w -X github.com/ollama/ollama/version.Version=${ver_num}"

    if ! (cd "$src_dir" && CGO_ENABLED=1 go build -o ollama -trimpath -ldflags="$ldflags" . 2>&1); then
        die "Go binary build failed"
    fi

    if [[ ! -f "${src_dir}/ollama" ]]; then
        die "Go build completed but ollama binary not found"
    fi

    local bin_size
    bin_size="$(du -h "${src_dir}/ollama" | cut -f1)"
    log_ok "Go binary built: ollama ($bin_size)"
}

# ── Full build pipeline ─────────────────────────────────────────────────────
run_build() {
    local src_dir="$1"
    local version="$2"
    local enable_vulkan="${3:-true}"
    local jobs="${4:-1}"

    cmake_configure "$src_dir" "$enable_vulkan"
    build_native "$src_dir" "$jobs"
    build_go_binary "$src_dir" "$version"

    log_ok "Full build completed successfully"
}