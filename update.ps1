# ==============================================================================
# Antigravity Mobile Harness - Atualizador (Windows PowerShell)
# Atualiza um projeto onde o harness JA esta instalado, sem tocar no seu codigo.
#
# Uso: irm <url>/update.ps1 | iex   OU   .\update.ps1 [-Branch main]
#
# O que e ATUALIZADO (sobrescrito, com backup previo em .agents.bak-<data>):
#   .agents/  _specs/prd-template.md  _specs/tasks/_template.md
#   install.ps1  install.sh  update.ps1  update.sh
#
# O que e PRESERVADO (nunca tocado):
#   apps/  _specs/prd.md  _specs/features/  _specs/tasks/T*.md
#   _specs/task-board.md  _references/  README.md  .git/  .gitignore (se existir)
# ==============================================================================

param(
    [string]$Repo = "MailsonSilva/antigravity-harness",
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   Atualizador do Antigravity Mobile Harness         " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath ".agents\harness.yaml")) {
    Write-Host "ERRO: harness nao encontrado aqui. Rode o install.ps1 primeiro." -ForegroundColor Red
    exit 1
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$zipUrl = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"
$tmpZip = Join-Path ([IO.Path]::GetTempPath()) "harness-update-$stamp.zip"
$tmpDir = Join-Path ([IO.Path]::GetTempPath()) "harness-update-$stamp"

try {
    Write-Host "Baixando $zipUrl ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip
    Expand-Archive -LiteralPath $tmpZip -DestinationPath $tmpDir -Force
    $src = Join-Path $tmpDir ((Get-ChildItem -LiteralPath $tmpDir -Directory)[0].Name)

    # 1. Backup do .agents atual
    $bak = ".agents.bak-$stamp"
    Copy-Item -Recurse -Force -LiteralPath ".agents" -Destination $bak
    Write-Host "Backup criado em: $bak" -ForegroundColor DarkYellow

    # 2. Sobrescreve SOMENTE arquivos gerenciados pelo harness
    Copy-Item -Recurse -Force (Join-Path $src ".agents\*") ".agents"
    foreach ($f in @("_specs\prd-template.md", "_specs\tasks\_template.md",
                     "install.ps1", "install.sh", "update.ps1", "update.sh")) {
        $from = Join-Path $src $f
        if (Test-Path -LiteralPath $from) {
            $destDir = Split-Path -Parent $f
            if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Force -LiteralPath $from -Destination $f
        }
    }
    if (-not (Test-Path -LiteralPath ".gitignore")) {
        Copy-Item -Force (Join-Path $src ".gitignore") ".gitignore"
    }

    Write-Host "Harness atualizado a partir de $Repo@$Branch." -ForegroundColor Green
    Write-Host "Preservados: apps/, prd.md, features/, suas tarefas, board e references." -ForegroundColor Green
    Write-Host "Se algo falhar, restaure com: Remove-Item -Recurse .agents; Rename-Item $bak .agents" -ForegroundColor DarkYellow
}
finally {
    if (Test-Path -LiteralPath $tmpZip) { Remove-Item -Force -LiteralPath $tmpZip }
    if (Test-Path -LiteralPath $tmpDir) { Remove-Item -Recurse -Force -LiteralPath $tmpDir }
}
