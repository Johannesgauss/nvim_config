#!/usr/bin/env bash
# ==============================================================================
# Neovim Configuration - Universal Cross-Platform Installer & Updater
# Repository: https://github.com/Johannesgauss/nvim_config
#
# Supported Operating Systems (Bash 3.2+ compatible for older macOS & UNIX):
#   - Linux: Gentoo, Arch/Manjaro/CachyOS, Debian/Ubuntu/Mint/Pop!_OS,
#            Fedora/RHEL/Rocky/Alma, openSUSE, Void, Alpine, NixOS, Solus, Clear
#   - macOS: Apple Silicon (ARM64) & Intel (x86_64, including older macOS releases)
#   - BSD:   FreeBSD, OpenBSD
#   - Windows: WSL, Git Bash (MINGW/MSYS2), Cygwin (via winget, scoop, choco, pacman)
#
# Features:
#   - Installs all Essential Dependencies automatically
#   - Prompts 1-by-1 for Optional Dependencies BEFORE running any installation
#   - Clones or updates https://github.com/Johannesgauss/nvim_config in ~/.config/nvim
#   - Installs itself into ~/.local/bin/nvim-installer on UNIX systems
#   - Supports full updates (--update / update) for config, plugins, parsers & tools
# ==============================================================================

set -u

REPO_URL="https://github.com/Johannesgauss/nvim_config.git"
RAW_SCRIPT_URL="https://raw.githubusercontent.com/Johannesgauss/nvim_config/main/install.sh"
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
LOCAL_BIN_DIR="$HOME/.local/bin"
INSTALLER_BIN_NAME="nvim-installer"
INSTALLER_BIN_PATH="$LOCAL_BIN_DIR/$INSTALLER_BIN_NAME"

# ==============================================================================
# Colors & Formatting (ANSI-C Quoting for Bash 3.2+ and EOF heredocs)
# ==============================================================================
if [ -t 1 ] || [ -e /dev/tty ]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RED=$'\033[1;31m'
    GREEN=$'\033[1;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[1;34m'
    MAGENTA=$'\033[1;35m'
    CYAN=$'\033[1;36m'
    RESET=$'\033[0m'
else
    BOLD="" DIM="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" RESET=""
fi

info()    { printf "${BLUE}[INFO]${RESET} %s\n" "$*"; }
success() { printf "${GREEN}[ OK ]${RESET} %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
error()   { printf "${RED}[ERRO]${RESET} %s\n" "$*" >&2; }
step()    { printf "\n${MAGENTA}${BOLD}==> %s${RESET}\n" "$*"; }

# ==============================================================================
# CLI Flags & State Variables
# ==============================================================================
MODE="interactive"      # interactive | update | quick-update
AUTO_YES=0              # --yes / -y / --all
MINIMAL_ONLY=0          # --minimal / --no-optional
DRY_RUN=0               # --dry-run

OPT_LAZYGIT=0
OPT_RUST=0
OPT_GDB=0
OPT_LATEX=0
OPT_NERDFONT=0
OPT_AGY=0
OPT_CLAUDE=0
OPT_OLLAMA=0

OS_FAMILY=""            # linux | macos | bsd | windows
OS_DISTRO=""            # gentoo | arch | debian | fedora | opensuse | void | alpine | nix | macos | freebsd | openbsd | windows
ARCH_RAW=""
ARCH_NORM=""            # x86_64 | arm64 | i686 | unknown
PKG_MGR=""              # emerge | pacman | apt | dnf | yum | zypper | xbps | apk | nix | brew | port | pkg | pkg_add | winget | scoop | choco
SUDO_CMD=""
MACOS_VERSION=""
MACOS_MAJOR=""

# ==============================================================================
# Usage / Help
# ==============================================================================
show_help() {
    cat <<EOF
${BOLD}Neovim Config - Universal Installer & Updater${RESET}

${BOLD}Uso / Usage:${RESET}
  $INSTALLER_BIN_NAME [opções / options]

${BOLD}Opções / Options:${RESET}
  (sem argumentos)      Modo interativo (pergunta opcionais 1 por 1 ou oferece update)
  -u, --update, update  Atualiza repositório (~/.config/nvim), plugins, parsers e dependências
  --quick-update        Atualiza apenas o repositório Git e os plugins do Neovim
  -y, --yes, --all      Modo não-interativo: instala essenciais + TODOS os opcionais
  --minimal             Modo não-interativo: instala apenas dependências essenciais + config
  --dry-run             Simula as etapas sem executar alterações no sistema
  -h, --help            Exibe esta mensagem de ajuda

${BOLD}Exemplos / Examples:${RESET}
  $INSTALLER_BIN_NAME              # Instalação interativa passo a passo
  $INSTALLER_BIN_NAME --update     # Atualiza a configuração, plugins e ferramentas
  $INSTALLER_BIN_NAME --all        # Instala tudo automaticamente sem perguntar
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -u|--update|update)
                MODE="update"
                ;;
            --quick-update|quick-update)
                MODE="quick-update"
                ;;
            -y|--yes|--all)
                AUTO_YES=1
                ;;
            --minimal|--no-optional)
                MINIMAL_ONLY=1
                ;;
            --dry-run)
                DRY_RUN=1
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            *)
                warn "Opção desconhecida ignorada: $1"
                ;;
        esac
        shift
    done
}

# ==============================================================================
# Terminal Input Helpers (Works even when piped via `curl -fsSL ... | bash`)
# ==============================================================================
read_tty() {
    local prompt_text="$1"
    local reply_var=""
    if [ -t 0 ]; then
        printf "%b" "$prompt_text" >&2
        read -r reply_var || reply_var=""
    elif [ -z "${BASH_SOURCE[0]:-}" ] && [ -e /dev/tty ]; then
        printf "%b" "$prompt_text" > /dev/tty
        read -r reply_var < /dev/tty || reply_var=""
    else
        printf "%b" "$prompt_text" >&2
        read -r reply_var || reply_var=""
    fi
    printf "%s" "$reply_var"
}

ask_yes_no() {
    local question="$1"
    local default="${2:-N}"
    local hint="[s/N]"
    if [ "$default" = "Y" ] || [ "$default" = "y" ]; then
        hint="[S/n]"
    fi

    if [ "$AUTO_YES" -eq 1 ]; then
        return 0
    fi
    if [ "$MINIMAL_ONLY" -eq 1 ]; then
        return 1
    fi

    while true; do
        local ans
        ans="$(read_tty "${CYAN}?${RESET} ${BOLD}${question}${RESET} ${DIM}${hint}${RESET}: ")"
        ans="$(printf "%s" "$ans" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        if [ -z "$ans" ]; then
            ans="$(printf "%s" "$default" | tr '[:upper:]' '[:lower:]')"
        fi
        case "$ans" in
            s|sim|y|yes|1) return 0 ;;
            n|nao|não|no|0) return 1 ;;
            *) printf "${YELLOW}  Por favor, responda 's' (sim) ou 'n' (não).${RESET}\n" ;;
        esac
    done
}

# ==============================================================================
# System, OS, Architecture & Package Manager Detection
# ==============================================================================
detect_privilege_escalation() {
    if [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ]; then
        SUDO_CMD=""
    elif command -v sudo >/dev/null 2>&1; then
        SUDO_CMD="sudo"
    elif command -v doas >/dev/null 2>&1; then
        SUDO_CMD="doas"
    else
        SUDO_CMD=""
    fi
}

ensure_local_paths() {
    mkdir -p "$LOCAL_BIN_DIR"
    export PATH="$LOCAL_BIN_DIR:$HOME/.cargo/bin:$PATH"
    if [ -d "/opt/homebrew/bin" ]; then
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
    fi
    if [ -d "/usr/local/bin" ]; then
        export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
    fi
    if [ -d "/opt/local/bin" ]; then
        export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
    fi
    if [ -d "/Library/TeX/texbin" ]; then
        export PATH="/Library/TeX/texbin:$PATH"
    fi
}

