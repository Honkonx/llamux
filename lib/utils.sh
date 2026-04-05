#!/usr/bin/env bash
# llamux/lib/utils.sh — Logging, colors, error handling, platform detection
# shellcheck disable=SC2034

readonly LLAMUX_NAME="llamux"
readonly LLAMUX_DATA_DIR="${HOME}/.llamux"
readonly LLAMUX_BACKUP_DIR="${LLAMUX_DATA_DIR}/backups"
readonly LLAMUX_BUILD_DIR="${HOME}/llamux-build"
readonly LLAMUX_LOG="${LLAMUX_DATA_DIR}/llamux.log"

# ── Colors ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly MAGENTA='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly RESET='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' DIM='' RESET=''
fi

# ── Logging ─────────────────────────────────────────────────────────────────
_log() {
    local level="$1" color="$2" msg="$3"
    local ts
    ts="$(date '+%H:%M:%S')"
    printf "${DIM}[%s]${RESET} ${color}%-5s${RESET} %s\n" "$ts" "$level" "$msg" >&2
    mkdir -p "$(dirname "$LLAMUX_LOG")"
    printf "[%s] %-5s %s\n" "$(date -Iseconds)" "$level" "$msg" >> "$LLAMUX_LOG" 2>/dev/null || true
}

log_info()  { _log "INFO"  "$CYAN"   "$*"; }
log_ok()    { _log "OK"    "$GREEN"  "$*"; }
log_warn()  { _log "WARN"  "$YELLOW" "$*"; }
log_error() { _log "ERROR" "$RED"    "$*"; }
log_step()  { _log "STEP"  "$MAGENTA" "$*"; }
log_debug() {
    [[ "${LLAMUX_DEBUG:-0}" == "1" ]] && _log "DEBUG" "$DIM" "$*"
    return 0
}

# ── Error handling ──────────────────────────────────────────────────────────
die() {
    log_error "$*"
    exit 1
}

# ── Banner ──────────────────────────────────────────────────────────────────
print_banner() {
    printf "${BOLD}${CYAN}"
    cat <<'BANNER'
  _ _                            
 | | | __ _ _ __ ___  _   ___  __
 | | |/ _` | '_ ` _ \| | | \ \/ /
 | | | (_| | | | | | | |_| |>  < 
 |_|_|\__,_|_| |_| |_|\__,_/_/\_\
BANNER
    printf "${RESET}"
    printf "${DIM}  Wrangle GPU-accelerated llamas on Android${RESET}\n\n"
}

# ── Platform checks ────────────────────────────────────────────────────────
assert_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        die "llamux requires Termux on Android. This doesn't look like a Termux environment."
    fi
}

assert_arch() {
    local arch
    arch="$(uname -m)"
    if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        die "llamux requires aarch64/arm64 architecture. Detected: $arch"
    fi
}

get_nproc() {
    nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1
}

# ── Filesystem helpers ──────────────────────────────────────────────────────
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

cleanup_dir() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        rm -rf "$dir"
        log_debug "Removed directory: $dir"
    fi
}

# ── Command existence check ─────────────────────────────────────────────────
has_cmd() {
    command -v "$1" &>/dev/null
}

# ── Confirmation prompt ─────────────────────────────────────────────────────
confirm() {
    local msg="${1:-Continue?}"
    printf "${YELLOW}%s [y/N] ${RESET}" "$msg" >&2
    local answer
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ── Spinner for long operations ──────────────────────────────────────────────
spinner() {
    local pid="$1" msg="${2:-Working...}"
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}%s${RESET} %s" "${chars:i%${#chars}:1}" "$msg" >&2
        i=$((i + 1))
        sleep 0.1
    done
    printf "\r%*s\r" $((${#msg} + 3)) "" >&2
}