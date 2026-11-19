# Render the user-supplied logo into the platform icon sizes.
# The square crop removes excess black padding while preserving the complete mark.
Add-Type -AssemblyName System.Drawing
$ViewQRoot = Split-Path $PSScriptRoot -Parent
$ViewQSourcePath = Join-Path $ViewQRoot 'assets\branding\logo-source.png'
$ViewQSource = [System.Drawing.Image]::FromFile($ViewQSourcePath)
try {
    $ViewQCrop = [System.Drawing.Rectangle]::new(
        [int]($ViewQSource.Width * 0.21), [int]($ViewQSource.Height * 0.21),
        [int]($ViewQSource.Width * 0.58), [int]($ViewQSource.Height * 0.58))
    function Write-ViewQIcon([string]$Destination, [int]$Size, [bool]$Adaptive = $false) {
        $ViewQBitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $ViewQGraphics = [System.Drawing.Graphics]::FromImage($ViewQBitmap)
        try {
            $ViewQGraphics.Clear([System.Drawing.Color]::Black)
            $ViewQGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $ViewQGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $ViewQInset = if ($Adaptive) { [int]($Size * 0.15) } else { 0 }
            $ViewQTarget = [System.Drawing.Rectangle]::new($ViewQInset, $ViewQInset, $Size - 2 * $ViewQInset, $Size - 2 * $ViewQInset)
            $ViewQGraphics.DrawImage($ViewQSource, $ViewQTarget, $ViewQCrop, [System.Drawing.GraphicsUnit]::Pixel)
            $ViewQBitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $ViewQGraphics.Dispose()
            $ViewQBitmap.Dispose()
        }
    }
    $ViewQIcons = @(Get-ChildItem (Join-Path $ViewQRoot 'android\app\src\main\res') -Filter ic_launcher.png -Recurse)
    $ViewQIcons += @(Get-ChildItem (Join-Path $ViewQRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset') -Filter '*.png')
    foreach ($ViewQIcon in $ViewQIcons) {
        $ViewQExisting = [System.Drawing.Image]::FromFile($ViewQIcon.FullName)
        $ViewQSize = $ViewQExisting.Width
        $ViewQExisting.Dispose()
        Write-ViewQIcon $ViewQIcon.FullName $ViewQSize
    }
    Write-ViewQIcon (Join-Path $ViewQRoot 'assets\branding\logo.png') 256
    $ViewQDrawable = Join-Path $ViewQRoot 'android\app\src\main\res\drawable-nodpi'
    New-Item -ItemType Directory -Force $ViewQDrawable | Out-Null
    Write-ViewQIcon (Join-Path $ViewQDrawable 'ic_launcher_foreground.png') 432 $true
} finally {
    $ViewQSource.Dispose()
}
