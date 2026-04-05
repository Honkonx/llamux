#!/usr/bin/env bash
# llamux/lib/deps.sh — Dependency detection and installation via Termux pkg

# Required packages for building ollama with Vulkan on Termux
readonly LLAMUX_REQUIRED_PKGS=(
    git
    golang
    cmake
    ninja
    make
    patch
    vulkan-headers
    vulkan-loader-android
    shaderc
)

# Optional packages
readonly LLAMUX_OPTIONAL_PKGS=(
    ccache
)

# ── Check if a Termux package is installed ──────────────────────────────────
pkg_installed() {
    local pkg="$1"
    dpkg -s "$pkg" &>/dev/null
}

# ── List missing required packages ──────────────────────────────────────────
get_missing_deps() {
    local missing=()
    for pkg in "${LLAMUX_REQUIRED_PKGS[@]}"; do
        if ! pkg_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done
    printf '%s\n' "${missing[@]}"
}

# ── Install missing dependencies ────────────────────────────────────────────
install_deps() {
    local dry_run="${1:-false}"
    local missing
    missing="$(get_missing_deps)"

    if [[ -z "$missing" ]]; then
        log_ok "All required dependencies are installed"
        return 0
    fi

    log_info "Missing packages:"
    while IFS= read -r pkg; do
        log_info "  • $pkg"
    done <<< "$missing"

    if [[ "$dry_run" == "true" ]]; then
        log_info "[dry-run] Would install: $missing"
        return 0
    fi

    log_step "Installing missing packages..."
    local pkg_list
    pkg_list="$(echo "$missing" | tr '\n' ' ')"

    if ! pkg install -y $pkg_list; then
        die "Failed to install packages: $pkg_list"
    fi

    log_ok "All dependencies installed successfully"
}

# ── Verify critical tools are available ──────────────────────────────────────
verify_tools() {
    local tools=(git go cmake glslc patch)
    local ok=true

    for tool in "${tools[@]}"; do
        if has_cmd "$tool"; then
            local ver
            case "$tool" in
                go)    ver="$(go version 2>/dev/null | awk '{print $3}')" ;;
                git)   ver="$(git --version 2>/dev/null | awk '{print $3}')" ;;
                cmake) ver="$(cmake --version 2>/dev/null | head -1 | awk '{print $3}')" ;;
                glslc) ver="$(glslc --version 2>/dev/null | head -1)" ;;
                *)     ver="found" ;;
            esac
            log_ok "$tool: $ver"
        else
            log_error "$tool: NOT FOUND"
            ok=false
        fi
    done

    [[ "$ok" == "true" ]] || die "Missing required tools. Run: llamux deps"
}

# ── Print dependency status ──────────────────────────────────────────────────
print_dep_status() {
    log_step "Dependency status:"
    for pkg in "${LLAMUX_REQUIRED_PKGS[@]}"; do
        if pkg_installed "$pkg"; then
            log_ok "  $pkg"
        else
            log_error "  $pkg (missing)"
        fi
    done
}