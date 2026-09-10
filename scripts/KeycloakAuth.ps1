# KeycloakAuth.ps1
# Shared connection logic for all provisioning scripts. Every script
# that needs to talk to the Keycloak Admin API (Joiner, Mover, Leaver,
# and diagnostic tools) dot-sources this file and calls
# Get-KeycloakToken instead of duplicating the authentication logic.

function Import-DotEnv {
    param([string]$Path = ".env")
    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
        }
    }
}

function Get-KeycloakToken {
    # Returns the full token response object (access_token, expires_in,
    # token_type, ...) so callers can use whichever fields they need,
    # not just the token string itself.
    Import-DotEnv

    $tokenUrl = "$($env:KEYCLOAK_BASE_URL)/realms/$($env:KEYCLOAK_REALM)/protocol/openid-connect/token"

    $body = @{
        grant_type    = "client_credentials"
        client_id     = $env:KEYCLOAK_CLIENT_ID
        client_secret = $env:KEYCLOAK_CLIENT_SECRET
    }

    try {
        return Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    }
    catch {
        throw "Failed to acquire Keycloak token: $($_.Exception.Message)"
    }
}
