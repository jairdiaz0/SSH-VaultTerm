# Deletes the local development data of SSH Client: the encrypted databases and
# the secrets this app stored in Windows Credential Manager.
#
# It prints everything it is about to delete and requires you to type BORRAR.
# Nothing is deleted otherwise. Respects SSH_CLIENT_DATA_DIR and
# SSH_CLIENT_SECRET_NAMESPACE, the same overrides the app uses.
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Get-DataDirectory {
    if ($env:SSH_CLIENT_DATA_DIR -and $env:SSH_CLIENT_DATA_DIR.Trim() -ne '') {
        return [System.IO.Path]::GetFullPath($env:SSH_CLIENT_DATA_DIR)
    }
    return Join-Path $env:APPDATA 'dev.sshclient\ssh_client\ssh_client'
}

$namespace = if ($env:SSH_CLIENT_SECRET_NAMESPACE) { $env:SSH_CLIENT_SECRET_NAMESPACE.Trim() } else { '' }
$dataDir = Get-DataDirectory

# flutter_secure_storage_windows prefixes every Credential Manager target with
# "<binary>_VGhpcyBpcyB0aGUgcHJlZml4IGZv_", so this filter only matches this app.
$credentialFilter = 'ssh_client_*'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class SshClientCredentials {
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredEnumerate(string filter, int flags, out int count, out IntPtr credentials);

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredDelete(string target, int type, int flags);

    [DllImport("advapi32.dll")]
    private static extern void CredFree(IntPtr buffer);

    public static List<string> List(string filter) {
        var targets = new List<string>();
        int count;
        IntPtr pointer;
        if (!CredEnumerate(filter, 0, out count, out pointer)) {
            return targets;
        }
        try {
            for (var i = 0; i < count; i++) {
                var entry = Marshal.ReadIntPtr(pointer, i * IntPtr.Size);
                var targetName = Marshal.ReadIntPtr(entry, 8);
                targets.Add(Marshal.PtrToStringUni(targetName));
            }
        } finally {
            CredFree(pointer);
        }
        return targets;
    }
}
'@

Write-Host 'Datos de desarrollo de SSH Client' -ForegroundColor Cyan
Write-Host "Directorio de datos: $dataDir"

$files = @()
if (Test-Path $dataDir) {
    $files = Get-ChildItem -Path $dataDir -Recurse -File | Where-Object {
        $_.Extension -in '.db', '.db-wal', '.db-shm', '.sqlite', '.sqlite3'
    }
}

$credentials = @( [SshClientCredentials]::List($credentialFilter) | Where-Object {
    if ($namespace -eq '') { $true } else { $_ -like "*$namespace*" }
})

Write-Host ''
Write-Host 'Archivos que se borrarán:' -ForegroundColor Yellow
if ($files.Count -eq 0) {
    Write-Host '  (ninguno)'
} else {
    $files | ForEach-Object { Write-Host "  $($_.FullName) ($($_.Length) bytes)" }
}

Write-Host ''
Write-Host 'Secretos de la app en Credential Manager que se borrarán:' -ForegroundColor Yellow
if ($credentials.Count -eq 0) {
    Write-Host '  (ninguno)'
} else {
    $credentials | ForEach-Object { Write-Host "  $_" }
}
if ($namespace -ne '') {
    Write-Host "  (limitado al namespace '$namespace')"
}

if ($files.Count -eq 0 -and $credentials.Count -eq 0) {
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
    [void][SshClientCredentials]::CredDelete($credential, 1, 0)
}
if (Test-Path $dataDir) {
    Remove-Item -Path $dataDir -Recurse -Force
}

Write-Host ''
Write-Host "Borrados $($files.Count) archivos y $($credentials.Count) secretos." -ForegroundColor Green
