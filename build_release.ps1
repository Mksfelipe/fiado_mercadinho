# build_release.ps1
# Gera o instalador da versao atual e publica como Release no GitHub.
#
# Uso:
#   .\build_release.ps1                 # build + instalador + publica release
#   .\build_release.ps1 -Notes "texto"  # com notas de versao
#   .\build_release.ps1 -SkipRelease     # so build + instalador (nao publica)
#
# Pre-requisitos: flutter, Inno Setup (ISCC) e gh (GitHub CLI, ja autenticado).

param(
    [string]$Notes = "Correcoes e melhorias.",
    [switch]$SkipRelease
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# --- 1. Le a versao do pubspec.yaml (linha "version: 1.2.0+3" -> "1.2.0") ---
$versionLine = Select-String -Path "pubspec.yaml" -Pattern '^\s*version:\s*([0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1
if (-not $versionLine) { throw "Nao achei 'version:' no pubspec.yaml" }
$version = $versionLine.Matches[0].Groups[1].Value
Write-Host "Versao detectada: $version" -ForegroundColor Cyan

# --- 1b. Confere se o .iss esta na mesma versao (evita publicar versao errada) ---
$issVersion = (Select-String -Path "installer\fiado_mercadinho.iss" -Pattern 'MyAppVersion\s+"([0-9.]+)"' | Select-Object -First 1).Matches[0].Groups[1].Value
if ($issVersion -ne $version) {
    throw "Versao do pubspec ($version) difere do .iss ($issVersion). Ajuste #define MyAppVersion no installer\fiado_mercadinho.iss."
}

# --- 2. Localiza o ISCC (compilador do Inno Setup) ---
$iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) {
    foreach ($p in @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe")) {
        if (Test-Path $p) { $iscc = $p; break }
    }
}
if (-not $iscc) { throw "ISCC.exe (Inno Setup) nao encontrado. Instale o Inno Setup 6." }

# --- 3. Build do Flutter para Windows ---
Write-Host "`n[1/3] Compilando o app (flutter build windows --release)..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build falhou." }

# --- 4. Gera o instalador ---
Write-Host "`n[2/3] Gerando o instalador (Inno Setup)..." -ForegroundColor Yellow
& $iscc "installer\fiado_mercadinho.iss"
if ($LASTEXITCODE -ne 0) { throw "ISCC falhou." }

$setup = "installer\Output\FiadosMercadinho-Setup-$version.exe"
if (-not (Test-Path $setup)) { throw "Instalador nao encontrado em $setup" }
Write-Host "Instalador gerado: $setup" -ForegroundColor Green

if ($SkipRelease) {
    Write-Host "`n-SkipRelease ativo: release nao publicado." -ForegroundColor DarkYellow
    return
}

# --- 5. Publica o Release no GitHub (tag vX.Y.Z + instalador anexado) ---
Write-Host "`n[3/3] Publicando Release v$version no GitHub..." -ForegroundColor Yellow
$tag = "v$version"

# Se a tag/release ja existe, sobe so o arquivo; senao cria o release.
gh release view $tag *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Release $tag ja existe; atualizando o instalador..." -ForegroundColor DarkYellow
    gh release upload $tag $setup --clobber
} else {
    gh release create $tag $setup --title $tag --notes $Notes
}
if ($LASTEXITCODE -ne 0) { throw "Falha ao publicar o release (gh)." }

Write-Host "`nPronto! Release $tag publicado. O app no mercadinho vai oferecer a atualizacao na proxima abertura." -ForegroundColor Green
