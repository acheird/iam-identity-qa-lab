# provision-users.ps1
# Joiner script (REQ-007). Building this incrementally.
# This version: read employees.csv, authenticate as acme-provisioner,
# and check whether each employee already exists in Keycloak.
# Still no create/update logic yet - find-only, to verify this piece
# works before building on top of it.

. "$PSScriptRoot\KeycloakAuth.ps1"
. "$PSScriptRoot\KeycloakUsers.ps1"

$csvPath = "$PSScriptRoot\..\data\employees.csv"
$employees = Import-Csv -Path $csvPath

Write-Host "Loaded $($employees.Count) employee record(s) from $csvPath" -ForegroundColor Cyan

$tokenResponse = Get-KeycloakToken
$accessToken = $tokenResponse.access_token

foreach ($employee in $employees) {
    # TODO (REQ-002): FirstName-based username is a temporary
    # convention for this find-only verification step. It does not
    # guarantee uniqueness (two "Maria" records would collide) and
    # is not the real identity-generation rule. Revisit when create
    # logic is added — uniqueness must be anchored to EmployeeID, not
    # name.
    $username = $employee.FirstName.ToLower()

    $existingUser = Get-KeycloakUser -Username $username -AccessToken $accessToken

    if ($existingUser) {
        Write-Host "  $($employee.EmployeeID) ($username): FOUND in Keycloak (id: $($existingUser.id))" -ForegroundColor Yellow
    }
    else {
        Write-Host "  $($employee.EmployeeID) ($username): NOT FOUND in Keycloak" -ForegroundColor Green
    }
}
