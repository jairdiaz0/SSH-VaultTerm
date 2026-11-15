# Deletes the local development data of SSH Client so the app starts as a fresh
# install: encrypted databases, the Windows secure-storage file that holds the
# database keys, and any leftover Credential Manager entries of this app.
#
# It prints everything it will delete and requires typing BORRAR.
# Respects SSH_CLIENT_DATA_DIR and SSH_CLIENT_SECRET_NAMESPACE.
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$namespace = if ($env:SSH_CLIENT_SECRET_NAMESPACE) { $env:SSH_CLIENT_SECRET_NAMESPACE.Trim() } else { '' }

# Production layout since round 4: LOCALAPPDATA, never Roaming.
$dataDir = if ($env:SSH_CLIENT_DATA_DIR -and $env:SSH_CLIENT_DATA_DIR.Trim() -ne '') {
    [System.IO.Path]::GetFullPath($env:SSH_CLIENT_DATA_DIR)
} else {
    Join-Path $env:LOCALAPPDATA 'dev.sshclient\ssh_client'
}

# Old location (rounds 1-3). Never opened by the app; deleted if present.
$legacyDataDir = Join-Path $env:APPDATA 'dev.sshclient\ssh_client\ssh_client'

# flutter_secure_storage_windows 4.x keeps its values in this DPAPI file inside
# the app-support (Roaming) folder, not in Credential Manager.
$secureStorageFile = Join-Path $env:APPDATA 'dev.sshclient\ssh_client\flutter_secure_storage.dat'

$files = @()
foreach ($dir in @($dataDir, $legacyDataDir)) {
    if (Test-Path $dir) {
        $files += Get-ChildItem -Path $dir -Recurse -File
    }
}
$prefsCandidates = @(
    (Join-Path $env:APPDATA 'dev.sshclient\ssh_client\shared_preferences.json'),
    (Join-Path $dataDir 'shared_preferences.json')
) | Where-Object { Test-Path $_ }

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class SshClientCreds {
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredEnumerate(string filter, int flags, out int count, out IntPtr credentials);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredDelete(string target, int type, int flags);
    [DllImport("advapi32.dll")]
    private static extern void CredFree(IntPtr buffer);
    public static List<string> List(string filter) {
        var targets = new List<string>(); int count; IntPtr pointer;
        if (!CredEnumerate(filter, 0, out count, out pointer)) { return targets; }
        try {
            for (var i = 0; i < count; i++) {
                var entry = Marshal.ReadIntPtr(pointer, i * IntPtr.Size);
                var targetName = Marshal.ReadIntPtr(entry, 8);
                targets.Add(Marshal.PtrToStringUni(targetName));
            }
        } finally { CredFree(pointer); }
        return targets;
    }
}
'@

# Fallback for older plugin versions that used Credential Manager.
$credentials = @([SshClientCreds]::List('ssh_client_*'))

Write-Host 'Datos de desarrollo de SSH Client' -ForegroundColor Cyan
Write-Host "Directorio de datos: $dataDir"

Write-Host ''
Write-Host 'Archivos que se borrarán:' -ForegroundColor Yellow
if ($files.Count -eq 0) { Write-Host '  (ninguno)' } else { $files | ForEach-Object { Write-Host "  $($_.FullName)" } }

Write-Host ''
Write-Host 'Almacén de claves de la app (archivo DPAPI):' -ForegroundColor Yellow
if (Test-Path $secureStorageFile) {
    if ($namespace -eq '') {
        Write-Host "  $secureStorageFile"
    } else {
        Write-Host "  $secureStorageFile (se conserva: hay namespace '$namespace')"
    }
} else {
    Write-Host '  (ninguno)'
}

if ($prefsCandidates.Count -gt 0) {
    Write-Host ''
    Write-Host 'Preferencias de la app:' -ForegroundColor Yellow
    $prefsCandidates | ForEach-Object { Write-Host "  $_" }
}

if ($credentials.Count -gt 0) {
    Write-Host ''
    Write-Host 'Credenciales antiguas en Credential Manager:' -ForegroundColor Yellow
    $credentials | ForEach-Object { Write-Host "  $_" }
}

$hasWork = $files.Count -gt 0 -or $prefsCandidates.Count -gt 0 -or $credentials.Count -gt 0 -or
    (Test-Path $secureStorageFile -and $namespace -eq '')
if (-not $hasWork) {
    Write-Host ''
    Write-Host 'No hay nada que borrar.' -ForegroundColor Green
    exit 0
}

if (-not $Force) {
    Write-Host ''
    $answer = Read-Host 'Escribe BORRAR para confirmar (cualquier otra cosa cancela)'
    if ($answer -ne 'BORRAR') {
        Write-Host 'Cancelado. No se ha borrado nada.' -ForegroundColor Green
        exit 1
    }
}

foreach ($credential in $credentials) {
    [void][SshClientCreds]::CredDelete($credential, 1, 0)
}
foreach ($dir in @($dataDir, $legacyDataDir)) {
    if (Test-Path $dir) { Remove-Item -Path $dir -Recurse -Force }
}
if ($namespace -eq '' -and (Test-Path $secureStorageFile)) {
    Remove-Item -Path $secureStorageFile -Force
}
foreach ($prefs in $prefsCandidates) {
    if (Test-Path $prefs) { Remove-Item -Path $prefs -Force }
}

Write-Host ''
Write-Host "Borrados $($files.Count) archivos, $($credentials.Count) credenciales y el almacén de claves si existía." -ForegroundColor Green
