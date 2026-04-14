$ErrorActionPreference = 'Stop'

Set-Location "$PSScriptRoot\..\diplomax_recruiter"
Write-Host '[recruiter] flutter pub get...'
flutter pub get
Write-Host '[recruiter] flutter analyze...'
flutter analyze
Write-Host '[recruiter] flutter test...'
flutter test
