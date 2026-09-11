# KeycloakMembership.ps1
# Group and role membership operations against the Keycloak Admin
# REST API. Kept in its own file, separate from KeycloakUsers.ps1
# (identity CRUD), so that department changes and role changes stay
# independently callable — see ADR-0001 (orthogonal Group/Role model).

function Get-KeycloakUserGroups {
    # Reads the user's CURRENT department group(s) from Keycloak —
    # the actual state, not what the CSV says it should be. This is
    # the "before" side of the Mover's diff logic (REQ-008).
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/users/$UserId/groups"
    $headers = @{ Authorization = "Bearer $AccessToken" }

    try {
        return Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    }
    catch {
        throw "Failed to read groups for user '$UserId': $($_.Exception.Message)"
    }
}

function Get-KeycloakUserRealmRoles {
    # Reads the user's CURRENT realm role assignments from Keycloak —
    # the "before" side of the Mover's diff logic (REQ-009).
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/users/$UserId/role-mappings/realm"
    $headers = @{ Authorization = "Bearer $AccessToken" }

    try {
        return Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    }
    catch {
        throw "Failed to read realm roles for user '$UserId': $($_.Exception.Message)"
    }
}

function Get-KeycloakGroupByName {
    param(
        [Parameter(Mandatory)]
        [string]$GroupName,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/groups?search=$GroupName&exact=true"
    $headers = @{ Authorization = "Bearer $AccessToken" }

    try {
        $result = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        if ($result.Count -gt 0) {
            return $result[0]
        }
        return $null
    }
    catch {
        throw "Failed to look up group '$GroupName': $($_.Exception.Message)"
    }
}

function Get-KeycloakRealmRole {
    # Fetches the full role representation object for a realm role by
    # name. Needed because Keycloak's role-mappings endpoint expects
    # complete role objects, not plain role-name strings.
    param(
        [Parameter(Mandatory)]
        [string]$RoleName,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/roles/$RoleName"
    $headers = @{ Authorization = "Bearer $AccessToken" }

    try {
        return Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    }
    catch {
        throw "Failed to look up role '$RoleName': $($_.Exception.Message)"
    }
}

function Set-RoleMembership {
    # Assigns realm roles to the user. Always includes 'employee'
    # (REQ-004, baseline). Adds 'manager' additionally, never as a
    # replacement, if the CSV Role field is "Manager" — explicit dual
    # assignment per ADR-0003, not a composite/implicit role.
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$Role,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $roleNames = @("employee")
    if ($Role -eq "Manager") {
        $roleNames += "manager"
    }

    $roleRepresentations = @()
    foreach ($roleName in $roleNames) {
        $roleRepresentations += Get-KeycloakRealmRole -RoleName $roleName -AccessToken $AccessToken
    }

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/users/$UserId/role-mappings/realm"
    $headers = @{
        Authorization  = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }
    # -AsArray forces JSON array syntax even when $roleRepresentations
    # has only one element (e.g. baseline "employee" only) - without
    # it, ConvertTo-Json would serialize a single-item collection as a
    # bare object, which Keycloak's endpoint would reject.
    $body = $roleRepresentations | ConvertTo-Json -Depth 5 -AsArray

    try {
        Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body | Out-Null
        # Return the role names that were actually sent, so callers
        # report what really happened instead of re-deriving the same
        # Manager/employee condition independently (which could drift
        # out of sync with this function, or silently be wrong if this
        # call had partially failed).
        return $roleNames
    }
    catch {
        throw "Failed to assign roles to user '$UserId': $($_.Exception.Message)"
    }
}

function Set-DepartmentMembership {
    # Adds the user to the department group matching their CSV
    # Department field (e.g. "IT" -> "department-it"). This does NOT
    # remove other department groups the user might already have —
    # that is Mover logic (REQ-008), out of scope for the Joiner.
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$Department,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $groupName = "department-$($Department.ToLower())"
    $group = Get-KeycloakGroupByName -GroupName $groupName -AccessToken $AccessToken

    if (-not $group) {
        throw "Department group '$groupName' does not exist in Keycloak."
    }

    $uri = "$($env:KEYCLOAK_BASE_URL)/admin/realms/$($env:KEYCLOAK_REALM)/users/$UserId/groups/$($group.id)"
    $headers = @{ Authorization = "Bearer $AccessToken" }

    try {
        # PUT with no body - this endpoint just needs the two IDs in
        # the URL (user, group). A successful call returns no content.
        Invoke-RestMethod -Uri $uri -Method Put -Headers $headers | Out-Null
    }
    catch {
        throw "Failed to add user '$UserId' to group '$groupName': $($_.Exception.Message)"
    }
}
