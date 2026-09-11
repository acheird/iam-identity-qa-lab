# read-state-test.ps1
# Connectivity/read check only, same spirit as get-token-test.ps1: find
# Alex by EmployeeID and print his CURRENT groups and realm roles from
# Keycloak. No diff logic, no changes — this only verifies that
# Get-KeycloakUserGroups and Get-KeycloakUserRealmRoles work correctly
# before Remove-DepartmentMembership / update-users.ps1 are built on
# top of them.

. "$PSScriptRoot\KeycloakAuth.ps1"
. "$PSScriptRoot\KeycloakUsers.ps1"
. "$PSScriptRoot\KeycloakMembership.ps1"

$tokenResponse = Get-KeycloakToken
$accessToken = $tokenResponse.access_token

$alex = Get-KeycloakUserByEmployeeId -EmployeeId "E005" -AccessToken $accessToken

if (-not $alex) {
    Write-Host "Alex (E005) not found in Keycloak - run provision-users.ps1 first." -ForegroundColor Red
    exit
}

Write-Host "Alex found (id: $($alex.id))" -ForegroundColor Cyan

$groups = Get-KeycloakUserGroups -UserId $alex.id -AccessToken $accessToken
Write-Host "Current groups:"
foreach ($group in $groups) {
    Write-Host "  - $($group.name)"
}

$roles = Get-KeycloakUserRealmRoles -UserId $alex.id -AccessToken $accessToken
Write-Host "Current realm roles:"
foreach ($role in $roles) {
    Write-Host "  - $($role.name)"
}
