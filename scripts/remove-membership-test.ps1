# remove-membership-test.ps1
# Standalone verification of Remove-DepartmentMembership, same spirit
# as get-token-test.ps1 and read-state-test.ps1: test one function in
# isolation before building diff/orchestration logic on top of it.
# Removes Alex from whatever department group he currently has, then
# reads his groups again to confirm it's gone.

. "$PSScriptRoot\KeycloakAuth.ps1"
. "$PSScriptRoot\KeycloakUsers.ps1"
. "$PSScriptRoot\KeycloakMembership.ps1"

$tokenResponse = Get-KeycloakToken
$accessToken = $tokenResponse.access_token

$alex = Get-KeycloakUserByEmployeeId -EmployeeId "E005" -AccessToken $accessToken

if (-not $alex) {
    Write-Host "Alex (E005) not found - run provision-users.ps1 first." -ForegroundColor Red
    exit
}

$currentGroups = Get-KeycloakUserGroups -UserId $alex.id -AccessToken $accessToken

if ($currentGroups.Count -eq 0) {
    Write-Host "Alex has no groups to remove." -ForegroundColor Yellow
    exit
}

$groupToRemove = $currentGroups[0]
Write-Host "Removing Alex from: $($groupToRemove.name)" -ForegroundColor Cyan

Remove-DepartmentMembership -UserId $alex.id -GroupId $groupToRemove.id -AccessToken $accessToken

$groupsAfter = Get-KeycloakUserGroups -UserId $alex.id -AccessToken $accessToken
Write-Host "Groups after removal:"
if ($groupsAfter.Count -eq 0) {
    Write-Host "  (none)" -ForegroundColor Green
}
else {
    foreach ($group in $groupsAfter) {
        Write-Host "  - $($group.name)"
    }
}
