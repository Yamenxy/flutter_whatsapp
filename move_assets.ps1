# Move all files from images/ to assets/images/
$src = Join-Path $PSScriptRoot 'images'
$dst = Join-Path $PSScriptRoot 'assets\images'
if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
Get-ChildItem -Path $src -File -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Move-Item -Path $_.FullName -Destination (Join-Path $dst $_.Name) -Force
        Write-Host "Moved: $($_.Name)"
    } catch {
        Write-Warning "Failed to move $($_.Name): $_"
    }
}
Write-Host "Done. Run `flutter pub get` if needed."