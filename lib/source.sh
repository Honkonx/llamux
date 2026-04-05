#!/usr/bin/env bash
# llamux/lib/source.sh — Git clone, version resolution, checkout

readonly OLLAMA_REPO="https://github.com/ollama/ollama.git"

# ── Resolve the target version ──────────────────────────────────────────────
# If no version specified, fetch the latest release tag from GitHub.
resolve_version() {
    local requested="${1:-}"

    if [[ -n "$requested" ]]; then
        echo "$requested"
        return 0
    fi

    log_info "Resolving latest ollama release..."
    local latest
    latest="$(git ls-remote --tags --sort=-v:refname "$OLLAMA_REPO" 'v*' 2>/dev/null \
        | head -1 \
        | sed 's|.*refs/tags/||; s|\^{}||')"

    if [[ -z "$latest" ]]; then
        die "Could not determine latest ollama version from GitHub"
    fi

    log_ok "Latest version: $latest"
    echo "$latest"
}

# ── Ensure the tag has a 'v' prefix ─────────────────────────────────────────
normalize_tag() {
    local ver="$1"
    if [[ "$ver" != v* ]]; then
        echo "v${ver}"
    else
        echo "$ver"
    fi
}

# ── Clone or update the ollama source ────────────────────────────────────────
fetch_source() {
    local version="$1"
    local tag
    tag="$(normalize_tag "$version")"
    local src_dir="${LLAMUX_BUILD_DIR}"

    if [[ -d "$src_dir/.git" ]]; then
        log_info "Source directory exists, fetching updates..."
        if ! git -C "$src_dir" fetch --tags --force 2>/dev/null; then
            log_warn "Fetch failed, removing and re-cloning..."
            cleanup_dir "$src_dir"
        fi
    fi

    if [[ ! -d "$src_dir/.git" ]]; then
        log_step "Cloning ollama repository..."
        ensure_dir "$(dirname "$src_dir")"
        if ! git clone --depth 1 --branch "$tag" "$OLLAMA_REPO" "$src_dir" 2>&1; then
            die "Failed to clone ollama at tag $tag"
        fi
        log_ok "Cloned ollama $tag"
    else
        log_step "Checking out $tag..."
        git -C "$src_dir" checkout "$tag" -- 2>/dev/null \
            || git -C "$src_dir" checkout "tags/$tag" -- 2>/dev/null \
            || die "Failed to checkout tag $tag"
        log_ok "Checked out $tag"
    fi

    # Verify we're on the right version
    local actual_tag
    actual_tag="$(git -C "$src_dir" describe --tags --exact-match 2>/dev/null || echo 'unknown')"
    log_info "Source version: $actual_tag"
}

# ── Extract the version number (without 'v' prefix) ─────────────────────────
version_number() {
    local tag="$1"
    echo "${tag#v}"
}