detect_system() {
    ensure_local_paths
    detect_privilege_escalation

    local uname_s
    uname_s="$(uname -s 2>/dev/null || echo Unknown)"
    ARCH_RAW="$(uname -m 2>/dev/null || echo unknown)"

    case "$ARCH_RAW" in
        x86_64|amd64|x64)
            ARCH_NORM="x86_64"
            ;;
        aarch64|arm64|armv8*)
            ARCH_NORM="arm64"
            ;;
        i386|i686|x86)
            ARCH_NORM="i686"
            ;;
        *)
            ARCH_NORM="$ARCH_RAW"
            ;;
    esac

    case "$uname_s" in
        Linux*)
            OS_FAMILY="linux"
            detect_linux_distro
            ;;
        Darwin*)
            OS_FAMILY="macos"
            OS_DISTRO="macos"
            MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo "10.15")"
            MACOS_MAJOR="$(printf "%s" "$MACOS_VERSION" | cut -d. -f1)"
            if command -v brew >/dev/null 2>&1; then
                PKG_MGR="brew"
            elif command -v port >/dev/null 2>&1; then
                PKG_MGR="port"
            else
                PKG_MGR="brew"
            fi
            ;;
        FreeBSD*)
            OS_FAMILY="bsd"
            OS_DISTRO="freebsd"
            PKG_MGR="pkg"
            ;;
        OpenBSD*)
            OS_FAMILY="bsd"
            OS_DISTRO="openbsd"
            PKG_MGR="pkg_add"
            ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT*)
            OS_FAMILY="windows"
            OS_DISTRO="windows"
            if command -v winget.exe >/dev/null 2>&1 || command -v winget >/dev/null 2>&1; then
                PKG_MGR="winget"
            elif command -v scoop >/dev/null 2>&1; then
                PKG_MGR="scoop"
            elif command -v choco.exe >/dev/null 2>&1 || command -v choco >/dev/null 2>&1; then
                PKG_MGR="choco"
            elif command -v pacman >/dev/null 2>&1; then
                PKG_MGR="msys-pacman"
            else
                PKG_MGR="winget"
            fi
            ;;
        *)
            OS_FAMILY="linux"
            detect_linux_distro
            ;;
    esac
}

detect_linux_distro() {
    local id=""
    local id_like=""
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        id="${ID:-}"
        id_like="${ID_LIKE:-}"
    fi

    if [ -f /etc/gentoo-release ] || [ "$id" = "gentoo" ] || [[ "$id_like" == *"gentoo"* ]] || command -v emerge >/dev/null 2>&1; then
        OS_DISTRO="gentoo"
        PKG_MGR="emerge"
    elif [ -f /etc/arch-release ] || [ "$id" = "arch" ] || [ "$id" = "manjaro" ] || [ "$id" = "endeavouros" ] || [ "$id" = "cachyos" ] || [[ "$id_like" == *"arch"* ]] || command -v pacman >/dev/null 2>&1; then
        OS_DISTRO="arch"
        PKG_MGR="pacman"
    elif [ -f /etc/debian_version ] || [ "$id" = "debian" ] || [ "$id" = "ubuntu" ] || [ "$id" = "linuxmint" ] || [ "$id" = "pop" ] || [[ "$id_like" == *"debian"* ]] || [[ "$id_like" == *"ubuntu"* ]] || command -v apt-get >/dev/null 2>&1; then
        OS_DISTRO="debian"
        PKG_MGR="apt"
    elif [ -f /etc/fedora-release ] || [ "$id" = "fedora" ] || [ "$id" = "rhel" ] || [ "$id" = "rocky" ] || [ "$id" = "almalinux" ] || [ "$id" = "centos" ] || [[ "$id_like" == *"fedora"* ]] || [[ "$id_like" == *"rhel"* ]]; then
        OS_DISTRO="fedora"
        if command -v dnf >/dev/null 2>&1; then
            PKG_MGR="dnf"
        else
            PKG_MGR="yum"
        fi
    elif [ "$id" = "opensuse-tumbleweed" ] || [ "$id" = "opensuse-leap" ] || [[ "$id_like" == *"suse"* ]] || command -v zypper >/dev/null 2>&1; then
        OS_DISTRO="opensuse"
        PKG_MGR="zypper"
    elif [ "$id" = "void" ] || command -v xbps-install >/dev/null 2>&1; then
        OS_DISTRO="void"
        PKG_MGR="xbps"
    elif [ -f /etc/alpine-release ] || [ "$id" = "alpine" ] || command -v apk >/dev/null 2>&1; then
        OS_DISTRO="alpine"
        PKG_MGR="apk"
    elif [ "$id" = "nixos" ] || command -v nix-env >/dev/null 2>&1; then
        OS_DISTRO="nix"
        PKG_MGR="nix"
    elif command -v eopkg >/dev/null 2>&1; then
        OS_DISTRO="solus"
        PKG_MGR="eopkg"
    elif command -v swupd >/dev/null 2>&1; then
        OS_DISTRO="clearlinux"
        PKG_MGR="swupd"
    elif command -v slackpkg >/dev/null 2>&1; then
        OS_DISTRO="slackware"
        PKG_MGR="slackpkg"
    else
        OS_DISTRO="generic-linux"
        PKG_MGR="binary"
    fi
}

run_priv() {
    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] ${SUDO_CMD:+$SUDO_CMD }$*"
        return 0
    fi
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" "$@"
    else
        "$@"
    fi
}

# ==============================================================================
# Pure Bash Version Comparison Helpers (Portable on macOS Bash 3.2, BSD & Linux)
# ==============================================================================
version_ge() {
    local v1="${1#v}"
    local v2="${2#v}"
    v1="${v1%%[-+]*}"
    v2="${v2%%[-+]*}"
    local v1_maj=0 v1_min=0 v1_pat=0
    local v2_maj=0 v2_min=0 v2_pat=0
    IFS=. read -r v1_maj v1_min v1_pat <<EOF
$v1
EOF
    IFS=. read -r v2_maj v2_min v2_pat <<EOF
$v2
EOF
    v1_maj="${v1_maj:-0}"; v1_min="${v1_min:-0}"; v1_pat="${v1_pat:-0}"
    v2_maj="${v2_maj:-0}"; v2_min="${v2_min:-0}"; v2_pat="${v2_pat:-0}"

    if [ "$v1_maj" -gt "$v2_maj" ] 2>/dev/null; then return 0; fi
    if [ "$v1_maj" -lt "$v2_maj" ] 2>/dev/null; then return 1; fi
    if [ "$v1_min" -gt "$v2_min" ] 2>/dev/null; then return 0; fi
    if [ "$v1_min" -lt "$v2_min" ] 2>/dev/null; then return 1; fi
    if [ "$v1_pat" -ge "$v2_pat" ] 2>/dev/null; then return 0; fi
    return 1
}

get_nvim_version() {
    if ! command -v nvim >/dev/null 2>&1; then
        echo "0.0.0"
        return
    fi
    nvim --version 2>/dev/null | head -n1 | sed -E 's/.*v([0-9]+\.[0-9]+\.[0-9]+).*/\1/' || echo "0.0.0"
}

get_treesitter_version() {
    if ! command -v tree-sitter >/dev/null 2>&1; then
        echo "0.0.0"
        return
    fi
    tree-sitter --version 2>/dev/null | awk '{print $2}' | sed -E 's/^v//' || echo "0.0.0"
}

# ==============================================================================
# Interactive Questions (1 by 1 Before Any Installation)
# ==============================================================================
prompt_existing_installation_mode() {
    if [ "$MODE" != "interactive" ] || [ "$AUTO_YES" -eq 1 ] || [ "$MINIMAL_ONLY" -eq 1 ]; then
        return
    fi

    if [ -d "$NVIM_CONFIG_DIR/.git" ]; then
        local origin_url
        origin_url="$(git -C "$NVIM_CONFIG_DIR" remote get-url origin 2>/dev/null || echo "")"
        if [[ "$origin_url" == *"nvim_config"* ]]; then
            printf "\n${GREEN}${BOLD}Configuração do Neovim já detectada em:${RESET} %s\n" "$NVIM_CONFIG_DIR"
            printf "O que você deseja fazer?\n"
            printf "  ${BOLD}1)${RESET} Atualizar tudo (repositório, plugins, parsers e manter/atualizar dependências) ${DIM}[Padrão]${RESET}\n"
            printf "  ${BOLD}2)${RESET} Instalação completa / Escolher dependências opcionais 1 por 1\n"
            printf "  ${BOLD}3)${RESET} Atualização rápida (apenas git pull + atualizar plugins do Neovim)\n"
            local choice
            choice="$(read_tty "${CYAN}?${RESET} Escolha uma opção ${DIM}[1/2/3]${RESET}: ")"
            choice="$(printf "%s" "$choice" | tr -d '[:space:]')"
            case "$choice" in
                2) MODE="interactive" ;;
                3) MODE="quick-update" ;;
                *) MODE="update" ;;
            esac
        fi
    fi
}

