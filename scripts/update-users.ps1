# update-users.ps1
# Mover script. This version: department changes only (REQ-008).
# Role change logic (REQ-009) not yet implemented - next step.
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
}
