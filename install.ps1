<#
.SYNOPSIS
    Neovim Configuration - Universal Windows PowerShell Installer & Updater
    Repository: https://github.com/Johannesgauss/nvim_config

.DESCRIPTION
    - Installs Essential Dependencies via winget / scoop / choco
    - Asks 1-by-1 for Optional Dependencies before starting installation
    - Clones or updates https://github.com/Johannesgauss/nvim_config in ~/.config/nvim
      and links $env:LOCALAPPDATA\nvim so native Windows Neovim works out-of-the-box
    - Installs the `nvim-installer` command into ~/.local/bin
    - Bootstraps lazy.nvim plugins & Treesitter parsers headlessly
#>

param(
    [switch]$Update,
    [switch]$All,
    [switch]$Minimal,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Continue"
$RepoUrl = "https://github.com/Johannesgauss/nvim_config.git"
$ConfigDir = Join-Path $HOME ".config\nvim"
$LocalAppDataNvim = Join-Path $env:LOCALAPPDATA "nvim"
$LocalBinDir = Join-Path $HOME ".local\bin"
$InstallerDest = Join-Path $LocalBinDir "nvim-installer.ps1"

function Show-Help {
    Write-Host "Neovim Config - Windows PowerShell Installer & Updater" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Uso / Usage:"
    Write-Host "  .\install.ps1                # Modo interativo (pergunta opcionais 1 por 1)"
    Write-Host "  .\install.ps1 -Update        # Atualiza repositório, plugins e ferramentas"
    Write-Host "  .\install.ps1 -All           # Instala essenciais + TODOS os opcionais sem perguntar"
    Write-Host "  .\install.ps1 -Minimal       # Instala apenas dependências essenciais"
    exit 0
}

if ($Help) { Show-Help }

function Ask-YesNo([string]$Question, [bool]$DefaultYes = $false) {
    if ($All) { return $true }
    if ($Minimal) { return $false }
    $hint = if ($DefaultYes) { "[S/n]" } else { "[s/N]" }
    while ($true) {
        $ans = Read-Host "? $Question $hint"
        $ans = $ans.Trim().ToLower()
        if ([string]::IsNullOrEmpty($ans)) { return $DefaultYes }
        if ($ans -in @("s", "sim", "y", "yes", "1")) { return $true }
        if ($ans -in @("n", "nao", "não", "no", "0")) { return $false }
        Write-Host "  Por favor, responda 's' (sim) ou 'n' (não)." -ForegroundColor Yellow
    }
}

# Detect Windows Package Manager
$PkgMgr = "winget"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $PkgMgr = "winget"
} elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    $PkgMgr = "scoop"
} elseif (Get-Command choco -ErrorAction SilentlyContinue) {
    $PkgMgr = "choco"
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   Neovim Configuration - Windows Setup & Update Tool ($PkgMgr)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$OptLazygit  = $false
$OptRust     = $false
$OptGdb      = $false
$OptLatex    = $false
$OptNerdFont = $false
$OptAgy      = $false
$OptClaude   = $false
$OptOllama   = $false

if (-not $Update -or (Ask-YesNo "Deseja revisar/instalar pacotes opcionais adicionais 1 por 1?" $false)) {
    if (-not $Minimal) {
        Write-Host "`n==> Seleção de Dependências Opcionais (1 por 1)" -ForegroundColor Magenta
        Write-Host "A instalação começará somente após todas as perguntas.`n"

        $OptLazygit  = Ask-YesNo "[1/8] Instalar Lazygit (Interface Git interativa via <leader>gg)?" $true
        $OptRust     = Ask-YesNo "[2/8] Instalar Rust, Cargo & rust-analyzer (Desenvolvimento Rust e LSP)?" $true
        $OptGdb      = Ask-YesNo "[3/8] Instalar GDB Debugger (Debug rápido no terminal via <leader>db)?" $true
        $OptLatex    = Ask-YesNo "[4/8] Instalar Suíte LaTeX (MiKTeX + SumatraPDF para VimTeX)?" $false
        $OptNerdFont = Ask-YesNo "[5/8] Instalar JetBrains Mono Nerd Font (Ícones para UI)?" $true
        $OptAgy      = Ask-YesNo "[6/8] Instalar Google Antigravity CLI ('agy' - Painel <leader>ai)?" $false
        $OptClaude   = Ask-YesNo "[7/8] Instalar Claude Code CLI ('claude' - Painel <leader>ci)?" $false
        $OptOllama   = Ask-YesNo "[8/8] Instalar Ollama ('ollama' - Modelos LLM locais para <C-y>)?" $false
    }
}

function Install-Pkg([string]$WingetId, [string]$ScoopName, [string]$ChocoName) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Instalaria $WingetId / $ScoopName" -ForegroundColor DarkGray
        return
    }
    if ($PkgMgr -eq "winget" -and $WingetId) {
        winget install --id $WingetId -e --accept-source-agreements --accept-package-agreements
    } elseif ($PkgMgr -eq "scoop" -and $ScoopName) {
        scoop install $ScoopName
    } elseif ($PkgMgr -eq "choco" -and $ChocoName) {
        choco install -y $ChocoName
    }
}