ask_optional_dependencies() {
    if [ "$MODE" = "quick-update" ]; then
        return
    fi

    if [ "$MODE" = "update" ] && [ "$AUTO_YES" -eq 0 ] && [ "$MINIMAL_ONLY" -eq 0 ]; then
        # In update mode, auto-detect already installed optionals and ask if user wants to configure new ones
        command -v lazygit >/dev/null 2>&1 && OPT_LAZYGIT=1
        command -v cargo >/dev/null 2>&1 && OPT_RUST=1
        command -v gdb >/dev/null 2>&1 && OPT_GDB=1
        command -v latexmk >/dev/null 2>&1 && OPT_LATEX=1
        command -v agy >/dev/null 2>&1 && OPT_AGY=1
        command -v claude >/dev/null 2>&1 && OPT_CLAUDE=1
        command -v ollama >/dev/null 2>&1 && OPT_OLLAMA=1

        if ! ask_yes_no "Deseja revisar/instalar pacotes opcionais adicionais 1 por 1 durante este update?" "N"; then
            return
        fi
    fi

    if [ "$MINIMAL_ONLY" -eq 1 ]; then
        info "Modo minimalista selecionado: pulando pacotes opcionais."
        return
    fi

    if [ "$AUTO_YES" -eq 1 ]; then
        OPT_LAZYGIT=1
        OPT_RUST=1
        OPT_GDB=1
        OPT_LATEX=1
        OPT_NERDFONT=1
        OPT_AGY=1
        OPT_CLAUDE=1
        OPT_OLLAMA=1
        return
    fi

    step "Seleção de Dependências Opcionais (1 por 1)"
    printf "As dependências essenciais (${BOLD}Neovim >= 0.10, Git, GCC/Clang, Make, tree-sitter CLI, ripgrep, fd, Node.js, Python 3${RESET})\n"
    printf "serão instaladas automaticamente.\n\n"
    printf "Responda abaixo sobre cada pacote opcional. ${BOLD}A instalação começará somente após todas as perguntas.${RESET}\n\n"

    # 1. Lazygit
    if ask_yes_no "[1/8] Instalar Lazygit (Interface Git interativa em tela cheia via <leader>gg)?" "Y"; then
        OPT_LAZYGIT=1
    fi

    # 2. Rust & Cargo
    if ask_yes_no "[2/8] Instalar Rust, Cargo & rust-analyzer (Desenvolvimento Rust e LSP)?" "Y"; then
        OPT_RUST=1
    fi

    # 3. GDB / Debugger
    if ask_yes_no "[3/8] Instalar GDB / LLDB Debugger (Debug rápido no terminal via <leader>db)?" "Y"; then
        OPT_GDB=1
    fi

    # 4. LaTeX & Zathura
    if ask_yes_no "[4/8] Instalar Suíte LaTeX (TeXLive + latexmk + Zathura PDF preview para VimTeX)?" "N"; then
        OPT_LATEX=1
    fi

    # 5. Nerd Font
    if ask_yes_no "[5/8] Instalar JetBrains Mono Nerd Font (Ícones para statusline, NvimTree e Telescope)?" "Y"; then
        OPT_NERDFONT=1
    fi

    # 6. Google Antigravity CLI (agy)
    if ask_yes_no "[6/8] Instalar / Configurar Google Antigravity CLI ('agy' - Agente IA no painel <leader>ai)?" "N"; then
        OPT_AGY=1
    fi

    # 7. Claude Code CLI (claude)
    if ask_yes_no "[7/8] Instalar Claude Code CLI ('claude' - Assistente IA no painel <leader>ci)?" "N"; then
        OPT_CLAUDE=1
    fi

    # 8. Ollama
    if ask_yes_no "[8/8] Instalar Ollama ('ollama' - Modelos LLM locais offline para autocompletar <C-y>)?" "N"; then
        OPT_OLLAMA=1
    fi
}

print_plan_summary() {
    step "Resumo do Plano de Execução"
    local sys_extra=""
    [ "$OS_FAMILY" = "macos" ] && sys_extra=" macOS ${MACOS_VERSION}"
    printf "  • ${BOLD}Sistema Detectado:${RESET}     %s (%s / %s%s)\n" "$OS_DISTRO" "$OS_FAMILY" "$ARCH_NORM" "$sys_extra"
    printf "  • ${BOLD}Gerenciador Pacotes:${RESET}   %s\n" "$PKG_MGR"
    printf "  • ${BOLD}Diretório Config:${RESET}      %s\n" "$NVIM_CONFIG_DIR"
    if [ "$OS_FAMILY" != "windows" ]; then
        printf "  • ${BOLD}Script em PATH:${RESET}        %s\n" "$INSTALLER_BIN_PATH"
    fi
    printf "  • ${BOLD}Pacotes Essenciais:${RESET}    nvim, git, cc/make, tree-sitter, rg, fd, node/npm, python3\n"
    if [ "$MODE" != "quick-update" ]; then
        printf "  • ${BOLD}Opcionais Escolhidos:${RESET}\n"
        printf "      - Lazygit:               %s\n" "$([ "$OPT_LAZYGIT" -eq 1 ] && echo "SIM" || echo "não")"
        printf "      - Rust & Cargo:          %s\n" "$([ "$OPT_RUST" -eq 1 ] && echo "SIM" || echo "não")"
        printf "      - GDB / Debugger:        %s\n" "$([ "$OPT_GDB" -eq 1 ] && echo "SIM" || echo "não")"
        printf "      - LaTeX & Zathura:       %s\n" "$([ "$OPT_LATEX" -eq 1 ] && echo "SIM" || echo "não")"
        printf "      - JetBrains Nerd Font:   %s\n" "$([ "$OPT_NERDFONT" -eq 1 ] && echo "SIM" || echo "não")"
        printf "      - Antigravity CLI (agy): %s\n" "$([ "$OPT_AGY" -eq 1 ] && echo "SIM" || echo "não")"
        printf "      - Claude Code CLI:       %s\n" "$([ "$OPT_CLAUDE" -eq 1 ] && echo "SIM" || echo "não")"
        printf "      - Ollama (Local LLM):    %s\n" "$([ "$OPT_OLLAMA" -eq 1 ] && echo "SIM" || echo "não")"
    fi
    printf "\n"
}

# ==============================================================================
# macOS Bootstrap (Xcode CLT & Homebrew / MacPorts for ARM64 & Older x86_64)
# ==============================================================================
setup_macos_environment() {
    if [ "$OS_FAMILY" != "macos" ]; then
        return
    fi

    info "Verificando ambiente macOS ($ARCH_NORM, macOS ${MACOS_VERSION:-unknown})..."

    # Ensure Xcode Command Line Tools (provides clang, make, git, lldb)
    if ! xcode-select -p >/dev/null 2>&1; then
        warn "Xcode Command Line Tools não encontrado. Solicitando instalação..."
        if [ "$DRY_RUN" -eq 0 ]; then
            xcode-select --install 2>/dev/null || true
        fi
    fi

    ensure_local_paths

    if ! command -v brew >/dev/null 2>&1 && ! command -v port >/dev/null 2>&1; then
        info "Homebrew/MacPorts não encontrado. Instalando Homebrew..."
        if [ "$DRY_RUN" -eq 0 ]; then
            NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || \
                warn "Homebrew não pôde ser instalado (comum em macOS x86_64 muito antigo); usaremos binários pré-compilados."
            ensure_local_paths
        fi
    fi
}

