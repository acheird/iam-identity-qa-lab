# KeycloakUsers.ps1
# Shared user-management operations against the Keycloak Admin REST
# API. Every provisioning script (Joiner/Mover/Leaver) dot-sources
# this alongside KeycloakAuth.ps1.

function Get-KeycloakUser {
    # Looks up a user by exact username. Returns the user object if
    # found, or $null if no user with that username exists — used to
    # decide create-vs-update (REQ-002: no duplicate identities).
    param(
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/users?username=$Username&exact=true"

    $headers = @{ Authorization = "Bearer $AccessToken" }

    try {
        $result = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        if ($result.Count -gt 0) {
            return $result[0]
        }
        return $null
    }
    catch {
        throw "Failed to query Keycloak for user '$Username': $($_.Exception.Message)"
    }
}

function Get-KeycloakUserByEmployeeId {
    # Authoritative existence check for REQ-002. Identity uniqueness
    # is anchored to the employeeId custom attribute, not to username
    # or name — two employees could share a first name, so
    # Get-KeycloakUser (username-based) is not sufficient to guarantee
    # uniqueness. This is what create-vs-skip decisions must use.
    param(
        [Parameter(Mandatory)]
        [string]$EmployeeId,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/users?q=employeeId:$EmployeeId"

    $headers = @{ Authorization = "Bearer $AccessToken" }

    try {
        $result = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        if ($result.Count -gt 0) {
            return $result[0]
        }
        return $null
    }
    catch {
        throw "Failed to query Keycloak for EmployeeID '$EmployeeId': $($_.Exception.Message)"
    }
}
