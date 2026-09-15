# KeycloakUsers.ps1
# Shared user-management operations against the Keycloak Admin REST
# API. Every provisioning script (Joiner/Mover/Leaver) dot-sources
# this alongside KeycloakAuth.ps1.

function Disable-KeycloakUser {
    # REQ-010. PUT with a partial body — Keycloak merges this into the
    # existing user representation, only "enabled" changes.
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/users/$UserId"
    $headers = @{
        Authorization  = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }
    $body = @{ enabled = $false } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $body | Out-Null
    }
    catch {
        throw "Failed to disable user '$UserId': $($_.Exception.Message)"
    }
}

function Revoke-KeycloakUserSessions {
    # REQ-012. Empirically confirmed mechanism — see architecture.md
    # Section 10. No body needed; the user ID in the URL is enough.
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/users/$UserId/logout"
    $headers = @{ Authorization = "Bearer $AccessToken" }

    try {
        Invoke-RestMethod -Uri $uri -Method Post -Headers $headers | Out-Null
    }
    catch {
        throw "Failed to revoke sessions for user '$UserId': $($_.Exception.Message)"
    }
}

function New-KeycloakUser {
    # Creates a new user in Keycloak. Keycloak's create endpoint
    # responds 201 Created with an EMPTY body — the new user's ID is
    # taken from the "Location" response header instead, hence
    # Invoke-WebRequest (which exposes headers) rather than
    # Invoke-RestMethod (which only exposes the parsed body).
    param(
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [string]$LastName,

        [Parameter(Mandatory)]
        [string]$Email,

        [Parameter(Mandatory)]
        [string]$EmployeeId,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/users"

    $headers = @{
        Authorization  = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    # Keycloak's user representation stores every attribute value as
    # an ARRAY of strings, even single values (employeeId = @($EmployeeId),
    # not employeeId = $EmployeeId) — this is a Keycloak API convention,
    # not a project choice.
    $userPayload = @{
        username   = $Username
        enabled    = $true
        firstName  = $FirstName
        lastName   = $LastName
        email      = $Email
        attributes = @{
            employeeId = @($EmployeeId)
        }
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $userPayload
        $location = $response.Headers['Location']
        if ($location -is [array]) { $location = $location[0] }
        $newUserId = ($location -split '/')[-1]
        return $newUserId
    }
    catch {
        throw "Failed to create user '$Username': $($_.Exception.Message)"
    }
}

function Get-KeycloakUserByEmployeeId {
    # Authoritative existence check for REQ-002. Identity uniqueness
    # is anchored to the employeeId custom attribute, not to username
    # or name — two employees could share a first name. This is what
    # create-vs-skip decisions must use.
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
