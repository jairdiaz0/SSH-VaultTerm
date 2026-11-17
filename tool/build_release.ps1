# Builds the distributable artifacts of SSH-VaultTerm.
#
# Targets:
#   windows  release exe + Inno Setup installer
#   android  universal APK and per-ABI APKs
#   all      both (default)
#
# It does not sign anything with a real key: the Android release keeps the
# template debug signature. See docs/BUILD.md for what that means.
#
# Usage:
#   pwsh -File tool/build_release.ps1                      # windows + android
#   pwsh -File tool/build_release.ps1 -Target windows
#   pwsh -File tool/build_release.ps1 -Target android -SkipSplitApk
#   pwsh -File tool/build_release.ps1 -SkipIcons            # reuse current icons

[CmdletBinding()]
param(
  [ValidateSet('all', 'windows', 'android')]
  [string] $Target = 'all',
  [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
  [string] $InnoSetupCompiler,
  [switch] $SkipIcons,
  [switch] $SkipSplitApk
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$results = [System.Collections.Generic.List[string]]::new()

function Write-Step {
  param([string] $Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Add-Result {
  param([string] $Path, [string] $Label)
  if (-not (Test-Path $Path)) { return }
  $item = Get-Item $Path
  $size = if ($item.PSIsContainer) {
    '{0:N1} MB' -f ((Get-ChildItem $item.FullName -Recurse -File |
        Measure-Object Length -Sum).Sum / 1MB)
  } else {
    '{0:N1} MB' -f ($item.Length / 1MB)
  }
  $relative = [System.IO.Path]::GetRelativePath($RepositoryRoot, $Path)
  $line = '{0,-5}  {1}  {2}' -f $Label, $relative, $size
  $results.Add($line)
}

function Invoke-Native {
  param([string] $FilePath, [string[]] $Arguments)
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "'$FilePath' failed with exit code $LASTEXITCODE."
  }
}

function Resolve-InnoSetupCompiler {
  param([string] $Explicit)

  if ($Explicit) {
    if (-not (Test-Path $Explicit)) { throw "ISCC not found at '$Explicit'." }
    return $Explicit
  }

  $candidates = @(@(
      (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7/ISCC.exe'),
      (Join-Path $env:ProgramFiles 'Inno Setup 7/ISCC.exe'),
      (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'),
      (Join-Path $env:ProgramFiles 'Inno Setup 6/ISCC.exe')
    ) | Where-Object { $_ -and (Test-Path $_) })

  if (-not $candidates) {
    throw 'Inno Setup (ISCC.exe) not found. Install it or pass -InnoSetupCompiler <path>.'
  }
  return $candidates[0]
}

Push-Location $RepositoryRoot
try {
  if (-not $SkipIcons) {
    Write-Step 'Regenerating icons'
    Invoke-Native 'pwsh' @('-NoProfile', '-File', (Join-Path $RepositoryRoot 'tool/build_icons.ps1'))
  }

  if ($Target -in @('all', 'windows')) {
    Write-Step 'Building the Windows release'
    Invoke-Native 'flutter' @('build', 'windows', '--release')

    Write-Step 'Compiling the installer'
    $iscc = Resolve-InnoSetupCompiler $InnoSetupCompiler
    Invoke-Native $iscc @('/Q', (Join-Path $RepositoryRoot 'tool/installer/ssh-vaultterm.iss'))

    $releaseDir = Join-Path $RepositoryRoot 'build/windows/x64/runner/Release'
    Add-Result (Join-Path $releaseDir 'ssh_vault_term.exe') 'exe'
    Get-ChildItem (Join-Path $RepositoryRoot 'build/installer') -Filter '*.exe' -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime |
      Select-Object -Last 1 |
      ForEach-Object { Add-Result $_.FullName 'setup' }
  }

  if ($Target -in @('all', 'android')) {
    Write-Step 'Building the universal Android APK'
    Invoke-Native 'flutter' @('build', 'apk', '--release')

    if (-not $SkipSplitApk) {
      Write-Step 'Building the per-ABI Android APKs'
      Invoke-Native 'flutter' @('build', 'apk', '--release', '--split-per-abi')
    }

    $apkDir = Join-Path $RepositoryRoot 'build/app/outputs/flutter-apk'
    Get-ChildItem $apkDir -Filter '*release.apk' -ErrorAction SilentlyContinue |
      Sort-Object Name |
      ForEach-Object { Add-Result $_.FullName 'apk' }
  }
}
finally {
  Pop-Location
}

if ($results.Count -gt 0) {
  Write-Step 'Artifacts'
  $results | ForEach-Object { Write-Host "  $_" }
} else {
  Write-Warning 'No artifacts were produced.'
}

