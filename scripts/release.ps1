# Crea una nuova versione: .\scripts\release.ps1 1.1.0
# Aggiorna VERSION, crea il tag vX.Y.Z e lo pusha -> GitHub Actions builda l'immagine.
param([Parameter(Mandatory = $true)][string]$Version)

# Niente $ErrorActionPreference='Stop': in Windows PowerShell 5.1 trasformerebbe in errore
# anche i normali messaggi che git scrive su stderr (es. l'avanzamento di "git push").
# Gli errori di git si controllano con $LASTEXITCODE.
function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "Comando fallito: git $args" }
}

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Formato atteso X.Y.Z (versione attuale: $(Get-Content VERSION))"
}
if (git tag --list "v$Version") { throw "Il tag v$Version esiste gia'" }
if (git status --porcelain) { throw "Ci sono modifiche non committate: committale prima del rilascio" }
if (-not (git remote)) { throw "Nessun remote configurato: esegui prima 'git remote add origin https://github.com/<owner>/NextGenDevops.git'" }

[IO.File]::WriteAllText("$PWD\VERSION", "$Version`n")
Invoke-Git add VERSION
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { Invoke-Git commit -m "release: v$Version" }
Invoke-Git tag -a "v$Version" -m "Release v$Version"
Invoke-Git push origin HEAD
Invoke-Git push origin "v$Version"

Write-Host "Tag v$Version pushato. Segui la build su GitHub > Actions, poi deploya con:"
Write-Host "  .\scripts\deploy.ps1 $Version"
