# Crea una nuova versione: .\scripts\release.ps1 1.1.0
# Aggiorna VERSION, crea il tag vX.Y.Z e lo pusha -> GitHub Actions builda l'immagine.
param([Parameter(Mandatory = $true)][string]$Version)
$ErrorActionPreference = 'Stop'

function Invoke-Git { git @args; if ($LASTEXITCODE -ne 0) { throw "git $args fallito" } }

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Formato atteso X.Y.Z (versione attuale: $(Get-Content VERSION))"
}
git rev-parse "v$Version" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { throw "Il tag v$Version esiste gia'" }
if (git status --porcelain) { throw "Ci sono modifiche non committate: committale prima del rilascio" }

[IO.File]::WriteAllText("$PWD\VERSION", "$Version`n")
Invoke-Git add VERSION
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { Invoke-Git commit -m "release: v$Version" }
Invoke-Git tag -a "v$Version" -m "Release v$Version"
Invoke-Git push origin HEAD
Invoke-Git push origin "v$Version"

Write-Host "Tag v$Version pushato. Segui la build su GitHub > Actions, poi deploya con:"
Write-Host "  .\scripts\deploy.ps1 $Version"
