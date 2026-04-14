$ErrorActionPreference = 'Stop'

Set-Location "$PSScriptRoot\..\diplomax_student"
Write-Host '[student] flutter pub get...'
flutter pub get
Write-Host '[student] flutter analyze...'
flutter analyze
Write-Host '[student] flutter test...'
flutter test
