# provision-users.ps1
# Joiner script (REQ-007). Building this incrementally.
# This version: read employees.csv, authenticate as acme-provisioner,
# and check whether each employee already exists in Keycloak -
# authoritatively, by EmployeeID (REQ-002), not by name/username.
# Still no create/update logic yet.

. "$PSScriptRoot\KeycloakAuth.ps1"
. "$PSScriptRoot\KeycloakUsers.ps1"

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
        Write-Host "  $($employee.EmployeeID) ($username): NOT FOUND in Keycloak" -ForegroundColor Green
    }
}
