# provision-users.ps1
# Joiner script (REQ-007).
# This version: find existing employees by EmployeeID, create any
# that don't exist yet, and assign their department group and realm
# roles. Mover/reconciliation logic (ensuring an already-existing
# identity still matches the CSV) is not implemented here — that is
# update-users.ps1's job.

. "$PSScriptRoot\KeycloakAuth.ps1"
. "$PSScriptRoot\KeycloakUsers.ps1"
. "$PSScriptRoot\KeycloakMembership.ps1"

$csvPath = "$PSScriptRoot\..\data\employees.csv"
$employees = Import-Csv -Path $csvPath

Write-Host "Loaded $($employees.Count) employee record(s) from $csvPath" -ForegroundColor Cyan

$tokenResponse = Get-KeycloakToken
$accessToken = $tokenResponse.access_token

foreach ($employee in $employees) {
    # Username is a human-readable login identifier only. It is NOT
    # the uniqueness anchor - EmployeeID is (REQ-002). See
    # Get-KeycloakUserByEmployeeId in KeycloakUsers.ps1.
    $username = $employee.FirstName.ToLower()

    $existingUser = Get-KeycloakUserByEmployeeId -EmployeeId $employee.EmployeeID -AccessToken $accessToken

    if ($existingUser) {
        Write-Host "  $($employee.EmployeeID) ($username): FOUND in Keycloak (id: $($existingUser.id))" -ForegroundColor Yellow
    }
    else {
        Write-Host "  $($employee.EmployeeID) ($username): NOT FOUND - creating..." -ForegroundColor Green

        $newUserId = New-KeycloakUser `
            -Username $username `
            -FirstName $employee.FirstName `
            -LastName $employee.LastName `
            -Email $employee.Email `
            -EmployeeId $employee.EmployeeID `
            -AccessToken $accessToken

        Write-Host "  $($employee.EmployeeID) ($username): CREATED (id: $newUserId)" -ForegroundColor Cyan

        Set-DepartmentMembership -UserId $newUserId -Department $employee.Department -AccessToken $accessToken
        Write-Host "  $($employee.EmployeeID) ($username): added to department-$($employee.Department.ToLower())" -ForegroundColor Cyan

        $assignedRoles = Set-RoleMembership -UserId $newUserId -Role $employee.Role -AccessToken $accessToken
        Write-Host "  $($employee.EmployeeID) ($username): role(s) assigned ($($assignedRoles -join ', '))" -ForegroundColor Cyan
    }
}
