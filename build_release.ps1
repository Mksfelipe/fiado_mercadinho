# build_release.ps1
# Gera o instalador localmente, para testar antes de publicar.
#
# Uso:
#   .\build_release.ps1                  # usa a ultima tag (ex: v1.4.1 -> 1.4.1)
#   .\build_release.ps1 -Version 1.5.0   # versao explicita
#
# Pre-requisitos: flutter e Inno Setup (ISCC).
#
# ATENCAO: este script NAO publica nada. Quem publica e o GitHub Actions,
# disparado ao empurrar uma tag:
#
#     git tag v1.5.0 && git push origin v1.5.0
#
# O workflow (.github/workflows/release.yml) compila, gera o instalador e cria
# o Release com o .exe anexado. O pubspec.yaml NAO e a fonte da versao: o CI o
# reescreve a partir da tag no momento do build, entao o valor commitado fica
# defasado de proposito e nao deve ser usado para nomear releases.

param(
    [string]$Version
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# --- 1. Versao: parametro explicito ou a ultima tag do git ---
if (-not $Version) {
    $tag = git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $tag) {
        throw "Nenhuma tag encontrada. Passe a versao: .\build_release.ps1 -Version 1.5.0"
    }
    $Version = $tag -replace '^v', ''
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Versao invalida: '$Version'. Esperado X.Y.Z (ex: 1.5.0)."
}
Write-Host "Versao: $Version" -ForegroundColor Cyan

# --- 2. Localiza o ISCC (compilador do Inno Setup) ---
$iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) {
    foreach ($p in @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe")) {
        if (Test-Path $p) { $iscc = $p; break }
    }
}
if (-not $iscc) { throw "ISCC.exe (Inno Setup) nao encontrado. Instale o Inno Setup 6." }

# --- 3. Build do Flutter para Windows ---
Write-Host "`n[1/2] Compilando o app (flutter build windows --release)..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build falhou." }

# --- 4. Gera o instalador (versao injetada, sem editar o .iss) ---
Write-Host "`n[2/2] Gerando o instalador (Inno Setup)..." -ForegroundColor Yellow
& $iscc "/DMyAppVersion=$Version" "installer\fiado_mercadinho.iss"
if ($LASTEXITCODE -ne 0) { throw "ISCC falhou." }

$setup = "installer\Output\FiadosMercadinho-Setup-$Version.exe"
if (-not (Test-Path $setup)) { throw "Instalador nao encontrado em $setup" }

Write-Host "`nInstalador gerado: $setup" -ForegroundColor Green
Write-Host "Para publicar, empurre a tag: git tag v$Version; git push origin v$Version" -ForegroundColor DarkGray
