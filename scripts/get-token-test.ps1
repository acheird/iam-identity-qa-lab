# get-token-test.ps1
# Minimal script to confirm the acme-provisioner service account can
# authenticate against Keycloak. No provisioning logic yet — this is
# the connection layer only, verified on its own before anything else
# is built on top of it.

# Load .env into environment variables for this session
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}

$tokenUrl = "$($env:KEYCLOAK_BASE_URL)/realms/$($env:KEYCLOAK_REALM)/protocol/openid-connect/token"

$body = @{
    grant_type    = "client_credentials"
    client_id     = $env:KEYCLOAK_CLIENT_ID
    client_secret = $env:KEYCLOAK_CLIENT_SECRET
}

try {
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    Write-Host "Token acquired successfully." -ForegroundColor Green
    Write-Host "Token type: $($response.token_type)"
    Write-Host "Expires in: $($response.expires_in) seconds"
}
catch {
    Write-Host "Failed to acquire token." -ForegroundColor Red
    Write-Host $_.Exception.Message
}
