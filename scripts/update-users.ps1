# update-users.ps1
# Mover script. Handles both department changes (REQ-008) and role
# changes (REQ-009), evaluated independently per employee (ADR-0001) —
# either, both, or neither can apply in the same run.
# Unlike the Joiner, this script only acts on employees who ALREADY
# exist in Keycloak — an employee not found here is skipped (creating
# new identities is provision-users.ps1's job, not this one's).
# It also only acts on Active employees — a Terminated employee is
# skipped entirely (BUG-002 fix), since reconciling their state here
# would undo deprovision-users.ps1's work; see architecture.md
# Section 8, "Status-scoped responsibility".

. "$PSScriptRoot\KeycloakAuth.ps1"
. "$PSScriptRoot\KeycloakUsers.ps1"
. "$PSScriptRoot\KeycloakMembership.ps1"

$csvPath = "$PSScriptRoot\..\data\employees.csv"
$employees = Import-Csv -Path $csvPath

Write-Host "Loaded $($employees.Count) employee record(s) from $csvPath" -ForegroundColor Cyan

$tokenResponse = Get-KeycloakToken
$accessToken = $tokenResponse.access_token

foreach ($employee in $employees) {
    # BUG-002: Mover only reconciles Active employees. Terminated
    # employees are handled exclusively by the Leaver.
    if ($employee.Status -eq "Terminated") {
        Write-Host "  $($employee.EmployeeID): skipped - employee is Terminated" -ForegroundColor Yellow
        continue
    }

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
    # BUG-003 fix: compare the FULL desired role set against the full
    # current set, not just whether "manager" matches — the old logic
    # never asserted that "employee" itself was present.
    $desiredRoles = if ($employee.Role -eq "Manager") { @("employee", "manager") } else { @("employee") }
    $currentRoles = Get-KeycloakUserRealmRoles -UserId $existingUser.id -AccessToken $accessToken
    $currentRoleNames = $currentRoles | ForEach-Object { $_.name }
    $currentBusinessRoles = $currentRoleNames | Where-Object { $_ -in @("employee", "manager") }

    $missingRoles = $desiredRoles | Where-Object { $_ -notin $currentBusinessRoles }
    $extraRoles = $currentBusinessRoles | Where-Object { $_ -notin $desiredRoles }

    if ($missingRoles.Count -eq 0 -and $extraRoles.Count -eq 0) {
        Write-Host "  $($employee.EmployeeID): role already correct ($($desiredRoles -join ', '))" -ForegroundColor Green
    }
    else {
        if ($missingRoles.Count -gt 0) {
            Write-Host "  $($employee.EmployeeID): role(s) missing - adding $($missingRoles -join ', ')" -ForegroundColor Cyan
            # Set-RoleMembership adds the full desired set for this
            # employee's Role value; re-adding an already-present
            # role is a harmless, idempotent no-op in Keycloak.
            Set-RoleMembership -UserId $existingUser.id -Role $employee.Role -AccessToken $accessToken | Out-Null
        }
        if ($extraRoles.Count -gt 0) {
            Write-Host "  $($employee.EmployeeID): role(s) not desired - removing $($extraRoles -join ', ')" -ForegroundColor Cyan
            Remove-RoleMembership -UserId $existingUser.id -RoleNames $extraRoles -AccessToken $accessToken | Out-Null
        }
        Write-Host "  $($employee.EmployeeID): role reconciled to ($($desiredRoles -join ', '))" -ForegroundColor Cyan
    }
}
