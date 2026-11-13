# Install putapin for Windows PowerShell 5.1 and PowerShell 7+.
# Copies the mod to InstallDir and adds a source block to each profile.
# Safe to re-run; re-running is also how you upgrade.
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
$end = '# <<< putapin <<<'

$InstallDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallDir)
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$dest = Join-Path $InstallDir 'putapin.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'putapin.ps1') -Destination $dest -Force
if (Get-Command Unblock-File -ErrorAction SilentlyContinue) {
    Unblock-File -LiteralPath $dest -ErrorAction SilentlyContinue
}
Write-Host "Installed $dest"

# For the default location, refer to $env:LOCALAPPDATA rather than the expanded
# path, so the block stays ASCII even when the user name is not.
if ($PSBoundParameters.ContainsKey('InstallDir')) {
    $pathExpr = "'" + ($dest -replace "'", "''") + "'"
} else {
    $pathExpr = "(Join-Path `$env:LOCALAPPDATA 'putapin\putapin.ps1')"
}
$line = "`$putapinPath = $pathExpr; if (Test-Path -LiteralPath `$putapinPath) { . `$putapinPath }; Remove-Variable putapinPath"

foreach ($p in $ProfilePaths) {
    $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
    New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
    $current = Read-PutapinProfile $p
    if ($current.Text.Contains($begin)) {
        Write-Host "Already configured: $p"
        continue
    }
    # Leading newline: ends an unterminated last line, or leaves one blank line.
    # Uninstall.ps1 removes exactly this, so install+uninstall is byte-for-byte.
    $nl = Get-PutapinNewline $current.Text
    $prefix = ''
    if ($current.Text.Length -gt 0) { $prefix = $nl }
    $block = $prefix + $begin + $nl + $line + $nl + $end + $nl
    Write-PutapinProfile $p ($current.Text + $block) $current.Encoding
    Write-Host "Configured: $p"
}

# Warn only; changing a machine's execution policy is the user's decision.
$policy = "$(Get-ExecutionPolicy)"
if ($policy -in 'Restricted', 'AllSigned', 'Undefined') {
    Write-Warning "Execution policy is '$policy', so PowerShell profiles will not load. Fix with: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
}
Write-Host 'Done. Open a new PowerShell window to activate.'
