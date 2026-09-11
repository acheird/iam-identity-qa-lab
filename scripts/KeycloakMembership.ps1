# KeycloakMembership.ps1
# Group and role membership operations against the Keycloak Admin
# REST API. Kept in its own file, separate from KeycloakUsers.ps1
# (identity CRUD), so that department changes and role changes stay
# independently callable — see ADR-0001 (orthogonal Group/Role model).

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
