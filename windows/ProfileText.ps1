# Encoding-preserving read/write for PowerShell profile files, shared by
# Install.ps1 and Uninstall.ps1. Keep ASCII-only and PS 5.1-compatible.

# Returns @{ Text = <string>; Encoding = <Text.Encoding> }.
# A file with a BOM uses that encoding. A BOM-less file is read as Latin-1,
# which maps every byte to exactly one char, so writing it back reproduces the
# original bytes (ANSI or UTF-8) exactly. A missing file reads as empty
# UTF-8-with-BOM, the encoding new profiles are written in (PS 5.1 and 7 both
# read it correctly).
function Read-PutapinProfile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return @{ Text = ''; Encoding = (New-Object Text.UTF8Encoding $true) }
    }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $skip = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = New-Object Text.UTF8Encoding $true
        $skip = 3
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = New-Object Text.UnicodeEncoding $false, $true
        $skip = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = New-Object Text.UnicodeEncoding $true, $true
        $skip = 2
    } else {
        $encoding = [Text.Encoding]::GetEncoding(28591)
    }
    @{ Text = $encoding.GetString($bytes, $skip, $bytes.Length - $skip); Encoding = $encoding }
}

# Write $Text to $Path in $Encoding, including its BOM (if it has one).
# WriteAllBytes opens the path normally, so a symlinked profile stays a link.
function Write-PutapinProfile([string]$Path, [string]$Text, [Text.Encoding]$Encoding) {
    $preamble = $Encoding.GetPreamble()
    $body = $Encoding.GetBytes($Text)
    $bytes = New-Object byte[] ($preamble.Length + $body.Length)
    [Array]::Copy($preamble, 0, $bytes, 0, $preamble.Length)
    [Array]::Copy($body, 0, $bytes, $preamble.Length, $body.Length)
    [IO.File]::WriteAllBytes($Path, $bytes)
}

# The newline style already used in $Text (CRLF or LF); the platform default if none.
function Get-PutapinNewline([string]$Text) {
    if ($Text.Contains("`r`n")) { return "`r`n" }
    if ($Text.Contains("`n")) { return "`n" }
    [Environment]::NewLine
}
