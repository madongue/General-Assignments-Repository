$ErrorActionPreference = 'Stop'

Write-Host '[backend] Installing Python dependencies...'
Set-Location "$PSScriptRoot\..\backend"
python -m pip install -r requirements.txt | Out-Null

Write-Host '[backend] Running pytest...'
python -m pytest -q
