# Deploy (o rollback) di una versione su Coolify via API.
#   $env:COOLIFY_URL      = "http://10.20.23.64:8000"
#   $env:COOLIFY_TOKEN    = "..."   # Coolify > Keys & Tokens > API tokens
#   $env:COOLIFY_APP_UUID = "..."   # UUID della risorsa NextGenDevops in Coolify
#   .\scripts\deploy.ps1 1.1.0      # aggiorna
#   .\scripts\deploy.ps1 1.0.1      # rollback
# Coolify clona il repo al tag vX.Y.Z, builda l'immagine con APP_VERSION=X.Y.Z e la avvia.
param([Parameter(Mandatory = $true)][string]$Version)
$ErrorActionPreference = 'Stop'   # qui va bene: nessun comando nativo, solo Invoke-RestMethod

foreach ($name in 'COOLIFY_URL', 'COOLIFY_TOKEN', 'COOLIFY_APP_UUID') {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "Imposta `$env:$name" }
}

$api = "$($env:COOLIFY_URL.TrimEnd('/'))/api/v1"
$app = "$api/applications/$env:COOLIFY_APP_UUID"
$headers = @{ Authorization = "Bearer $env:COOLIFY_TOKEN" }

Write-Host "Imposto sorgente = tag v$Version"
Invoke-RestMethod -Method Patch -Uri $app -Headers $headers -ContentType 'application/json' `
    -Body (@{ git_branch = "v$Version" } | ConvertTo-Json) | Out-Null

Write-Host "Imposto APP_VERSION=$Version"
Invoke-RestMethod -Method Patch -Uri "$app/envs" -Headers $headers -ContentType 'application/json' `
    -Body (@{ key = 'APP_VERSION'; value = $Version } | ConvertTo-Json) | Out-Null

Write-Host "Avvio deploy"
$res = Invoke-RestMethod -Uri "$api/deploy?uuid=$env:COOLIFY_APP_UUID&force=false" -Headers $headers
$deployment = $res.deployments[0].deployment_uuid
Write-Host "Deployment $deployment avviato, attendo l'esito..."

do {
    Start-Sleep -Seconds 10
    $status = (Invoke-RestMethod -Uri "$api/deployments/$deployment" -Headers $headers).status
    Write-Host "  stato: $status"
} while ($status -in 'queued', 'in_progress')

if ($status -ne 'finished') { throw "Deploy v$Version terminato con stato '$status': controlla i log in Coolify" }
Write-Host "Versione $Version in esecuzione."
