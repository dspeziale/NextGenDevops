# Deploy (o rollback) di una versione su Coolify via API.
#   .\scripts\deploy.ps1 1.1.0      # aggiorna
#   .\scripts\deploy.ps1 1.0.1      # rollback
# Il token API (Coolify > Keys & Tokens > API tokens) viene chiesto se $env:COOLIFY_TOKEN non e' impostato.
# URL e UUID dell'applicazione hanno un default, sovrascrivibile con $env:COOLIFY_URL / $env:COOLIFY_APP_UUID.
# Coolify clona il repo al tag vX.Y.Z, builda l'immagine con APP_VERSION=X.Y.Z e la avvia.
param([Parameter(Mandatory = $true)][string]$Version)
$ErrorActionPreference = 'Stop'   # qui va bene: nessun comando nativo, solo Invoke-RestMethod

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Formato atteso X.Y.Z" }

$url = if ($env:COOLIFY_URL) { $env:COOLIFY_URL } else { 'http://10.20.23.64:8000' }
$uuid = if ($env:COOLIFY_APP_UUID) { $env:COOLIFY_APP_UUID } else { '0ldidmberbwan7h0d89lrviy' }
$token = $env:COOLIFY_TOKEN
if (-not $token -or $token -match '^<.*>$') {
    $secure = Read-Host 'Token API Coolify' -AsSecureString
    $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
$token = $token.Trim()

$api = "$($url.TrimEnd('/'))/api/v1"
$app = "$api/applications/$uuid"
$headers = @{ Authorization = "Bearer $token" }

try {
    Invoke-RestMethod -Uri $app -Headers $headers | Out-Null
} catch {
    $code = [int]$_.Exception.Response.StatusCode
    if ($code -eq 401) { throw "Token rifiutato da Coolify (401). Usa il token completo, incluso il prefisso 'N|'." }
    if ($code -eq 404) { throw "Applicazione $uuid non trovata su $url" }
    throw
}

Write-Host "Imposto sorgente = tag v$Version"
Invoke-RestMethod -Method Patch -Uri $app -Headers $headers -ContentType 'application/json' `
    -Body (@{ git_branch = "v$Version" } | ConvertTo-Json) | Out-Null

Write-Host "Imposto APP_VERSION=$Version"
Invoke-RestMethod -Method Patch -Uri "$app/envs" -Headers $headers -ContentType 'application/json' `
    -Body (@{ key = 'APP_VERSION'; value = $Version } | ConvertTo-Json) | Out-Null

Write-Host "Avvio deploy"
$res = Invoke-RestMethod -Method Post -Uri "$api/deploy?uuid=$uuid&force=false" -Headers $headers
$deployment = $res.deployments[0].deployment_uuid
Write-Host "Deployment $deployment avviato, attendo l'esito..."

do {
    Start-Sleep -Seconds 10
    $status = (Invoke-RestMethod -Uri "$api/deployments/$deployment" -Headers $headers).status
    Write-Host "  stato: $status"
} while ($status -in 'queued', 'in_progress')

if ($status -ne 'finished') { throw "Deploy v$Version terminato con stato '$status': controlla i log in Coolify" }
Write-Host "Versione $Version in esecuzione."
