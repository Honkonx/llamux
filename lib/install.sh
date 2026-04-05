#!/usr/bin/env bash
# llamux/lib/install.sh — Backup, install, rollback, environment setup

readonly OLLAMA_BIN="${PREFIX}/bin/ollama"
readonly OLLAMA_LIB_DIR="${PREFIX}/lib/ollama"

# ── Create a timestamped backup of the current installation ──────────────────
backup_current() {
    local backup_ts
    backup_ts="$(date '+%Y%m%d_%H%M%S')"
    local backup_path="${LLAMUX_BACKUP_DIR}/${backup_ts}"

    if [[ ! -f "$OLLAMA_BIN" ]]; then
        log_info "No existing ollama binary found — skipping backup"
        return 0
    fi

    log_step "Backing up current installation to ${backup_path}..."
    ensure_dir "$backup_path"

    cp -f "$OLLAMA_BIN" "${backup_path}/ollama" 2>/dev/null || true

    if [[ -d "$OLLAMA_LIB_DIR" ]]; then
        mkdir -p "${backup_path}/lib"
        cp -a "$OLLAMA_LIB_DIR"/. "${backup_path}/lib/" 2>/dev/null || true
    fi

    # Record the version
    local ver
    ver="$("$OLLAMA_BIN" --version 2>&1 | grep -oP 'version is \K[0-9.]+' || echo 'unknown')"
    echo "$ver" > "${backup_path}/version"

    log_ok "Backup created: $backup_path (version: $ver)"
}

# ── Install built artifacts ──────────────────────────────────────────────────
install_build() {
    local src_dir="$1"
    local build_dir="${src_dir}/build"
    local lib_dir="${build_dir}/lib/ollama"

    log_step "Installing ollama..."

    # Install binary
    if [[ ! -f "${src_dir}/ollama" ]]; then
        die "ollama binary not found in build directory"
    fi
    cp -f "${src_dir}/ollama" "$OLLAMA_BIN"
    chmod +x "$OLLAMA_BIN"
    log_ok "Installed binary: $OLLAMA_BIN"

    # Install libraries
    ensure_dir "$OLLAMA_LIB_DIR"

    # Copy real library files (not symlinks)
    for lib in "${lib_dir}"/*.so*; do
        if [[ -f "$lib" && ! -L "$lib" ]]; then
            cp -f "$lib" "$OLLAMA_LIB_DIR/"
            log_info "  Installed: $(basename "$lib")"
        fi
    done

    # Recreate symlinks for libggml-base
    if [[ -f "${OLLAMA_LIB_DIR}/libggml-base.so.0.0.0" ]]; then
        (cd "$OLLAMA_LIB_DIR" && \
            ln -sf libggml-base.so.0.0.0 libggml-base.so.0 && \
            ln -sf libggml-base.so.0 libggml-base.so)
    fi

    log_ok "Libraries installed to: $OLLAMA_LIB_DIR"
}

# ── Set up environment variables ─────────────────────────────────────────────
setup_environment() {
    local enable_vulkan="${1:-true}"
    local shell_rc

    # Detect shell rc file
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *zsh* ]]; then
        shell_rc="${HOME}/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == *bash* ]]; then
        shell_rc="${HOME}/.bashrc"
    else
        shell_rc="${HOME}/.profile"
    fi

    if [[ "$enable_vulkan" == "true" ]]; then
        if ! grep -q "OLLAMA_VULKAN" "$shell_rc" 2>/dev/null; then
            log_step "Adding OLLAMA_VULKAN=true to $shell_rc..."
            echo 'export OLLAMA_VULKAN=true' >> "$shell_rc"
            log_ok "Environment configured: OLLAMA_VULKAN=true"
        else
            log_info "OLLAMA_VULKAN already set in $shell_rc"
        fi
        export OLLAMA_VULKAN=true
    fi
}

# ── Set up Termux:Boot service (optional) ────────────────────────────────────
setup_boot_service() {
    local boot_dir="${HOME}/.termux/boot"
    local service_file="${boot_dir}/ollama-serve"

    ensure_dir "$boot_dir"

    cat > "$service_file" <<'BOOT'
#!/data/data/com.termux/files/usr/bin/bash
export OLLAMA_VULKAN=true
termux-wake-lock
ollama serve &
BOOT
    chmod +x "$service_file"
    log_ok "Boot service installed: $service_file"
    log_info "Ollama will auto-start on device boot (requires Termux:Boot app)"
}

# ── Rollback to the most recent backup ───────────────────────────────────────
rollback() {
    if [[ ! -d "$LLAMUX_BACKUP_DIR" ]]; then
        die "No backups found at $LLAMUX_BACKUP_DIR"
    fi

    # Find the most recent backup
    local latest_backup
    latest_backup="$(ls -1d "${LLAMUX_BACKUP_DIR}"/*/ 2>/dev/null | sort -r | head -1)"

    if [[ -z "$latest_backup" ]]; then
        die "No backup directories found"
    fi

    local backup_ver
    backup_ver="$(cat "${latest_backup}/version" 2>/dev/null || echo 'unknown')"

    log_step "Rolling back to backup: $(basename "$latest_backup") (version: $backup_ver)..."

    if [[ -f "${latest_backup}/ollama" ]]; then
        cp -f "${latest_backup}/ollama" "$OLLAMA_BIN"
        chmod +x "$OLLAMA_BIN"
        log_ok "Restored binary"
    fi

    if [[ -d "${latest_backup}/lib" ]]; then
        ensure_dir "$OLLAMA_LIB_DIR"
        cp -a "${latest_backup}/lib"/. "$OLLAMA_LIB_DIR/"
        log_ok "Restored libraries"
    fi

    log_ok "Rollback complete to version $backup_ver"
}

# ── List available backups ───────────────────────────────────────────────────
list_backups() {
    if [[ ! -d "$LLAMUX_BACKUP_DIR" ]]; then
        log_info "No backups found"
        return 0
    fi

    log_info "Available backups:"
    for backup in "${LLAMUX_BACKUP_DIR}"/*/; do
        if [[ -d "$backup" ]]; then
            local ver
            ver="$(cat "${backup}/version" 2>/dev/null || echo 'unknown')"
            local name
            name="$(basename "$backup")"
            log_info "  $name (version: $ver)"
        fi
    done
}