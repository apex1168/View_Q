param([switch]$DebugBuild)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-env.ps1')
Push-Location $ViewQRoot
try {
    # One APK containing all three Flutter Android release architectures.
    # Windows Application Control blocks font-subset.exe on this computer.
    $mode = if ($DebugBuild) { 'debug' } else { 'release' }
    flutter build apk "--$mode" --target-platform android-arm,android-arm64,android-x64 --no-tree-shake-icons
    if ($LASTEXITCODE -ne 0) { throw 'The universal Android build failed.' }
    $output = Join-Path $ViewQRoot 'dist'
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    $name = if ($DebugBuild) { 'View-Q-universal-debug.apk' } else { 'View-Q-universal.apk' }
    $apk = Join-Path $output $name
    Copy-Item -LiteralPath (Join-Path $ViewQRoot "build\app\outputs\flutter-apk\app-$mode.apk") -Destination $apk
    $hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $name" | Set-Content -LiteralPath "$apk.sha256" -Encoding ascii
    Write-Output "Share this file: $apk"
} finally {
    Pop-Location
}
