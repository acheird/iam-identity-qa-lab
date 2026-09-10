# provision-users.ps1
# Joiner script (REQ-007). Building this incrementally: this first
# version only reads and displays employees.csv, to confirm the data
# is parsed correctly before any Keycloak calls are added.

$csvPath = "$PSScriptRoot\..\data\employees.csv"

$employees = Import-Csv -Path $csvPath

Write-Host "Loaded $($employees.Count) employee record(s) from $csvPath" -ForegroundColor Cyan

foreach ($employee in $employees) {
    Write-Host "  $($employee.EmployeeID): $($employee.FirstName) $($employee.LastName) - $($employee.Department)/$($employee.Role) - $($employee.Status)"
}
