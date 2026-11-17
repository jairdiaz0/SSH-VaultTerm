# Regenerates every application icon from icons/terminal-icon.svg.
#
# Why a plate: the mark is pure black. On a transparent background it vanishes
# on a dark taskbar or a dark launcher. Every generated icon therefore sits on a
# light rounded plate: on a dark background the plate keeps the silhouette
# visible, and on a light background the plate blends in and the original black
# mark shows, exactly as the source art.
#
# Outputs:
#   windows/runner/resources/app_icon.ico     (16-256 px, uncompressed DIB entries)
#   android/app/src/main/res/mipmap-*/        (legacy, adaptive foreground and
#                                              monochrome layers)
#   icons/generated/                          (master previews for the docs)
#
# Requires Windows (System.Drawing) and Microsoft Edge for the SVG render; if
# Edge is missing it falls back to the 256 px PNG.
#
# Usage: pwsh -File tool/build_icons.ps1 [-SkipAndroid] [-SkipWindows]

[CmdletBinding()]
param(
  [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
  [switch] $SkipAndroid,
  [switch] $SkipWindows
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$PlateColor = [System.Drawing.Color]::FromArgb(255, 246, 247, 249)
$Generated = Join-Path $RepositoryRoot 'icons/generated'
New-Item -ItemType Directory -Force -Path $Generated | Out-Null

# --------------------------------------------------------------------------
# Source mark
# --------------------------------------------------------------------------

function Get-GlyphMaster {
  param([string] $Root)

  $svgPath = Join-Path $Root 'icons/terminal-icon.svg'
  $edges = @(@(
      (Join-Path $env:ProgramFiles 'Microsoft/Edge/Application/msedge.exe'),
      (Join-Path ${env:ProgramFiles(x86)} 'Microsoft/Edge/Application/msedge.exe')
    ) | Where-Object { Test-Path $_ })

  if ($svgPath -and (Test-Path $svgPath) -and $edges.Count -gt 0) {
    $edge = $edges[0]
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ('ssh-icon-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    try {
      $svg = Get-Content $svgPath -Raw
      $html = @"
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
svg { display: block; width: 1024px !important; height: 1024px !important; }
</style></head><body>$svg</body></html>
"@
      $htmlPath = Join-Path $work 'glyph.html'
      $pngPath = Join-Path $work 'glyph.png'
      Set-Content -Path $htmlPath -Value $html -Encoding UTF8

      $url = 'file:///' + ($htmlPath -replace '\\', '/')
      & $edge --headless=new --disable-gpu --hide-scrollbars `
        --force-device-scale-factor=1 --default-background-color=00000000 `
        --user-data-dir=(Join-Path $work 'edge') `
        --screenshot=$pngPath --window-size=1024,1024 $url 2>&1 | Out-Null
      for ($i = 0; $i -lt 40 -and -not (Test-Path $pngPath); $i++) {
        Start-Sleep -Milliseconds 250
      }

      if (Test-Path $pngPath) {
        $rendered = New-Object System.Drawing.Bitmap($pngPath)
        $bounds = Get-ContentBounds $rendered
        if ($bounds.Right -lt 900) {
          throw "The SVG render kept its 200 px default ($($bounds.Right) px wide)."
        }
        $master = New-Object System.Drawing.Bitmap(1024, 1024,
          [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($master)
        $g.DrawImage($rendered, 0, 0, 1024, 1024)
        $g.Dispose()
        $rendered.Dispose()
        return $master
      }
    }
    finally {
      Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
    }
  }

  $fallback = Join-Path $Root 'icons/terminal-svgrepo-com.png'
  if (-not (Test-Path $fallback)) {
    throw 'Neither icons/terminal-icon.svg (with Edge) nor icons/terminal-svgrepo-com.png is available.'
  }
  $source = New-Object System.Drawing.Bitmap($fallback)
  $master = New-Object System.Drawing.Bitmap(1024, 1024,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($master)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($source, 0, 0, 1024, 1024)
  $g.Dispose()
  $source.Dispose()
  return $master
}

function Get-ContentBounds {
  param([System.Drawing.Bitmap] $Bitmap)
  $minX = $Bitmap.Width; $minY = $Bitmap.Height; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $Bitmap.Height; $y += 4) {
    for ($x = 0; $x -lt $Bitmap.Width; $x += 4) {
      if ($Bitmap.GetPixel($x, $y).A -gt 32) {
        if ($x -lt $minX) { $minX = $x }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  [pscustomobject]@{ Left = $minX; Top = $minY; Right = $maxX; Bottom = $maxY }
}

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

function New-QualityGraphics {
  param([System.Drawing.Bitmap] $Bitmap)
  $g = [System.Drawing.Graphics]::FromImage($Bitmap)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  return $g
}

function New-RoundedPath {
  param([single] $Width, [single] $Height, [single] $Radius)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $Radius * 2
  $path.AddArc(0, 0, $d, $d, 180, 90)
  $path.AddArc($Width - $d, 0, $d, $d, 270, 90)
  $path.AddArc($Width - $d, $Height - $d, $d, $d, 0, 90)
  $path.AddArc(0, $Height - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

function New-PlatedIcon {
  param([System.Drawing.Bitmap] $Glyph, [int] $Size, [double] $Coverage = 0.66)
  $bitmap = New-Object System.Drawing.Bitmap($Size, $Size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = New-QualityGraphics $bitmap
  $radius = [single]($Size * 0.22)
  $path = New-RoundedPath $Size $Size $radius
  $brush = New-Object System.Drawing.SolidBrush($PlateColor)
  $g.FillPath($brush, $path)
  $brush.Dispose()
  $path.Dispose()

  $side = [single]($Size * $Coverage)
  $offset = [single](($Size - $side) / 2)
  $dest = New-Object System.Drawing.RectangleF($offset, $offset, $side, $side)
  $src = New-Object System.Drawing.RectangleF(0, 0, $Glyph.Width, $Glyph.Height)
  $g.DrawImage($Glyph, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  return $bitmap
}

# Transparent mark only: used by the Android adaptive and monochrome layers,
# where the plate comes from the background layer or from the launcher theme.
function New-GlyphIcon {
  param([System.Drawing.Bitmap] $Glyph, [int] $Size, [double] $Coverage = 0.58)
  $bitmap = New-Object System.Drawing.Bitmap($Size, $Size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = New-QualityGraphics $bitmap
  $side = [single]($Size * $Coverage)
  $offset = [single](($Size - $side) / 2)
  $dest = New-Object System.Drawing.RectangleF($offset, $offset, $side, $side)
  $src = New-Object System.Drawing.RectangleF(0, 0, $Glyph.Width, $Glyph.Height)
  $g.DrawImage($Glyph, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  return $bitmap
}

function Save-Png {
  param([System.Drawing.Bitmap] $Bitmap, [string] $Path)
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

# --------------------------------------------------------------------------
# ICO writer
# --------------------------------------------------------------------------

function Get-DibEntry {
  param([System.Drawing.Bitmap] $Bitmap)
  $size = $Bitmap.Width
  $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
  $data = $Bitmap.LockBits($rect,
    [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $stride = $data.Stride
  $raw = New-Object byte[] ($stride * $size)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $raw, 0, $raw.Length)
  $Bitmap.UnlockBits($data)

  $stream = New-Object System.IO.MemoryStream
  $writer = New-Object System.IO.BinaryWriter($stream)
  # BITMAPINFOHEADER; height is doubled because the DIB holds XOR + AND masks.
  $writer.Write([int]40)
  $writer.Write([int]$size)
  $writer.Write([int]($size * 2))
  $writer.Write([int16]1)
  $writer.Write([int16]32)
  $writer.Write([int]0)
  $writer.Write([int]($size * $size * 4))
  $writer.Write([int]0)
  $writer.Write([int]0)
  $writer.Write([int]0)
  $writer.Write([int]0)

  for ($y = $size - 1; $y -ge 0; $y--) {
    $writer.Write($raw, $y * $stride, $size * 4)
  }

  $maskRow = [int]([Math]::Floor(($size + 31) / 32) * 4)
  $mask = New-Object byte[] ($maskRow * $size)
  for ($y = 0; $y -lt $size; $y++) {
    $src = $y * $stride
    $dst = ($size - 1 - $y) * $maskRow
    for ($x = 0; $x -lt $size; $x++) {
      if ($raw[$src + $x * 4 + 3] -lt 128) {
        $index = $dst + [int][Math]::Floor($x / 8)
        $mask[$index] = $mask[$index] -bor (0x80 -shr ($x % 8))
      }
    }
  }
  $writer.Write($mask, 0, $mask.Length)
  $writer.Flush()
  $bytes = $stream.ToArray()
  $writer.Dispose()
  $stream.Dispose()
  return , $bytes
}

function Get-PngEntry {
  param([System.Drawing.Bitmap] $Bitmap)
  $stream = New-Object System.IO.MemoryStream
  $Bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $bytes = $stream.ToArray()
  $stream.Dispose()
  return , $bytes
}

function Save-Ico {
  param([System.Drawing.Bitmap[]] $Bitmaps, [string] $Path)
  $entries = @()
  foreach ($bitmap in $Bitmaps) {
    # Uncompressed DIB for every size: the 256 entry is the only one Windows
    # could take as PNG, and some tools (including Inno Setup) reject that.
    $bytes = Get-DibEntry $bitmap
    $entries += , [pscustomobject]@{ Size = $bitmap.Width; Bytes = $bytes }
  }

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  $stream = New-Object System.IO.MemoryStream
  $writer = New-Object System.IO.BinaryWriter($stream)
  $writer.Write([int16]0)
  $writer.Write([int16]1)
  $writer.Write([int16]$entries.Count)
  $offset = 6 + 16 * $entries.Count
  foreach ($entry in $entries) {
    $dimension = if ($entry.Size -ge 256) { 0 } else { $entry.Size }
    $writer.Write([byte]$dimension)
    $writer.Write([byte]$dimension)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([int16]1)
    $writer.Write([int16]32)
    $writer.Write([int]$entry.Bytes.Length)
    $writer.Write([int]$offset)
    $offset += $entry.Bytes.Length
  }
  foreach ($entry in $entries) {
    $writer.Write($entry.Bytes, 0, $entry.Bytes.Length)
  }
  $writer.Flush()
  [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
  $writer.Dispose()
  $stream.Dispose()
}

# --------------------------------------------------------------------------
# Run
# --------------------------------------------------------------------------

$glyph = Get-GlyphMaster $RepositoryRoot
Write-Host "Source mark rendered: $($glyph.Width)x$($glyph.Height)"

Save-Png (New-PlatedIcon $glyph 1024) (Join-Path $Generated 'app-icon-1024.png')
Save-Png (New-PlatedIcon $glyph 512) (Join-Path $Generated 'app-icon-512.png')

if (-not $SkipWindows) {
  $icoSizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
  $bitmaps = @()
  foreach ($size in $icoSizes) { $bitmaps += , (New-PlatedIcon $glyph $size) }
  $icoPath = Join-Path $RepositoryRoot 'windows/runner/resources/app_icon.ico'
  Save-Ico $bitmaps $icoPath
  $bitmaps | ForEach-Object { $_.Dispose() }
  $length = (Get-Item $icoPath).Length
  Write-Host "Windows icon: $icoPath ($($icoSizes -join ', ') px, $length bytes)"
}

if (-not $SkipAndroid) {
  $res = Join-Path $RepositoryRoot 'android/app/src/main/res'
  $densities = [ordered]@{
    'mdpi'    = 48
    'hdpi'    = 72
    'xhdpi'   = 96
    'xxhdpi'  = 144
    'xxxhdpi' = 192
  }
  $foreground = [ordered]@{
    'mdpi'    = 108
    'hdpi'    = 162
    'xhdpi'   = 216
    'xxhdpi'  = 324
    'xxxhdpi' = 432
  }
  foreach ($density in $densities.Keys) {
    $folder = Join-Path $res "mipmap-$density"
    $launcher = New-PlatedIcon $glyph $densities[$density]
    Save-Png $launcher (Join-Path $folder 'ic_launcher.png')
    $launcher.Dispose()

    $layer = New-GlyphIcon $glyph $foreground[$density]
    Save-Png $layer (Join-Path $folder 'ic_launcher_foreground.png')
    Save-Png $layer (Join-Path $folder 'ic_launcher_monochrome.png')
    $layer.Dispose()
  }
  Write-Host "Android icons written to $res"
}

$glyph.Dispose()
Write-Host 'Icons regenerated.'



