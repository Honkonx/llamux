#!/usr/bin/env bash
# llamux/lib/verify.sh — Post-install verification and smoke testing

readonly SMOKE_TEST_MODEL="smollm2:135m"

# ── Verify the installed binary works ────────────────────────────────────────
verify_binary() {
    log_step "Verifying ollama binary..."

    if [[ ! -f "$OLLAMA_BIN" ]]; then
        die "ollama binary not found at $OLLAMA_BIN"
    fi

    if [[ ! -x "$OLLAMA_BIN" ]]; then
        die "ollama binary is not executable"
    fi

    local ver_output
    ver_output="$("$OLLAMA_BIN" --version 2>&1)"
    log_ok "Binary works: $ver_output"
}

# ── Verify libraries are present ─────────────────────────────────────────────
verify_libraries() {
    local enable_vulkan="${1:-true}"

    log_step "Verifying installed libraries..."

    local required_libs=(libggml-base.so libggml-cpu.so)
    if [[ "$enable_vulkan" == "true" ]]; then
        required_libs+=(libggml-vulkan.so)
    fi

    for lib in "${required_libs[@]}"; do
        if [[ -f "${OLLAMA_LIB_DIR}/${lib}" ]] || [[ -L "${OLLAMA_LIB_DIR}/${lib}" ]]; then
            local size
            size="$(du -h "${OLLAMA_LIB_DIR}/${lib}" 2>/dev/null | cut -f1)"
            log_ok "  $lib ($size)"
        else
            die "Missing library: ${OLLAMA_LIB_DIR}/${lib}"
        fi
    done
}

# ── Run a smoke test with a tiny model ───────────────────────────────────────
run_smoke_test() {
    local enable_vulkan="${1:-true}"

    log_step "Running smoke test..."

    # Start server in background
    local server_log
    server_log="$(mktemp)"

    if [[ "$enable_vulkan" == "true" ]]; then
        export OLLAMA_VULKAN=true
    fi

    "$OLLAMA_BIN" serve > "$server_log" 2>&1 &
    local server_pid=$!

    # Wait for server to be ready
    local retries=0
    while ! curl -sf http://127.0.0.1:11434/ &>/dev/null; do
        retries=$((retries + 1))
        if [[ $retries -gt 30 ]]; then
            kill "$server_pid" 2>/dev/null || true
            rm -f "$server_log"
            die "Server failed to start within 30 seconds"
        fi
        sleep 1
    done
    log_ok "Server started (PID: $server_pid)"

    # Check Vulkan status in server config
    if [[ "$enable_vulkan" == "true" ]]; then
        if grep -q "OLLAMA_VULKAN:true" "$server_log" 2>/dev/null; then
            log_ok "Vulkan enabled in server config"
        else
            log_warn "OLLAMA_VULKAN may not be active in server"
        fi
    fi

    # Pull test model
    log_info "Pulling test model: $SMOKE_TEST_MODEL..."
    if ! "$OLLAMA_BIN" pull "$SMOKE_TEST_MODEL" 2>&1; then
        kill "$server_pid" 2>/dev/null || true
        rm -f "$server_log"
        die "Failed to pull test model"
    fi
    log_ok "Test model pulled"

    # Run inference
    log_info "Running test inference..."
    local response
    response="$("$OLLAMA_BIN" run "$SMOKE_TEST_MODEL" "Say OK" 2>&1)"
    if [[ -n "$response" ]]; then
        log_ok "Inference successful: $(echo "$response" | head -1 | cut -c1-80)"
    else
        kill "$server_pid" 2>/dev/null || true
        rm -f "$server_log"
        die "Inference returned empty response"
    fi

    # Cleanup test model
    log_info "Cleaning up test model..."
    "$OLLAMA_BIN" rm "$SMOKE_TEST_MODEL" 2>&1 || true

    # Stop server
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    rm -f "$server_log"

    log_ok "Smoke test passed!"
}

# ── Full verification pipeline ───────────────────────────────────────────────
run_verification() {
    local enable_vulkan="${1:-true}"
    local skip_smoke="${2:-false}"

    verify_binary
    verify_libraries "$enable_vulkan"

    if [[ "$skip_smoke" != "true" ]]; then
        run_smoke_test "$enable_vulkan"
    fi

    log_ok "All verification checks passed"
}

# ── Print installation status ────────────────────────────────────────────────
print_status() {
    log_step "Installation status:"

    # Binary
    if [[ -f "$OLLAMA_BIN" ]]; then
        local ver
        ver="$("$OLLAMA_BIN" --version 2>&1 | grep -oP 'version is \K[0-9.]+' || echo 'unknown')"
        log_ok "Binary: $OLLAMA_BIN (version: $ver)"
    else
        log_error "Binary: not installed"
    fi

    # Libraries
    if [[ -d "$OLLAMA_LIB_DIR" ]]; then
        log_ok "Libraries: $OLLAMA_LIB_DIR"
        for lib in "${OLLAMA_LIB_DIR}"/*.so*; do
            if [[ -f "$lib" && ! -L "$lib" ]]; then
                local size
                size="$(du -h "$lib" | cut -f1)"
                log_info "  $(basename "$lib") ($size)"
            fi
        done
    else
        log_error "Libraries: not installed"
    fi

    # Vulkan
    if [[ -f "${OLLAMA_LIB_DIR}/libggml-vulkan.so" ]]; then
        log_ok "Vulkan: enabled"
    else
        log_info "Vulkan: not available"
    fi

    # Environment
    if [[ "${OLLAMA_VULKAN:-}" == "true" ]]; then
        log_ok "OLLAMA_VULKAN: true (active in current session)"
    else
        log_info "OLLAMA_VULKAN: not set in current session"
    fi

    # Backups
    list_backups
}