# ==============================================================================
# Standalone Prebuilt Binary Fallbacks (Linux, macOS x86_64/arm64, Windows)
# ==============================================================================
install_nvim_binary_fallback() {
    local cur_ver
    cur_ver="$(get_nvim_version)"
    if version_ge "$cur_ver" "0.10.0"; then
        success "Neovim v$cur_ver já atende ao requisito (>= 0.10.0)."
        return 0
    fi

    info "Instalando Neovim (>= 0.10.0) oficial pré-compilado em ~/.local..."
    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t 'nvim-install')"
    local url=""
    local archive="$tmp_dir/nvim.tar.gz"

    if [ "$OS_FAMILY" = "linux" ]; then
        if [ "$ARCH_NORM" = "x86_64" ]; then
            url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
        elif [ "$ARCH_NORM" = "arm64" ]; then
            url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz"
        fi
    elif [ "$OS_FAMILY" = "macos" ]; then
        if [ "$ARCH_NORM" = "arm64" ]; then
            url="https://github.com/neovim/neovim/releases/latest/download/nvim-macos-arm64.tar.gz"
        else
            url="https://github.com/neovim/neovim/releases/latest/download/nvim-macos-x86_64.tar.gz"
        fi
    fi

    if [ -n "$url" ]; then
        if curl -fL "$url" -o "$archive" 2>/dev/null || ( [ "$OS_FAMILY" = "linux" ] && [ "$ARCH_NORM" = "x86_64" ] && curl -fL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz" -o "$archive" 2>/dev/null ); then
            rm -rf "$HOME/.local/share/nvim-release"
            mkdir -p "$HOME/.local/share/nvim-release"
            tar -xzf "$archive" -C "$HOME/.local/share/nvim-release" --strip-components=1
            if [ "$OS_FAMILY" = "macos" ] && command -v xattr >/dev/null 2>&1; then
                xattr -cr "$HOME/.local/share/nvim-release" 2>/dev/null || true
            fi
            ln -sf "$HOME/.local/share/nvim-release/bin/nvim" "$LOCAL_BIN_DIR/nvim"
            success "Neovim $(get_nvim_version) instalado em $LOCAL_BIN_DIR/nvim"
        else
            warn "Não foi possível baixar o binário oficial do Neovim de $url"
        fi
    fi
    rm -rf "$tmp_dir"
}

install_treesitter_binary_fallback() {
    local cur_ver
    cur_ver="$(get_treesitter_version)"
    if version_ge "$cur_ver" "0.25.0"; then
        success "tree-sitter CLI v$cur_ver já instalado (>= 0.25.0)."
        return 0
    fi

    info "Instalando tree-sitter CLI (v0.25+) em $LOCAL_BIN_DIR/tree-sitter..."
    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi

    local asset=""
    if [ "$OS_FAMILY" = "linux" ]; then
        if [ "$ARCH_NORM" = "x86_64" ]; then
            asset="tree-sitter-linux-x64.gz"
        elif [ "$ARCH_NORM" = "arm64" ]; then
            asset="tree-sitter-linux-arm64.gz"
        elif [ "$ARCH_NORM" = "i686" ]; then
            asset="tree-sitter-linux-x86.gz"
        fi
    elif [ "$OS_FAMILY" = "macos" ]; then
        if [ "$ARCH_NORM" = "arm64" ]; then
            asset="tree-sitter-macos-arm64.gz"
        else
            asset="tree-sitter-macos-x64.gz"
        fi
    elif [ "$OS_FAMILY" = "windows" ]; then
        asset="tree-sitter-windows-x64.gz"
    fi

    if [ -n "$asset" ]; then
        local url="https://github.com/tree-sitter/tree-sitter/releases/latest/download/$asset"
        local tmp_gz="$LOCAL_BIN_DIR/tree-sitter.gz"
        if curl -fsSL "$url" -o "$tmp_gz" 2>/dev/null; then
            gzip -df "$tmp_gz"
            if [ "$OS_FAMILY" = "windows" ]; then
                mv -f "$LOCAL_BIN_DIR/tree-sitter" "$LOCAL_BIN_DIR/tree-sitter.exe" 2>/dev/null || true
            else
                chmod +x "$LOCAL_BIN_DIR/tree-sitter"
                if [ "$OS_FAMILY" = "macos" ] && command -v xattr >/dev/null 2>&1; then
                    xattr -cr "$LOCAL_BIN_DIR/tree-sitter" 2>/dev/null || true
                fi
            fi
            success "tree-sitter CLI $(get_treesitter_version) instalado em $LOCAL_BIN_DIR"
            return 0
        fi
    fi

    # Fallback via npm or cargo
    if command -v npm >/dev/null 2>&1; then
        info "Tentando instalar tree-sitter-cli via npm..."
        npm install -g tree-sitter-cli --prefix "$HOME/.local" >/dev/null 2>&1 || run_priv npm install -g tree-sitter-cli >/dev/null 2>&1 || true
    elif command -v cargo >/dev/null 2>&1; then
        info "Tentando instalar tree-sitter-cli via cargo..."
        cargo install tree-sitter-cli >/dev/null 2>&1 || true
    fi
}

install_node_binary_fallback() {
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi

    info "Node.js / npm não detectado; instalando Node.js LTS pré-compilado em ~/.local..."
    local node_ver="v20.18.1"
    local node_plat=""
    if [ "$OS_FAMILY" = "linux" ] && [ "$ARCH_NORM" = "x86_64" ]; then
        node_plat="linux-x64"
    elif [ "$OS_FAMILY" = "linux" ] && [ "$ARCH_NORM" = "arm64" ]; then
        node_plat="linux-arm64"
    elif [ "$OS_FAMILY" = "macos" ] && [ "$ARCH_NORM" = "x86_64" ]; then
        node_plat="darwin-x64"
    elif [ "$OS_FAMILY" = "macos" ] && [ "$ARCH_NORM" = "arm64" ]; then
        node_plat="darwin-arm64"
    fi

    if [ -n "$node_plat" ]; then
        local tmp_dir
        tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t 'node-install')"
        local url="https://nodejs.org/dist/${node_ver}/node-${node_ver}-${node_plat}.tar.gz"
        if curl -fsSL "$url" -o "$tmp_dir/node.tar.gz" 2>/dev/null; then
            rm -rf "$HOME/.local/share/node-lts"
            mkdir -p "$HOME/.local/share/node-lts"
            tar -xzf "$tmp_dir/node.tar.gz" -C "$HOME/.local/share/node-lts" --strip-components=1
            ln -sf "$HOME/.local/share/node-lts/bin/node" "$LOCAL_BIN_DIR/node"
            ln -sf "$HOME/.local/share/node-lts/bin/npm" "$LOCAL_BIN_DIR/npm"
            ln -sf "$HOME/.local/share/node-lts/bin/npx" "$LOCAL_BIN_DIR/npx"
            success "Node.js $(node --version 2>/dev/null) instalado em $LOCAL_BIN_DIR"
        fi
        rm -rf "$tmp_dir"
    fi
}