Write-Host "`n==> Instalando Dependências Essenciais..." -ForegroundColor Magenta
Install-Pkg "Neovim.Neovim" "neovim" "neovim"
Install-Pkg "Git.Git" "git" "git"
Install-Pkg "BrechtSanders.WinLibs.POSIX.UCRT" "gcc" "mingw"
Install-Pkg "BurntSushi.ripgrep.MSVC" "ripgrep" "ripgrep"
Install-Pkg "sharkdp.fd" "fd" "fd"
Install-Pkg "OpenJS.NodeJS.LTS" "nodejs-lts" "nodejs-lts"
Install-Pkg "Python.Python.3.12" "python" "python3"
Install-Pkg "Tree-sitter.Tree-sitter-CLI" "tree-sitter" "tree-sitter"

if ($OptLazygit) {
    Write-Host "`n==> Instalando Opcional [1/8]: Lazygit..." -ForegroundColor Magenta
    Install-Pkg "JesseDuffield.lazygit" "lazygit" "lazygit"
}
if ($OptRust) {
    Write-Host "`n==> Instalando Opcional [2/8]: Rust & Cargo..." -ForegroundColor Magenta
    Install-Pkg "Rustlang.Rustup" "rustup" "rust"
}
if ($OptGdb) {
    Write-Host "`n==> Instalando Opcional [3/8]: GDB..." -ForegroundColor Magenta
    Install-Pkg "BrechtSanders.WinLibs.POSIX.UCRT" "gdb" "mingw"
}
if ($OptLatex) {
    Write-Host "`n==> Instalando Opcional [4/8]: LaTeX & PDF Viewer..." -ForegroundColor Magenta
    Install-Pkg "MiKTeX.MiKTeX" "latex" "miktex"
    Install-Pkg "SumatraPDF.SumatraPDF" "sumatrapdf" "sumatrapdf"
}
if ($OptNerdFont) {
    Write-Host "`n==> Instalando Opcional [5/8]: JetBrains Mono Nerd Font..." -ForegroundColor Magenta
    Install-Pkg "DEVCOM.JetBrainsMonoNerdFont" "JetBrainsMono-NF" "jetbrainsmono-nf"
}
if ($OptAgy -and (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "`n==> Verificando Opcional [6/8]: Antigravity CLI..." -ForegroundColor Magenta
    if (-not $DryRun) { npm install -g @google/antigravity-cli 2>$null }
}
if ($OptClaude -and (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "`n==> Instalando Opcional [7/8]: Claude Code CLI..." -ForegroundColor Magenta
    if (-not $DryRun) { npm install -g @anthropic-ai/claude-code }
}
if ($OptOllama) {
    Write-Host "`n==> Instalando Opcional [8/8]: Ollama..." -ForegroundColor Magenta
    Install-Pkg "Ollama.Ollama" "ollama" "ollama"
}

Write-Host "`n==> Configurando Repositório em $ConfigDir..." -ForegroundColor Magenta
if (-not $DryRun) {
    $parentDir = Split-Path -Parent $ConfigDir
    if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }

    if (Test-Path (Join-Path $ConfigDir ".git")) {
        Write-Host "[INFO] Atualizando repositório existente em $ConfigDir..." -ForegroundColor Blue
        git -C $ConfigDir fetch origin main
        git -C $ConfigDir pull --rebase --autostash origin main
    } else {
        if (Test-Path $ConfigDir) {
            $backup = "$ConfigDir.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Move-Item -Path $ConfigDir -Destination $backup -Force
            Write-Host "[INFO] Backup salvo em $backup" -ForegroundColor Yellow
        }
        git clone $RepoUrl $ConfigDir
    }

    # Link $env:LOCALAPPDATA\nvim -> ~/.config/nvim so native Windows Neovim uses ~/.config/nvim
    if (-not (Test-Path $LocalAppDataNvim)) {
        New-Item -ItemType Junction -Path $LocalAppDataNvim -Target $ConfigDir -ErrorAction SilentlyContinue | Out-Null
    }

    # Install script into ~/.local/bin
    if (-not (Test-Path $LocalBinDir)) { New-Item -ItemType Directory -Path $LocalBinDir -Force | Out-Null }
    $srcPs1 = Join-Path $ConfigDir "install.ps1"
    if (Test-Path $srcPs1) { Copy-Item -Path $srcPs1 -Destination $InstallerDest -Force }

    if (Get-Command nvim -ErrorAction SilentlyContinue) {
        Write-Host "`n==> Sincronizando Plugins (lazy.nvim) & Parsers (Treesitter)..." -ForegroundColor Magenta
        nvim --headless "+Lazy! sync" +qa 2>$null
        nvim --headless "+TSUpdateSync" +qa 2>$null
    }
}

Write-Host "`n======================================================================" -ForegroundColor Green
Write-Host "   Instalação / Atualização concluída com sucesso!" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
