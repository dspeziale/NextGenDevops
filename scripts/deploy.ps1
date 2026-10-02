# Deploy (o rollback) di una versione su Coolify via API.
#   $env:COOLIFY_URL      = "http://10.20.23.64"
#   $env:COOLIFY_TOKEN    = "..."   # Coolify > Keys & Tokens > API tokens
#   $env:COOLIFY_APP_UUID = "..."   # UUID della risorsa NextGenDevops in Coolify
#   .\scripts\deploy.ps1 1.1.0      # aggiorna
#   .\scripts\deploy.ps1 1.0.0      # rollback
param([Parameter(Mandatory = $true)][string]$Version)
$ErrorActionPreference = 'Stop'   # qui va bene: nessun comando nativo, solo Invoke-RestMethod

foreach ($name in 'COOLIFY_URL', 'COOLIFY_TOKEN', 'COOLIFY_APP_UUID') {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "Imposta `$env:$name" }
}

$api = "$($env:COOLIFY_URL.TrimEnd('/'))/api/v1"
$headers = @{ Authorization = "Bearer $env:COOLIFY_TOKEN" }

Write-Host "Imposto APP_VERSION=$Version"
$body = @{ key = 'APP_VERSION'; value = $Version } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$api/applications/$env:COOLIFY_APP_UUID/envs" `
    -Headers $headers -ContentType 'application/json' -Body $body | Out-Null

Write-Host "Avvio deploy"
Invoke-RestMethod -Uri "$api/deploy?uuid=$env:COOLIFY_APP_UUID&force=false" -Headers $headers |
    ConvertTo-Json -Depth 5
