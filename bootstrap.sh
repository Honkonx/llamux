#!/usr/bin/env bash
# llamux bootstrap — One-click installer for llamux on a fresh Termux
# Usage: curl -fsSL https://raw.githubusercontent.com/llamux/llamux/main/bootstrap.sh | bash
set -euo pipefail

REPO="https://github.com/llamux/llamux.git"
INSTALL_DIR="${HOME}/llamux"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

info()  { printf "${CYAN}[INFO]${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${RESET}    %s\n" "$*"; }
error() { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; }
die()   { error "$*"; exit 1; }

# ── Banner ───────────────────────────────────────────────────────────────────
printf "${BOLD}${CYAN}"
cat <<'BANNER'

  _ _                            
 | | | __ _ _ __ ___  _   ___  __
 | | |/ _` | '_ ` _ \| | | \ \/ /
 | | | (_| | | | | | | |_| |>  < 
 |_|_|\__,_|_| |_| |_|\__,_/_/\_\

  One-click bootstrap for Android/Termux
BANNER
printf "${RESET}\n"

# ── Pre-flight checks ───────────────────────────────────────────────────────
if [[ ! -d "/data/data/com.termux" ]]; then
    die "This script requires Termux on Android."
fi

arch="$(uname -m)"
if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
    die "Requires aarch64/arm64 architecture. Detected: $arch"
fi

# ── Step 1: Update package index ─────────────────────────────────────────────
info "Updating Termux package index..."
pkg update -y 2>&1 | tail -1
ok "Package index updated"

# ── Step 2: Install git if missing ───────────────────────────────────────────
if ! command -v git &>/dev/null; then
    info "Installing git..."
    pkg install -y git 2>&1 | tail -1
fi
ok "git available: $(git --version)"

# ── Step 3: Clone llamux ────────────────────────────────────────────────────
if [[ -d "$INSTALL_DIR" ]]; then
    info "llamux directory exists, pulling latest..."
    git -C "$INSTALL_DIR" pull --ff-only 2>&1 || {
        info "Pull failed, re-cloning..."
        rm -rf "$INSTALL_DIR"
        git clone "$REPO" "$INSTALL_DIR" 2>&1
    }
else
    info "Cloning llamux..."
    git clone "$REPO" "$INSTALL_DIR" 2>&1
fi
ok "llamux cloned to $INSTALL_DIR"

# ── Step 4: Make executable ──────────────────────────────────────────────────
chmod +x "${INSTALL_DIR}/llamux" "${INSTALL_DIR}"/lib/*.sh

# ── Step 5: Add to PATH if needed ───────────────────────────────────────────
shell_rc="${HOME}/.bashrc"
[[ "$SHELL" == *zsh* ]] && shell_rc="${HOME}/.zshrc"

if ! grep -q "llamux" "$shell_rc" 2>/dev/null; then
    info "Adding llamux to PATH in $shell_rc..."
    echo "" >> "$shell_rc"
    echo "# llamux — Wrangle GPU-accelerated llamas on Android" >> "$shell_rc"
    echo "export PATH=\"\${HOME}/llamux:\${PATH}\"" >> "$shell_rc"
    ok "Added to PATH"
else
    ok "llamux already in PATH"
fi

# Export for current session
export PATH="${INSTALL_DIR}:${PATH}"

# ── Step 6: Verify ──────────────────────────────────────────────────────────
info "Verifying installation..."
llamux_ver="$(llamux version 2>&1)"
ok "$llamux_ver"

# ── Done! ────────────────────────────────────────────────────────────────────
echo ""
printf "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${GREEN}║  llamux installed successfully!                     ║${RESET}\n"
printf "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${RESET}\n"
echo ""
info "Quick start:"
echo ""
echo "  # Restart your shell (or run: source $shell_rc)"
echo "  # Then build & install Ollama with Vulkan GPU support:"
echo "  llamux install"
echo ""
echo "  # Or install a specific version:"
echo "  llamux install --version 0.20.2"
echo ""
echo "  # Preview what will happen first:"
echo "  llamux install --dry-run"
echo ""