install_rg_fd_fallbacks() {
    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi

    # On Debian/Ubuntu/Fedora, fd is often installed as `fdfind`
    if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
        ln -sf "$(command -v fdfind)" "$LOCAL_BIN_DIR/fd"
        success "Symlink criado: $LOCAL_BIN_DIR/fd -> $(command -v fdfind)"
    fi

    # Fallback for ripgrep (rg) if missing (e.g. older macOS x86_64 or minimal Linux)
    if ! command -v rg >/dev/null 2>&1; then
        info "Instalando ripgrep (rg) via binário pré-compilado do GitHub..."
        local rg_ver="14.1.1"
        local rg_target=""
        if [ "$OS_FAMILY" = "linux" ] && [ "$ARCH_NORM" = "x86_64" ]; then
            rg_target="x86_64-unknown-linux-musl"
        elif [ "$OS_FAMILY" = "linux" ] && [ "$ARCH_NORM" = "arm64" ]; then
            rg_target="aarch64-unknown-linux-gnu"
        elif [ "$OS_FAMILY" = "macos" ] && [ "$ARCH_NORM" = "x86_64" ]; then
            rg_target="x86_64-apple-darwin"
        elif [ "$OS_FAMILY" = "macos" ] && [ "$ARCH_NORM" = "arm64" ]; then
            rg_target="aarch64-apple-darwin"
        fi

        if [ -n "$rg_target" ]; then
            local tmp_dir
            tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t 'rg-install')"
            local url="https://github.com/BurntSushi/ripgrep/releases/download/${rg_ver}/ripgrep-${rg_ver}-${rg_target}.tar.gz"
            if curl -fsSL "$url" -o "$tmp_dir/rg.tar.gz" 2>/dev/null; then
                tar -xzf "$tmp_dir/rg.tar.gz" -C "$tmp_dir" --strip-components=1
                cp -f "$tmp_dir/rg" "$LOCAL_BIN_DIR/rg"
                chmod +x "$LOCAL_BIN_DIR/rg"
                if [ "$OS_FAMILY" = "macos" ] && command -v xattr >/dev/null 2>&1; then
                    xattr -cr "$LOCAL_BIN_DIR/rg" 2>/dev/null || true
                fi
                success "ripgrep instalado em $LOCAL_BIN_DIR/rg"
            fi
            rm -rf "$tmp_dir"
        fi
    fi

    # Fallback for fd if still missing
    if ! command -v fd >/dev/null 2>&1; then
        info "Instalando fd via binário pré-compilado do GitHub..."
        local fd_ver="v10.2.0"
        local fd_target=""
        if [ "$OS_FAMILY" = "linux" ] && [ "$ARCH_NORM" = "x86_64" ]; then
            fd_target="x86_64-unknown-linux-musl"
        elif [ "$OS_FAMILY" = "linux" ] && [ "$ARCH_NORM" = "arm64" ]; then
            fd_target="aarch64-unknown-linux-gnu"
        elif [ "$OS_FAMILY" = "macos" ] && [ "$ARCH_NORM" = "x86_64" ]; then
            fd_target="x86_64-apple-darwin"
        elif [ "$OS_FAMILY" = "macos" ] && [ "$ARCH_NORM" = "arm64" ]; then
            fd_target="aarch64-apple-darwin"
        fi

        if [ -n "$fd_target" ]; then
            local tmp_dir
            tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t 'fd-install')"
            local url="https://github.com/sharkdp/fd/releases/download/${fd_ver}/fd-${fd_ver}-${fd_target}.tar.gz"
            if curl -fsSL "$url" -o "$tmp_dir/fd.tar.gz" 2>/dev/null; then
                tar -xzf "$tmp_dir/fd.tar.gz" -C "$tmp_dir" --strip-components=1
                cp -f "$tmp_dir/fd" "$LOCAL_BIN_DIR/fd"
                chmod +x "$LOCAL_BIN_DIR/fd"
                if [ "$OS_FAMILY" = "macos" ] && command -v xattr >/dev/null 2>&1; then
                    xattr -cr "$LOCAL_BIN_DIR/fd" 2>/dev/null || true
                fi
                success "fd instalado em $LOCAL_BIN_DIR/fd"
            fi
            rm -rf "$tmp_dir"
        fi
    fi
}

# ==============================================================================
# Essential Dependencies Installation Across All Operating Systems
# ==============================================================================
install_essential_dependencies() {
    step "Instalando Dependências Essenciais ($OS_DISTRO / $PKG_MGR)"

    case "$PKG_MGR" in
        emerge)
            info "Gentoo Linux detectado. Instalando pacotes essenciais via Portage (emerge --noreplace)..."
            run_priv emerge --noreplace --quiet-build=y \
                app-editors/neovim \
                dev-vcs/git \
                sys-devel/gcc \
                sys-devel/make \
                sys-apps/ripgrep \
                sys-apps/fd \
                net-libs/nodejs \
                dev-lang/python \
                net-misc/curl \
                app-arch/unzip \
                app-arch/tar \
                app-arch/gzip || warn "Alguns pacotes do emerge retornaram aviso; verificando binários..."
            run_priv emerge --noreplace dev-util/tree-sitter-cli 2>/dev/null || true
            ;;

        pacman)
            info "Arch Linux / derivado detectado. Instalando pacotes via pacman..."
            run_priv pacman -Sy --needed --noconfirm \
                neovim git base-devel gcc make ripgrep fd nodejs npm python python-pip \
                tree-sitter-cli curl wget unzip tar gzip
            ;;

        apt)
            info "Debian / Ubuntu / derivado detectado. Instalando pacotes via apt..."
            run_priv apt-get update -y
            run_priv env DEBIAN_FRONTEND=noninteractive apt-get install -y \
                git build-essential gcc g++ make ripgrep fd-find nodejs npm \
                python3 python3-pip python3-venv curl wget unzip tar gzip xclip wl-clipboard || \
            run_priv env DEBIAN_FRONTEND=noninteractive apt-get install -y \
                git build-essential gcc g++ make ripgrep fd-find nodejs npm \
                python3 python3-pip curl wget unzip tar gzip
            run_priv env DEBIAN_FRONTEND=noninteractive apt-get install -y neovim tree-sitter-cli 2>/dev/null || true
            ;;

        dnf|yum)
            info "Fedora / RHEL / derivado detectado. Instalando pacotes via $PKG_MGR..."
            run_priv "$PKG_MGR" install -y \
                neovim git gcc gcc-c++ make ripgrep fd-find nodejs npm \
                python3 python3-pip curl wget unzip tar gzip
            run_priv "$PKG_MGR" install -y tree-sitter-cli 2>/dev/null || true
            ;;

        zypper)
            info "openSUSE detectado. Instalando pacotes via zypper..."
            run_priv zypper --non-interactive install \
                neovim git gcc gcc-c++ make ripgrep fd nodejs npm \
                python3 python3-pip tree-sitter curl wget unzip tar gzip
            ;;

        xbps)
            info "Void Linux detectado. Instalando pacotes via xbps-install..."
            run_priv xbps-install -Sy \
                neovim git base-devel gcc make ripgrep fd nodejs \
                python3 python3-pip tree-sitter curl wget unzip tar gzip
            ;;

        apk)
            info "Alpine Linux detectado. Instalando pacotes via apk..."
            run_priv apk add --no-cache \
                neovim git build-base gcc g++ make ripgrep fd nodejs npm \
                python3 py3-pip tree-sitter-cli curl wget unzip tar gzip bash
            ;;

        nix)
            info "NixOS / Nix detectado. Instalando pacotes via nix-env..."
            nix-env -iA \
                nixpkgs.neovim nixpkgs.git nixpkgs.gcc nixpkgs.gnumake \
                nixpkgs.ripgrep nixpkgs.fd nixpkgs.nodejs nixpkgs.python3 \
                nixpkgs.tree-sitter nixpkgs.curl nixpkgs.unzip
            ;;

        eopkg)
            run_priv eopkg install -y neovim git gcc make ripgrep fd nodejs python3 curl unzip tar gzip
            ;;

        swupd)
            run_priv swupd bundle-add neovim git c-basic ripgrep fd nodejs-basic python3-basic curl
            ;;

        slackpkg)
            run_priv slackpkg install neovim git gcc make llvm nodejs python3 curl infozip
            ;;

        brew)
            setup_macos_environment
            info "macOS ($ARCH_NORM, v$MACOS_VERSION) detectado. Instalando pacotes essenciais via Homebrew..."
            brew install neovim git ripgrep fd node python tree-sitter curl unzip || \
                warn "Homebrew reportou aviso (comum em versões mais antigas do macOS x86_64). Ativando fallbacks binários..."
            ;;

        port)
            setup_macos_environment
            info "macOS ($ARCH_NORM, v$MACOS_VERSION) detectado. Instalando pacotes essenciais via MacPorts..."
            run_priv port -N install neovim git ripgrep fd nodejs20 npm10 python312 curl unzip || true
            ;;

        pkg)
            info "FreeBSD detectado. Instalando pacotes via pkg..."
            run_priv pkg install -y neovim git gcc gmake ripgrep fd-find node npm python3 tree-sitter curl unzip
            ;;

        pkg_add)
            info "OpenBSD detectado. Instalando pacotes via pkg_add..."
            run_priv pkg_add neovim git gmake ripgrep fd node python3 curl unzip
            ;;

        winget)
            info "Windows detectado. Instalando pacotes essenciais via winget..."
            local winget_bin="winget"
            command -v winget.exe >/dev/null 2>&1 && winget_bin="winget.exe"
            "$winget_bin" install --id Neovim.Neovim -e --accept-source-agreements --accept-package-agreements || true
            "$winget_bin" install --id Git.Git -e --accept-source-agreements --accept-package-agreements || true
            "$winget_bin" install --id BurntSushi.ripgrep.MSVC -e --accept-source-agreements --accept-package-agreements || true
            "$winget_bin" install --id sharkdp.fd -e --accept-source-agreements --accept-package-agreements || true
            "$winget_bin" install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements || true
            "$winget_bin" install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements || true
            "$winget_bin" install --id BrechtSanders.WinLibs.POSIX.UCRT -e --accept-source-agreements --accept-package-agreements || true
            "$winget_bin" install --id Tree-sitter.Tree-sitter-CLI -e --accept-source-agreements --accept-package-agreements 2>/dev/null || true
            ;;

        scoop)
            info "Windows detectado. Instalando pacotes essenciais via Scoop..."
            scoop install neovim git gcc make ripgrep fd nodejs-lts python tree-sitter
            ;;

        choco)
            info "Windows detectado. Instalando pacotes essenciais via Chocolatey..."
            choco install -y neovim git mingw make ripgrep fd nodejs-lts python3
            ;;

        msys-pacman)
            info "MSYS2 detectado. Instalando pacotes essenciais via pacman..."
            pacman -S --needed --noconfirm \
                mingw-w64-x86_64-neovim git base-devel mingw-w64-x86_64-gcc make \
                mingw-w64-x86_64-ripgrep mingw-w64-x86_64-fd mingw-w64-x86_64-nodejs \
                mingw-w64-x86_64-python mingw-w64-x86_64-tree-sitter curl unzip
            ;;
    esac

    # Universal post-verification & fallbacks for Neovim >= 0.10, Node.js, tree-sitter >= 0.25, rg, fd
    install_nvim_binary_fallback
    install_node_binary_fallback
    install_treesitter_binary_fallback
    install_rg_fd_fallbacks
    success "Dependências essenciais instaladas e verificadas!"
}

