# update-users.ps1
# Mover script. Handles both department changes (REQ-008) and role
# changes (REQ-009), evaluated independently per employee (ADR-0001) —
# either, both, or neither can apply in the same run.
# Unlike the Joiner, this script only acts on employees who ALREADY
# exist in Keycloak — an employee not found here is skipped (creating
# new identities is provision-users.ps1's job, not this one's).

. "$PSScriptRoot\KeycloakAuth.ps1"
. "$PSScriptRoot\KeycloakUsers.ps1"
. "$PSScriptRoot\KeycloakMembership.ps1"

$csvPath = "$PSScriptRoot\..\data\employees.csv"
$employees = Import-Csv -Path $csvPath

Write-Host "Loaded $($employees.Count) employee record(s) from $csvPath" -ForegroundColor Cyan

$tokenResponse = Get-KeycloakToken
$accessToken = $tokenResponse.access_token

foreach ($employee in $employees) {
    $existingUser = Get-KeycloakUserByEmployeeId -EmployeeId $employee.EmployeeID -AccessToken $accessToken

    if (-not $existingUser) {
        Write-Host "  $($employee.EmployeeID): not found in Keycloak - skipping (Joiner's job, not Mover's)" -ForegroundColor Yellow
        continue
    }

    $desiredGroupName = "department-$($employee.Department.ToLower())"
    $currentGroups = Get-KeycloakUserGroups -UserId $existingUser.id -AccessToken $accessToken
    $currentGroupNames = $currentGroups | ForEach-Object { $_.name }

    if ($currentGroupNames -contains $desiredGroupName) {
        Write-Host "  $($employee.EmployeeID): department already correct ($desiredGroupName)" -ForegroundColor Green
    }
    else {
        Write-Host "  $($employee.EmployeeID): department change detected - current: [$($currentGroupNames -join ', ')], desired: $desiredGroupName" -ForegroundColor Cyan

        # Every group in our model IS a department group (REQ-003: a
        # user belongs to exactly one at a time) - so it's safe to
        # remove ALL current groups before adding the new one, without
        # needing to filter by name first.
        foreach ($group in $currentGroups) {
            Remove-DepartmentMembership -UserId $existingUser.id -GroupId $group.id -AccessToken $accessToken
        }

        Set-DepartmentMembership -UserId $existingUser.id -Department $employee.Department -AccessToken $accessToken
        Write-Host "  $($employee.EmployeeID): moved to $desiredGroupName" -ForegroundColor Cyan
    }

    # Role change (REQ-009) — evaluated independently of department
    # (ADR-0001): a role change can happen with or without a
    # department change in the same run.
    $currentRoles = Get-KeycloakUserRealmRoles -UserId $existingUser.id -AccessToken $accessToken
    $currentRoleNames = $currentRoles | ForEach-Object { $_.name }
    $hasManager = $currentRoleNames -contains "manager"
    $shouldBeManager = ($employee.Role -eq "Manager")

    if ($shouldBeManager -and -not $hasManager) {
        Write-Host "  $($employee.EmployeeID): role change detected - Employee -> Manager" -ForegroundColor Cyan
        # Reuses Set-RoleMembership, which always includes "employee"
        # too — re-adding a role the user already has is a harmless,
        # idempotent no-op in Keycloak.
        Set-RoleMembership -UserId $existingUser.id -Role $employee.Role -AccessToken $accessToken | Out-Null
        Write-Host "  $($employee.EmployeeID): manager role added" -ForegroundColor Cyan
    }
    elseif (-not $shouldBeManager -and $hasManager) {
        Write-Host "  $($employee.EmployeeID): role change detected - Manager -> Employee" -ForegroundColor Cyan
        # Only "manager" is passed for removal — "employee" is never
        # in this set, so it is never touched (ADR-0003).
        Remove-RoleMembership -UserId $existingUser.id -RoleNames @("manager") -AccessToken $accessToken | Out-Null
        Write-Host "  $($employee.EmployeeID): manager role removed, employee retained" -ForegroundColor Cyan
    }
    else {
        $roleLabel = if ($shouldBeManager) { "employee + manager" } else { "employee" }
        Write-Host "  $($employee.EmployeeID): role already correct ($roleLabel)" -ForegroundColor Green
    }
}
