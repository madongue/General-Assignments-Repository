$ErrorActionPreference = 'Stop'

Write-Host '=== Diplomax CM full validation ==='

& "$PSScriptRoot\test_backend.ps1"
& "$PSScriptRoot\test_student.ps1"
& "$PSScriptRoot\test_university.ps1"
& "$PSScriptRoot\test_recruiter.ps1"

Write-Host '=== All suites completed successfully ==='