# ==============================================================================
# Optional Dependencies Installation (Executed After All Prompts)
# ==============================================================================
install_opt_lazygit() {
    [ "$OPT_LAZYGIT" -ne 1 ] && return 0
    step "Instalando Opcional [1/8]: Lazygit"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Instalaria lazygit"
        return 0
    fi

    case "$PKG_MGR" in
        emerge)      run_priv emerge --noreplace dev-vcs/lazygit 2>/dev/null || true ;;
        pacman)      run_priv pacman -S --needed --noconfirm lazygit || true ;;
        apt)         run_priv apt-get install -y lazygit 2>/dev/null || true ;;
        dnf)
            run_priv dnf copr enable atim/lazygit -y 2>/dev/null || true
            run_priv dnf install -y lazygit 2>/dev/null || true
            ;;
        zypper)      run_priv zypper --non-interactive install lazygit 2>/dev/null || true ;;
        xbps)        run_priv xbps-install -Sy lazygit 2>/dev/null || true ;;
        apk)         run_priv apk add --no-cache lazygit 2>/dev/null || true ;;
        nix)         nix-env -iA nixpkgs.lazygit 2>/dev/null || true ;;
        brew)        brew install lazygit || true ;;
        port)        run_priv port -N install lazygit || true ;;
        pkg)         run_priv pkg install -y lazygit || true ;;
        winget)
            local w="winget"; command -v winget.exe >/dev/null 2>&1 && w="winget.exe"
            "$w" install --id JesseDuffield.lazygit -e --accept-source-agreements --accept-package-agreements || true
            ;;
        scoop)       scoop install lazygit || true ;;
        choco)       choco install -y lazygit || true ;;
    esac

    # Universal GitHub release binary fallback (POSIX sed instead of GNU grep -P for macOS/BSD compatibility)
    if ! command -v lazygit >/dev/null 2>&1; then
        info "Baixando binário oficial do Lazygit via GitHub Releases..."
        local lg_ver
        lg_ver="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n1)"
        [ -z "$lg_ver" ] && lg_ver="0.44.1"
        local lg_os=""
        local lg_arch="x86_64"
        [ "$ARCH_NORM" = "arm64" ] && lg_arch="arm64"
        if [ "$OS_FAMILY" = "linux" ]; then
            lg_os="Linux"
        elif [ "$OS_FAMILY" = "macos" ]; then
            lg_os="Darwin"
        fi

        if [ -n "$lg_os" ]; then
            local tmp_dir
            tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t 'lg-install')"
            local url="https://github.com/jesseduffield/lazygit/releases/download/v${lg_ver}/lazygit_${lg_ver}_${lg_os}_${lg_arch}.tar.gz"
            if curl -fsSL "$url" -o "$tmp_dir/lazygit.tar.gz" 2>/dev/null; then
                tar -xzf "$tmp_dir/lazygit.tar.gz" -C "$tmp_dir" lazygit
                cp -f "$tmp_dir/lazygit" "$LOCAL_BIN_DIR/lazygit"
                chmod +x "$LOCAL_BIN_DIR/lazygit"
                if [ "$OS_FAMILY" = "macos" ] && command -v xattr >/dev/null 2>&1; then
                    xattr -cr "$LOCAL_BIN_DIR/lazygit" 2>/dev/null || true
                fi
            fi
            rm -rf "$tmp_dir"
        fi
    fi

    if command -v lazygit >/dev/null 2>&1; then
        success "Lazygit instalado com sucesso!"
    else
        warn "Não foi possível instalar o Lazygit automaticamente."
    fi
}

install_opt_rust() {
    [ "$OPT_RUST" -ne 1 ] && return 0
    step "Instalando Opcional [2/8]: Rust, Cargo & rust-analyzer"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Instalaria rustc, cargo e rust-analyzer"
        return 0
    fi

    if ! command -v cargo >/dev/null 2>&1; then
        case "$PKG_MGR" in
            emerge)
                info "Gentoo: Instalando Rust (dev-lang/rust-bin ou rustup)..."
                run_priv emerge --noreplace dev-lang/rust-bin 2>/dev/null || \
                run_priv emerge --noreplace virtual/rust 2>/dev/null || \
                (curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y)
                ;;
            pacman)
                run_priv pacman -S --needed --noconfirm rust rust-analyzer || true
                ;;
            winget)
                local w="winget"; command -v winget.exe >/dev/null 2>&1 && w="winget.exe"
                "$w" install --id Rustlang.Rustup -e --accept-source-agreements --accept-package-agreements || true
                ;;
            scoop)
                scoop install rustup || true
                ;;
            choco)
                choco install -y rust || true
                ;;
            *)
                info "Instalando Rust toolchain oficial via rustup..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                ;;
        esac
    fi

    # Load cargo env if installed via rustup
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    if command -v rustup >/dev/null 2>&1; then
        rustup component add rust-analyzer clippy rustfmt 2>/dev/null || true
    fi

    if command -v cargo >/dev/null 2>&1; then
        success "Rust & Cargo ($(cargo --version 2>/dev/null)) prontos!"
    else
        warn "Rust/Cargo requer reinicialização do terminal para atualizar o PATH."
    fi
}

install_opt_gdb() {
    [ "$OPT_GDB" -ne 1 ] && return 0
    step "Instalando Opcional [3/8]: GDB / LLDB Debugger"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Instalaria gdb / lldb"
        return 0
    fi

    case "$PKG_MGR" in
        emerge)      run_priv emerge --noreplace sys-devel/gdb ;;
        pacman)      run_priv pacman -S --needed --noconfirm gdb ;;
        apt)         run_priv apt-get install -y gdb ;;
        dnf|yum)     run_priv "$PKG_MGR" install -y gdb ;;
        zypper)      run_priv zypper --non-interactive install gdb ;;
        xbps)        run_priv xbps-install -Sy gdb ;;
        apk)         run_priv apk add --no-cache gdb ;;
        nix)         nix-env -iA nixpkgs.gdb ;;
        brew)
            if [ "$ARCH_NORM" = "x86_64" ]; then
                brew install gdb || true
            else
                info "macOS ARM64: LLDB já está incluído via Xcode Command Line Tools (suportado em <leader>db)."
                brew install llvm 2>/dev/null || true
            fi
            ;;
        port)        run_priv port -N install gdb || true ;;
        pkg)         run_priv pkg install -y gdb ;;
        pkg_add)     run_priv pkg_add gdb ;;
        scoop)       scoop install gdb || true ;;
        choco)       choco install -y mingw || true ;;
        msys-pacman) pacman -S --needed --noconfirm mingw-w64-x86_64-gdb ;;
    esac

    if command -v gdb >/dev/null 2>&1 || command -v lldb >/dev/null 2>&1; then
        success "Debugger (GDB/LLDB) pronto para uso com <leader>db!"
    fi
}

