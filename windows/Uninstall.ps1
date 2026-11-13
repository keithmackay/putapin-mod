# Uninstall putapin: remove the profile blocks and the installed mod.
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'putapin'),
    # GetFolderPath follows OneDrive/folder redirection of Documents.
    [string[]]$ProfilePaths = @(
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\profile.ps1'),
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\profile.ps1')
    )
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ProfileText.ps1')
$begin = '# >>> putapin >>>'
# The block plus the one newline Install.ps1 put before it.
$pattern = '(?s)(\r?\n)?# >>> putapin >>>\r?\n.*?# <<< putapin <<<(\r?\n)?'

foreach ($p in $ProfilePaths) {
    $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $current = Read-PutapinProfile $p
    if (-not $current.Text.Contains($begin)) { continue }
    Copy-Item -LiteralPath $p -Destination "$p.putapin.bak" -Force
    Write-PutapinProfile $p ([regex]::Replace($current.Text, $pattern, '')) $current.Encoding
    Write-Host "Removed putapin from $p (backup: $p.putapin.bak)"
}

$InstallDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallDir)
Remove-Item -LiteralPath (Join-Path $InstallDir 'putapin.ps1') -Force -ErrorAction SilentlyContinue
if ((Test-Path -LiteralPath $InstallDir) -and -not (Get-ChildItem -LiteralPath $InstallDir -Force)) {
    Remove-Item -LiteralPath $InstallDir
}
Write-Host 'Uninstalled. Open a new PowerShell window to finish.'
