# deprovision-users.ps1
# Leaver script. Finds employees with Status=Terminated in the CSV
# and, for each one already existing in Keycloak: disables the
# account (REQ-010), removes department/role access (REQ-011), and
# revokes active sessions (REQ-012 - mechanism empirically confirmed,
# see architecture.md Section 10).

. "$PSScriptRoot\KeycloakAuth.ps1"
. "$PSScriptRoot\KeycloakUsers.ps1"
. "$PSScriptRoot\KeycloakMembership.ps1"

$csvPath = "$PSScriptRoot\..\data\employees.csv"
$employees = Import-Csv -Path $csvPath

$terminated = $employees | Where-Object { $_.Status -eq "Terminated" }

Write-Host "Found $($terminated.Count) terminated employee record(s) in $csvPath" -ForegroundColor Cyan

$tokenResponse = Get-KeycloakToken
$accessToken = $tokenResponse.access_token

foreach ($employee in $terminated) {
    $existingUser = Get-KeycloakUserByEmployeeId -EmployeeId $employee.EmployeeID -AccessToken $accessToken

    if (-not $existingUser) {
        Write-Host "  $($employee.EmployeeID): not found in Keycloak - nothing to deprovision" -ForegroundColor Yellow
        continue
    }

    # REQ-010 — Account Deactivation
    Disable-KeycloakUser -UserId $existingUser.id -AccessToken $accessToken
    Write-Host "  $($employee.EmployeeID): account disabled" -ForegroundColor Cyan

    # REQ-011 — Access Revocation (groups)
    $currentGroups = Get-KeycloakUserGroups -UserId $existingUser.id -AccessToken $accessToken
    foreach ($group in $currentGroups) {
        Remove-DepartmentMembership -UserId $existingUser.id -GroupId $group.id -AccessToken $accessToken
    }
    $removedGroupNames = $currentGroups | ForEach-Object { $_.name }
    Write-Host "  $($employee.EmployeeID): groups removed ($($removedGroupNames -join ', '))" -ForegroundColor Cyan

    # REQ-011 — Access Revocation (business roles). Explicit inclusion
    # list, not a dynamic exclusion of Keycloak system roles: for the
    # current Acme IAM model, `employee` and `manager` are the only
    # business roles managed by the HR-driven lifecycle. This mirrors
    # REQ-006 — hr-admin/it-admin are never assigned automatically by
    # this automation, so they are not revoked automatically by it
    # either; an IAM Administrator manages both, manually, on
    # termination as well as on grant. Introducing a new business role
    # later means a deliberate decision — does it belong to the
    # HR-managed lifecycle? — not an automatic assumption that
    # "anything not a known Keycloak system role" should be stripped.
    $currentRoles = Get-KeycloakUserRealmRoles -UserId $existingUser.id -AccessToken $accessToken
    $currentRoleNames = $currentRoles | ForEach-Object { $_.name }
    $businessRolesToRemove = $currentRoleNames | Where-Object { $_ -in @("employee", "manager") }

    if ($businessRolesToRemove.Count -gt 0) {
        Remove-RoleMembership -UserId $existingUser.id -RoleNames $businessRolesToRemove -AccessToken $accessToken | Out-Null
        Write-Host "  $($employee.EmployeeID): roles removed ($($businessRolesToRemove -join ', '))" -ForegroundColor Cyan
    }
    else {
        Write-Host "  $($employee.EmployeeID): no business roles to remove" -ForegroundColor Cyan
    }

    # REQ-012 — Session Revocation
    Revoke-KeycloakUserSessions -UserId $existingUser.id -AccessToken $accessToken
    Write-Host "  $($employee.EmployeeID): sessions revoked" -ForegroundColor Cyan
}
