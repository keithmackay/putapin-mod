# Tests for windows/Install.ps1, windows/Uninstall.ps1 and windows/ProfileText.ps1.
# Everything runs against throwaway paths under $TestDrive; real profiles are never touched.

# Pester 6 does not allow BeforeEach at the root, hence the outer Describe.
Describe 'Windows installer' {
    BeforeAll {
        $script:WinDir = Join-Path $PSScriptRoot (Join-Path '..' (Join-Path '..' 'windows'))
        $script:InstallScript = Join-Path $script:WinDir 'Install.ps1'
        $script:UninstallScript = Join-Path $script:WinDir 'Uninstall.ps1'
        $script:ModFile = Join-Path $script:WinDir 'putapin.ps1'
        $script:Exe = (Get-Process -Id $PID).Path
        $script:Begin = '# >>> putapin >>>'
        $script:Latin1 = [Text.Encoding]::GetEncoding(28591)

        . (Join-Path $script:WinDir 'ProfileText.ps1')

        function Invoke-Install {
            & $script:InstallScript -InstallDir $script:inst -ProfilePaths $script:p1, $script:p2 3>$null 6>$null
        }
        function Invoke-Uninstall {
            & $script:UninstallScript -InstallDir $script:inst -ProfilePaths $script:p1, $script:p2 3>$null 6>$null
        }
        function Get-BlockCount([string]$Path) {
            ([regex]::Matches((Read-PutapinProfile $Path).Text, [regex]::Escape($script:Begin))).Count
        }
        function Get-Bytes([string]$Path) { [IO.File]::ReadAllBytes($Path) }
        # Run code in a fresh child PowerShell (no profile) and return its output as text.
        function Invoke-Child([string]$Code) {
            & $script:Exe -NoProfile -NonInteractive -Command $Code 2>&1 | Out-String
        }
    }

    BeforeEach {
        # $TestDrive is shared by every test in a Describe, so each test gets its own root.
        $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:inst = Join-Path $script:root 'inst'
        $script:p1 = Join-Path (Join-Path $script:root 'p1') 'profile.ps1'
        $script:p2 = Join-Path (Join-Path $script:root 'p2') 'profile.ps1'
        $script:installed = Join-Path $script:inst 'putapin.ps1'
        New-Item -ItemType Directory -Force -Path $script:root | Out-Null
        Mock Get-ExecutionPolicy { 'RemoteSigned' }
    }

    Describe 'ProfileText helpers' {
        It 'reads a missing file as empty UTF-8-with-BOM' {
            $r = Read-PutapinProfile (Join-Path $script:root 'nope.ps1')
            $r.Text | Should -BeExactly ''
            $r.Encoding.GetPreamble().Length | Should -Be 3
        }
        It 'round-trips BOM-less bytes exactly, including non-ASCII ANSI' {
            $f = Join-Path $script:root 'ansi.ps1'
            [byte[]]$bytes = 0x23, 0x20, 0xE9, 0x0D, 0x0A, 0x41
            [IO.File]::WriteAllBytes($f, $bytes)
            $r = Read-PutapinProfile $f
            Write-PutapinProfile $f $r.Text $r.Encoding
            (Get-Bytes $f) | Should -Be $bytes
        }
        It 'round-trips UTF-16LE with its BOM' {
            $f = Join-Path $script:root 'u16.ps1'
            [IO.File]::WriteAllText($f, "# caf$([char]0xE9)`r`n", [Text.Encoding]::Unicode)
            $before = Get-Bytes $f
            $r = Read-PutapinProfile $f
            $r.Text | Should -BeExactly "# caf$([char]0xE9)`r`n"
            Write-PutapinProfile $f $r.Text $r.Encoding
            (Get-Bytes $f) | Should -Be $before
        }
        It 'detects the newline style' {
            Get-PutapinNewline "a`r`nb" | Should -BeExactly "`r`n"
            Get-PutapinNewline "a`nb" | Should -BeExactly "`n"
            Get-PutapinNewline '' | Should -BeExactly ([Environment]::NewLine)
        }
    }

    Describe 'Install.ps1' {
        It 'copies the mod into InstallDir' {
            Invoke-Install
            (Get-FileHash $script:installed).Hash | Should -Be (Get-FileHash $script:ModFile).Hash
        }
        It 'creates missing profiles (and their folders) with one block each' {
            Invoke-Install
            Get-BlockCount $script:p1 | Should -Be 1
            Get-BlockCount $script:p2 | Should -Be 1
        }
        It 'writes new profiles as UTF-8 with a BOM (readable by PS 5.1 and 7)' {
            Invoke-Install
            $b = Get-Bytes $script:p1
            $b[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
        }
        It 'is idempotent' {
            Invoke-Install
            Invoke-Install
            Get-BlockCount $script:p1 | Should -Be 1
            Get-BlockCount $script:p2 | Should -Be 1
        }
        It 'preserves existing profile content' {
            New-Item -ItemType Directory -Force -Path (Split-Path $script:p1) | Out-Null
            [IO.File]::WriteAllText($script:p1, "Set-Alias ll Get-ChildItem`r`n")
            Invoke-Install
            (Read-PutapinProfile $script:p1).Text | Should -BeLike "Set-Alias ll Get-ChildItem`r`n*"
        }
        It 'matches the existing newline style' {
            New-Item -ItemType Directory -Force -Path (Split-Path $script:p1) | Out-Null
            [IO.File]::WriteAllText($script:p1, "`$x = 1`n")
            Invoke-Install
            (Read-PutapinProfile $script:p1).Text | Should -Not -Match "`r"
        }
        It 'keeps a UTF-16LE profile in UTF-16LE' {
            New-Item -ItemType Directory -Force -Path (Split-Path $script:p1) | Out-Null
            [IO.File]::WriteAllText($script:p1, "# caf$([char]0xE9)`r`n", [Text.Encoding]::Unicode)
            Invoke-Install
            $b = Get-Bytes $script:p1
            $b[0..1] | Should -Be @(0xFF, 0xFE)
            [Text.Encoding]::Unicode.GetString($b, 2, $b.Length - 2) | Should -BeLike "# caf$([char]0xE9)`r`n*$script:Begin*"
        }
        It 'leaves the existing bytes of a BOM-less ANSI profile untouched' {
            New-Item -ItemType Directory -Force -Path (Split-Path $script:p1) | Out-Null
            [byte[]]$orig = 0x23, 0x20, 0xE9, 0x0D, 0x0A
            [IO.File]::WriteAllBytes($script:p1, $orig)
            Invoke-Install
            (Get-Bytes $script:p1)[0..4] | Should -Be $orig
        }
        It 're-running refreshes an outdated installed copy' {
            Invoke-Install
            Set-Content -LiteralPath $script:installed -Value '# old'
            Invoke-Install
            (Get-FileHash $script:installed).Hash | Should -Be (Get-FileHash $script:ModFile).Hash
        }
        It 'warns (but changes nothing) when the execution policy blocks profiles' -ForEach @(
            @{ policy = 'Restricted' }, @{ policy = 'AllSigned' }, @{ policy = 'Undefined' }
        ) {
            $script:mockPolicy = $policy
            Mock Get-ExecutionPolicy { $script:mockPolicy }
            $out = & $script:InstallScript -InstallDir $script:inst -ProfilePaths $script:p1, $script:p2 3>&1 6>$null
            $warn = @($out | Where-Object { $_ -is [Management.Automation.WarningRecord] })
            $warn.Count | Should -Be 1
            $warn[0].Message | Should -Match 'Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
        }
        It 'does not warn when the execution policy allows profiles' {
            $out = & $script:InstallScript -InstallDir $script:inst -ProfilePaths $script:p1, $script:p2 3>&1 6>$null
            @($out | Where-Object { $_ -is [Management.Automation.WarningRecord] }).Count | Should -Be 0
        }
        It 'the profile block defines the claude wrapper' {
            Invoke-Install
            Invoke-Child ". '$script:p1'; (Get-Command claude).CommandType" | Should -Match 'Function'
        }
        It 'the profile still loads if the installed file is deleted' {
            Invoke-Install
            Remove-Item $script:installed
            $out = Invoke-Child ". '$script:p1'; 'LOADED-OK'"
            $out.Trim() | Should -BeExactly 'LOADED-OK'
        }
        It 'with the default InstallDir, the block refers to $env:LOCALAPPDATA and is ASCII' {
            $saved = $env:LOCALAPPDATA
            try {
                $env:LOCALAPPDATA = Join-Path $script:root ('App' + [char]0xE9)
                & $script:InstallScript -ProfilePaths $script:p1 3>$null 6>$null
                $text = (Read-PutapinProfile $script:p1).Text
                $text | Should -Match ([regex]::Escape('$env:LOCALAPPDATA'))
                $text | Should -Not -Match '[^\x00-\x7F]'
                Test-Path (Join-Path $env:LOCALAPPDATA 'putapin\putapin.ps1') | Should -BeTrue
                Invoke-Child ". '$script:p1'; (Get-Command claude).CommandType" | Should -Match 'Function'
            } finally {
                $env:LOCALAPPDATA = $saved
            }
        }
        It 'defaults ProfilePaths from the real Documents folder (follows OneDrive redirection)' {
            $ast = [Management.Automation.Language.Parser]::ParseFile($script:InstallScript, [ref]$null, [ref]$null)
            $param = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'ProfilePaths' }
            $param.DefaultValue.Extent.Text | Should -Match ([regex]::Escape("GetFolderPath('MyDocuments')"))
            $param.DefaultValue.Extent.Text | Should -Match 'WindowsPowerShell'
            $param.DefaultValue.Extent.Text | Should -Match "'PowerShell"
        }
        It 'writes through a symlinked profile, keeping the link' {
            $target = Join-Path $script:root 'dotfiles-profile.ps1'
            Set-Content -LiteralPath $target -Value '# managed'
            New-Item -ItemType Directory -Force -Path (Split-Path $script:p1) | Out-Null
            try {
                New-Item -ItemType SymbolicLink -Path $script:p1 -Target $target -ErrorAction Stop | Out-Null
            } catch {
                Set-ItResult -Skipped -Because "cannot create symlinks here: $($_.Exception.Message)"
                return
            }
            Invoke-Install
            (Get-Item $script:p1).LinkType | Should -Be 'SymbolicLink'
            Get-BlockCount $target | Should -Be 1
        }
    }

    Describe 'Uninstall.ps1' {
        It 'removes the block from every profile' {
            Invoke-Install
            Invoke-Uninstall
            Get-BlockCount $script:p1 | Should -Be 0
            Get-BlockCount $script:p2 | Should -Be 0
            (Read-PutapinProfile $script:p1).Text | Should -Not -Match 'putapin'
        }
        It 'round trip is byte-for-byte: <name>' -ForEach @(
            @{ name = 'CRLF';                 bytes = [byte[]][Text.Encoding]::ASCII.GetBytes("`$a = 1`r`n`r`n`$b = 2`r`n") }
            @{ name = 'LF';                   bytes = [byte[]][Text.Encoding]::ASCII.GetBytes("`$a = 1`n") }
            @{ name = 'no trailing newline';  bytes = [byte[]][Text.Encoding]::ASCII.GetBytes("`$a = 1") }
            @{ name = 'ANSI non-ASCII';       bytes = [byte[]](0x23, 0x20, 0xE9, 0x0D, 0x0A) }
            @{ name = 'UTF-8 BOM';            bytes = [byte[]](0xEF, 0xBB, 0xBF, 0x23, 0x0D, 0x0A) }
            @{ name = 'UTF-16LE';             bytes = [byte[]](0xFF, 0xFE, 0x23, 0x00, 0x0D, 0x00, 0x0A, 0x00) }
        ) {
            New-Item -ItemType Directory -Force -Path (Split-Path $script:p1) | Out-Null
            [IO.File]::WriteAllBytes($script:p1, $bytes)
            Invoke-Install
            Invoke-Uninstall
            (Get-Bytes $script:p1) | Should -Be $bytes
        }
        It 'keeps content added after the block' {
            New-Item -ItemType Directory -Force -Path (Split-Path $script:p1) | Out-Null
            [IO.File]::WriteAllText($script:p1, "`$a = 1`r`n")
            Invoke-Install
            $r = Read-PutapinProfile $script:p1
            Write-PutapinProfile $script:p1 ($r.Text + "`$b = 2`r`n") $r.Encoding
            Invoke-Uninstall
            (Read-PutapinProfile $script:p1).Text | Should -BeExactly "`$a = 1`r`n`$b = 2`r`n"
        }
        It 'writes a .putapin.bak backup of the installed profile' {
            Invoke-Install
            $before = Get-Bytes $script:p1
            Invoke-Uninstall
            (Get-Bytes "$script:p1.putapin.bak") | Should -Be $before
        }
        It 'deletes the installed file and its empty folder' {
            Invoke-Install
            Invoke-Uninstall
            Test-Path $script:installed | Should -BeFalse
            Test-Path $script:inst | Should -BeFalse
        }
        It 'keeps the folder if it holds other files' {
            Invoke-Install
            Set-Content -LiteralPath (Join-Path $script:inst 'notes.txt') -Value 'x'
            Invoke-Uninstall
            Test-Path $script:installed | Should -BeFalse
            Test-Path (Join-Path $script:inst 'notes.txt') | Should -BeTrue
        }
        It 'is a no-op when not installed' {
            New-Item -ItemType Directory -Force -Path (Split-Path $script:p1) | Out-Null
            [IO.File]::WriteAllText($script:p1, "`$a = 1`r`n")
            $before = Get-Bytes $script:p1
            { Invoke-Uninstall } | Should -Not -Throw
            (Get-Bytes $script:p1) | Should -Be $before
            Test-Path "$script:p1.putapin.bak" | Should -BeFalse
        }
        It 'the profile no longer defines claude' {
            Invoke-Install
            Invoke-Uninstall
            $out = Invoke-Child ". '$script:p1'; [bool](Get-Command claude -CommandType Function -ErrorAction SilentlyContinue)"
            $out.Trim() | Should -BeExactly 'False'
        }
        It 'writes through a symlinked profile, keeping the link' {
            $target = Join-Path $script:root 'dotfiles-profile.ps1'
            [IO.File]::WriteAllText($target, "# managed`r`n")
            New-Item -ItemType Directory -Force -Path (Split-Path $script:p1) | Out-Null
            try {
                New-Item -ItemType SymbolicLink -Path $script:p1 -Target $target -ErrorAction Stop | Out-Null
            } catch {
                Set-ItResult -Skipped -Because "cannot create symlinks here: $($_.Exception.Message)"
                return
            }
            Invoke-Install
            Invoke-Uninstall
            (Get-Item $script:p1).LinkType | Should -Be 'SymbolicLink'
            [IO.File]::ReadAllText($target) | Should -BeExactly "# managed`r`n"
        }
    }
}
