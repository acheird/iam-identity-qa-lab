# get-token-test.ps1
# Connectivity check only: confirms the acme-provisioner service
# account can authenticate against Keycloak. Contains no provisioning
# logic itself - reuses the shared Get-KeycloakToken function from
# KeycloakAuth.ps1, the same function every Joiner/Mover/Leaver script
# will use. Safe to re-run any time you want to verify the connection
# layer independently of the rest of the project.

. "$PSScriptRoot\KeycloakAuth.ps1"

try {
    $response = Get-KeycloakToken
    Write-Host "Token acquired successfully." -ForegroundColor Green
    Write-Host "Token type: $($response.token_type)"
    Write-Host "Expires in: $($response.expires_in) seconds"
}
catch {
    Write-Host "Failed to acquire token." -ForegroundColor Red
    Write-Host $_.Exception.Message
}