install_opt_latex() {
    [ "$OPT_LATEX" -ne 1 ] && return 0
    step "Instalando Opcional [4/8]: Suíte LaTeX (TeXLive, latexmk & Zathura)"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Instalaria texlive, latexmk e zathura"
        return 0
    fi

    case "$PKG_MGR" in
        emerge)
            run_priv emerge --noreplace app-text/texlive-core dev-tex/latexmk app-text/zathura app-text/zathura-pdf-poppler || \
            run_priv emerge --noreplace app-text/texlive dev-tex/latexmk app-text/zathura app-text/zathura-pdf-mupdf || true
            ;;
        pacman)
            run_priv pacman -S --needed --noconfirm \
                texlive-basic texlive-latex texlive-latexextra texlive-mathscience texlive-binextra \
                perl-yaml-tiny perl-file-homedir zathura zathura-pdf-mupdf || true
            ;;
        apt)
            run_priv env DEBIAN_FRONTEND=noninteractive apt-get install -y \
                texlive-latex-base texlive-latex-recommended texlive-latex-extra \
                texlive-fonts-recommended texlive-science latexmk zathura || true
            ;;
        dnf|yum)
            run_priv "$PKG_MGR" install -y \
                texlive-scheme-basic texlive-latex latexmk zathura zathura-pdf-mupdf || true
            ;;
        zypper)
            run_priv zypper --non-interactive install \
                texlive-scheme-basic texlive-latex texlive-latexmk zathura zathura-plugin-pdf-poppler || true
            ;;
        xbps)
            run_priv xbps-install -Sy texlive-bin zathura zathura-pdf-mupdf || true
            ;;
        apk)
            run_priv apk add --no-cache texlive texmf-dist-latexextra zathura zathura-pdf-mupdf || true
            ;;
        nix)
            nix-env -iA nixpkgs.texlive.combined.scheme-medium nixpkgs.zathura || true
            ;;
        brew)
            brew install --cask basictex 2>/dev/null || brew install --cask mactex-no-gui 2>/dev/null || true
            export PATH="/Library/TeX/texbin:$PATH"
            brew install --cask skim 2>/dev/null || true
            ;;
        pkg)
            run_priv pkg install -y texlive-full zathura zathura-pdf-poppler || true
            ;;
        winget)
            local w="winget"; command -v winget.exe >/dev/null 2>&1 && w="winget.exe"
            "$w" install --id MiKTeX.MiKTeX -e --accept-source-agreements --accept-package-agreements || true
            "$w" install --id SumatraPDF.SumatraPDF -e --accept-source-agreements --accept-package-agreements || true
            ;;
        scoop)
            scoop install latex sumatrapdf || true
            ;;
        choco)
            choco install -y miktex sumatrapdf || true
            ;;
    esac
    success "Configuração de pacotes LaTeX concluída!"
}

install_opt_nerdfont() {
    [ "$OPT_NERDFONT" -ne 1 ] && return 0
    step "Instalando Opcional [5/8]: JetBrains Mono Nerd Font"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Instalaria JetBrains Mono Nerd Font"
        return 0
    fi

    if [ "$PKG_MGR" = "pacman" ]; then
        if run_priv pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd 2>/dev/null; then
            success "JetBrains Mono Nerd Font instalada via pacman!"
            return 0
        fi
    elif [ "$PKG_MGR" = "brew" ]; then
        if brew install --cask font-jetbrains-mono-nerd-font 2>/dev/null; then
            success "JetBrains Mono Nerd Font instalada via Homebrew!"
            return 0
        fi
    elif [ "$PKG_MGR" = "winget" ]; then
        local w="winget"; command -v winget.exe >/dev/null 2>&1 && w="winget.exe"
        "$w" install --id DEVCOM.JetBrainsMonoNerdFont -e --accept-source-agreements --accept-package-agreements 2>/dev/null && return 0
    fi

    # Direct download from Nerd Fonts GitHub Release (works on Gentoo, Debian, Fedora, older macOS, etc.)
    local font_dir=""
    if [ "$OS_FAMILY" = "macos" ]; then
        font_dir="$HOME/Library/Fonts/JetBrainsMonoNerdFont"
    else
        font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMonoNerdFont"
    fi

    mkdir -p "$font_dir"
    local tmp_dir
    tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t 'nerdfont-install')"
    local zip_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

    info "Baixando JetBrainsMono Nerd Font para $font_dir..."
    if curl -fsSL "$zip_url" -o "$tmp_dir/JetBrainsMono.zip" 2>/dev/null; then
        unzip -qo "$tmp_dir/JetBrainsMono.zip" -d "$font_dir"
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -f "$font_dir" >/dev/null 2>&1 || true
        fi
        success "JetBrains Mono Nerd Font instalada em $font_dir!"
    else
        warn "Não foi possível baixar a Nerd Font automaticamente."
    fi
    rm -rf "$tmp_dir"
}

install_opt_agy() {
    [ "$OPT_AGY" -ne 1 ] && return 0
    step "Verificando Opcional [6/8]: Google Antigravity CLI (agy)"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Verificaria/instalaria Antigravity CLI (agy)"
        return 0
    fi

    if command -v agy >/dev/null 2>&1; then
        success "Google Antigravity CLI (agy) já está instalado em $(command -v agy)!"
    elif command -v npm >/dev/null 2>&1; then
        info "Verificando pacote Antigravity CLI..."
        npm install -g @google/antigravity-cli --prefix "$HOME/.local" 2>/dev/null || \
            info "Para instalar o Antigravity CLI manualmente, consulte a documentação oficial do Google Antigravity."
    fi
}

install_opt_claude() {
    [ "$OPT_CLAUDE" -ne 1 ] && return 0
    step "Instalando Opcional [7/8]: Claude Code CLI (claude)"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Instalaria @anthropic-ai/claude-code via npm"
        return 0
    fi

    if command -v claude >/dev/null 2>&1; then
        success "Claude Code CLI já está instalado em $(command -v claude)!"
        return 0
    fi

    if command -v npm >/dev/null 2>&1; then
        info "Instalando @anthropic-ai/claude-code via npm..."
        npm install -g @anthropic-ai/claude-code --prefix "$HOME/.local" 2>/dev/null || \
        run_priv npm install -g @anthropic-ai/claude-code || \
        warn "Falha ao instalar @anthropic-ai/claude-code via npm."
    else
        warn "npm não encontrado para instalar o Claude Code CLI."
    fi

    if command -v claude >/dev/null 2>&1; then
        success "Claude Code CLI instalado com sucesso!"
    fi
}

install_opt_ollama() {
    [ "$OPT_OLLAMA" -ne 1 ] && return 0
    step "Instalando Opcional [8/8]: Ollama (Local LLM)"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Instalaria Ollama"
        return 0
    fi

    if command -v ollama >/dev/null 2>&1; then
        success "Ollama já está instalado em $(command -v ollama)!"
        return 0
    fi

    case "$OS_FAMILY" in
        linux)
            if [ "$PKG_MGR" = "pacman" ]; then
                run_priv pacman -S --needed --noconfirm ollama || true
            elif [ "$PKG_MGR" = "emerge" ]; then
                run_priv emerge --noreplace app-misc/ollama 2>/dev/null || (curl -fsSL https://ollama.com/install.sh | sh)
            else
                curl -fsSL https://ollama.com/install.sh | sh || warn "Falha ao instalar Ollama."
            fi
            ;;
        macos)
            if command -v brew >/dev/null 2>&1; then
                brew install ollama || true
            fi
            ;;
        windows)
            if [ "$PKG_MGR" = "winget" ]; then
                local w="winget"; command -v winget.exe >/dev/null 2>&1 && w="winget.exe"
                "$w" install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements || true
            elif [ "$PKG_MGR" = "scoop" ]; then
                scoop install ollama || true
            fi
            ;;
    esac

    if command -v ollama >/dev/null 2>&1; then
        success "Ollama instalado com sucesso!"
    fi
}

