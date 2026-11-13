# putapin - ask "Resume prior session? (Y/n)" when launching Claude Code.
# Dot-source this file from your PowerShell profile. Keep it PS 5.1-compatible
# and ASCII-only (PS 5.1 reads BOM-less scripts as Windows-1252).

# Claude Code keys sessions by the project path with every non-alphanumeric character as '-'.
function ConvertTo-PutapinProjectKey([string]$Path) {
    $Path -creplace '[^A-Za-z0-9]', '-'
}

# Seam for tests: $HOME is read-only in PowerShell.
function Get-PutapinHome { $HOME }

# True if Claude Code has at least one saved session for directory $Path.
function Test-PutapinSession([string]$Path) {
    $root = $env:CLAUDE_CONFIG_DIR
    if (-not $root) { $root = Join-Path (Get-PutapinHome) '.claude' }
    $dir = Join-Path (Join-Path $root 'projects') (ConvertTo-PutapinProjectKey $Path)
    $hit = Get-ChildItem -LiteralPath $dir -Filter '*.jsonl' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    [bool]$hit
}

# Show the prompt on the host (never the pipeline) and read one line. $null on EOF.
# Not Read-Host: it appends ": " to the prompt and cannot signal EOF.
function Read-PutapinLine {
    [CmdletBinding()]
    param()
    Write-Host -NoNewline 'Resume prior session? (Y/n) '
    $line = [Console]::ReadLine()
    if ($null -eq $line) { Write-Host '' }
    $line
}

# Prompt until we get an answer: 'yes', 'no', or 'abort' (EOF).
# Surrounding whitespace is ignored; matching is case-insensitive.
function Read-PutapinAnswer {
    while ($true) {
        $reply = Read-PutapinLine
        if ($null -eq $reply) { return 'abort' }
        switch -Regex ($reply.Trim()) {
            '^(y|yes)?$' { return 'yes' }
            '^(n|no)$'   { return 'no' }
        }
    }
}

# Seam for tests: true when both stdin and stdout are a console.
function Test-PutapinInteractive {
    -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected
}

# The real Claude Code CLI: claude.exe (native installer) or claude.ps1/claude.cmd (npm).
function Get-PutapinRealClaude {
    Get-Command claude -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

# Never clobber someone else's alias or function; redefining our own is fine.
# (In PowerShell an alias outranks a function, so ours would never run anyway.)
$putapinInstall = $true
$putapinExisting = Get-Command claude -CommandType Alias, Function -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($putapinExisting -and $putapinExisting.CommandType -eq 'Alias') {
    $putapinInstall = $false
    Write-Warning "putapin: 'claude' is already an alias; not installing the resume prompt."
} elseif ($putapinExisting -and $putapinExisting.ScriptBlock.ToString() -notmatch 'Read-PutapinAnswer') {
    $putapinInstall = $false
    Write-Warning "putapin: 'claude' is already a function; not installing the resume prompt."
}

# The wrapper. Prompts only for a bare `claude` in a console when this directory
# has a prior session; otherwise behaves exactly like the real CLI. A simple
# (non-advanced) function, so every argument passes through untouched via $args.
if ($putapinInstall) {
    function claude {
        $real = Get-PutapinRealClaude
        if (-not $real) {
            Write-Error "putapin: could not find the real 'claude' on PATH."
            return
        }
        $here = (Get-Location -PSProvider FileSystem).ProviderPath
        if ($args.Count -gt 0 -or -not (Test-PutapinInteractive) -or -not (Test-PutapinSession $here)) {
            & $real @args
            return
        }
        switch (Read-PutapinAnswer) {
            'yes'   { & $real --continue }
            'no'    { & $real }
            default { $global:LASTEXITCODE = 130 }
        }
    }
}
Remove-Variable putapinInstall, putapinExisting
