$ErrorActionPreference = 'Stop'

Set-Location "$PSScriptRoot\..\diplomax_university"
Write-Host '[university] flutter pub get...'
flutter pub get
Write-Host '[university] flutter analyze...'
flutter analyze
Write-Host '[university] flutter test...'
flutter test