# ==============================================================================
# Clone or Update Repository in ~/.config/nvim (and Windows AppData link)
# ==============================================================================
clone_or_update_repo() {
    step "Configurando Repositório em $NVIM_CONFIG_DIR"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Clonaria ou atualizaria $REPO_URL em $NVIM_CONFIG_DIR"
        return 0
    fi

    mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"

    if [ -d "$NVIM_CONFIG_DIR/.git" ]; then
        local current_remote
        current_remote="$(git -C "$NVIM_CONFIG_DIR" remote get-url origin 2>/dev/null || echo "")"
        if [[ "$current_remote" == *"nvim_config"* ]]; then
            info "Repositório nvim_config existente detectado. Atualizando via git pull..."
            git -C "$NVIM_CONFIG_DIR" fetch origin main 2>/dev/null || git -C "$NVIM_CONFIG_DIR" fetch origin 2>/dev/null || true
            if git -C "$NVIM_CONFIG_DIR" pull --rebase --autostash origin main 2>/dev/null; then
                success "Repositório em $NVIM_CONFIG_DIR atualizado com sucesso!"
            else
                warn "Não foi possível fazer pull (ou há commits locais à frente de origin/main); mantendo estado local."
            fi
        else
            local backup_dir="${NVIM_CONFIG_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
            warn "Outro repositório Git detectado em $NVIM_CONFIG_DIR ($current_remote)."
            info "Fazendo backup para: $backup_dir"
            mv "$NVIM_CONFIG_DIR" "$backup_dir"
            git clone "$REPO_URL" "$NVIM_CONFIG_DIR"
            success "Repositório clonado em $NVIM_CONFIG_DIR (backup salvo em $backup_dir)!"
        fi
    elif [ -d "$NVIM_CONFIG_DIR" ] && [ -n "$(ls -A "$NVIM_CONFIG_DIR" 2>/dev/null)" ]; then
        local backup_dir="${NVIM_CONFIG_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        warn "Diretório existente encontrado em $NVIM_CONFIG_DIR."
        info "Fazendo backup seguro para: $backup_dir"
        mv "$NVIM_CONFIG_DIR" "$backup_dir"
        git clone "$REPO_URL" "$NVIM_CONFIG_DIR"
        success "Repositório clonado em $NVIM_CONFIG_DIR (backup salvo em $backup_dir)!"
    else
        rm -rf "$NVIM_CONFIG_DIR" 2>/dev/null || true
        info "Clonando $REPO_URL em $NVIM_CONFIG_DIR..."
        git clone "$REPO_URL" "$NVIM_CONFIG_DIR"
        success "Repositório clonado com sucesso em $NVIM_CONFIG_DIR!"
    fi

    # On Windows (Git Bash / MSYS2 / Cygwin), native Neovim uses $LOCALAPPDATA/nvim
    # Link or sync $LOCALAPPDATA/nvim <-> ~/.config/nvim so both work seamlessly
    if [ "$OS_FAMILY" = "windows" ] && [ -n "${LOCALAPPDATA:-}" ]; then
        local win_nvim_dir
        win_nvim_dir="$(cygpath -u "$LOCALAPPDATA" 2>/dev/null || echo "$LOCALAPPDATA")/nvim"
        if [ "$win_nvim_dir" != "$NVIM_CONFIG_DIR" ] && [ ! -e "$win_nvim_dir" ]; then
            info "Criando link para compatibilidade nativa do Windows em $win_nvim_dir..."
            ln -s "$NVIM_CONFIG_DIR" "$win_nvim_dir" 2>/dev/null || cp -r "$NVIM_CONFIG_DIR" "$win_nvim_dir" 2>/dev/null || true
        fi
    fi
}

# ==============================================================================
# Install Script into ~/.local/bin on UNIX Systems & Configure PATH
# ==============================================================================
install_self_to_local_bin() {
    step "Instalando Script Gerenciador em $INSTALLER_BIN_PATH"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Copiaria install.sh para $INSTALLER_BIN_PATH e adicionaria $LOCAL_BIN_DIR ao PATH"
        return 0
    fi

    mkdir -p "$LOCAL_BIN_DIR"

    if [ -f "$NVIM_CONFIG_DIR/install.sh" ]; then
        cp -f "$NVIM_CONFIG_DIR/install.sh" "$INSTALLER_BIN_PATH"
        chmod +x "$INSTALLER_BIN_PATH"
        chmod +x "$NVIM_CONFIG_DIR/install.sh"
        success "Script instalado em: $INSTALLER_BIN_PATH"
    elif [ -f "${BASH_SOURCE[0]:-}" ]; then
        cp -f "${BASH_SOURCE[0]}" "$INSTALLER_BIN_PATH"
        chmod +x "$INSTALLER_BIN_PATH"
        success "Script instalado em: $INSTALLER_BIN_PATH"
    else
        curl -fsSL "$RAW_SCRIPT_URL" -o "$INSTALLER_BIN_PATH" && chmod +x "$INSTALLER_BIN_PATH"
        success "Script baixado e instalado em: $INSTALLER_BIN_PATH"
    fi

    # Ensure ~/.local/bin is in user's shell configuration files on UNIX
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local rc_files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    for rc in "${rc_files[@]}"; do
        if [ -f "$rc" ]; then
            if ! grep -Fq ".local/bin" "$rc" 2>/dev/null; then
                printf "\n# Added by nvim-installer\n%s\n" "$path_line" >> "$rc"
                info "Adicionado ~/.local/bin ao PATH em $rc"
            fi
        fi
    done

    # Fish shell support if installed
    local fish_config="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
    if [ -f "$fish_config" ] && ! grep -Fq ".local/bin" "$fish_config" 2>/dev/null; then
        printf "\n# Added by nvim-installer\nfish_add_path ~/.local/bin\n" >> "$fish_config"
        info "Adicionado ~/.local/bin ao PATH em $fish_config"
    fi
}

# ==============================================================================
# Bootstrap Neovim Plugins, Treesitter Parsers & Mason Headlessly
# ==============================================================================
bootstrap_neovim_headless() {
    step "Sincronizando Plugins (lazy.nvim) & Gramáticas (Treesitter)"

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] Executaria: nvim --headless \"+Lazy! sync\" +qa"
        return 0
    fi

    if ! command -v nvim >/dev/null 2>&1; then
        warn "Comando 'nvim' não encontrado no PATH atual. Pulando sincronização headless."
        return 0
    fi

    info "Sincronizando plugins via lazy.nvim (aguarde alguns segundos)..."
    nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || true

    info "Atualizando parsers do Treesitter..."
    nvim --headless "+TSUpdateSync" +qa >/dev/null 2>&1 || true

    success "Plugins e parsers do Neovim prontos para uso imediato!"
}

# ==============================================================================
# Main Execution Flow
# ==============================================================================
main() {
    parse_args "$@"
    detect_system

    printf "\n${BOLD}${CYAN}======================================================================${RESET}\n"
    printf "${BOLD}${CYAN}   Neovim Configuration - Universal Setup & Update Tool${RESET}\n"
    printf "${BOLD}${CYAN}======================================================================${RESET}\n"

    # 1. Check if already installed and ask mode (if interactive)
    prompt_existing_installation_mode

    # 2. Ask all 1-by-1 optional dependency questions BEFORE installing anything
    ask_optional_dependencies

    # 3. Print full execution plan
    print_plan_summary

    # 4. Install Essential + Selected Optional Dependencies (unless quick-update)
    if [ "$MODE" != "quick-update" ]; then
        install_essential_dependencies
        install_opt_lazygit
        install_opt_rust
        install_opt_gdb
        install_opt_latex
        install_opt_nerdfont
        install_opt_agy
        install_opt_claude
        install_opt_ollama
    fi

    # 5. Clone or Update ~/.config/nvim
    clone_or_update_repo

    # 6. Install script into ~/.local/bin/nvim-installer on UNIX systems
    install_self_to_local_bin

    # 7. Sync Neovim plugins & Treesitter parsers headlessly
    bootstrap_neovim_headless

    printf "\n${BOLD}${GREEN}======================================================================${RESET}\n"
    printf "${BOLD}${GREEN}   Tudo pronto! Instalação / Atualização concluída com sucesso!${RESET}\n"
    printf "${BOLD}${GREEN}======================================================================${RESET}\n\n"
    printf "  • Abra o Neovim digitando:        ${BOLD}nvim${RESET}\n"
    printf "  • Para atualizar no futuro:       ${BOLD}%s --update${RESET}\n" "$INSTALLER_BIN_NAME"
    printf "  • Para adicionar novos opcionais: ${BOLD}%s${RESET}\n\n" "$INSTALLER_BIN_NAME"
}

main "$@"
