BeforeAll {
    $script:ModPath = Join-Path $PSScriptRoot (Join-Path '..' (Join-Path '..' (Join-Path 'windows' 'putapin.ps1')))
    . $script:ModPath
}

Describe 'harness' {
    It 'dot-sources cleanly' {
        $true | Should -BeTrue
    }
}

Describe 'ConvertTo-PutapinProjectKey' {
    It 'encodes a Windows path' {
        ConvertTo-PutapinProjectKey 'C:\Users\x\proj' | Should -BeExactly 'C--Users-x-proj'
    }
    It 'encodes a Unix path, including dots and underscores' {
        ConvertTo-PutapinProjectKey '/Users/k.m/my_proj' | Should -BeExactly '-Users-k-m-my-proj'
    }
    It 'preserves case, digits and dashes' {
        ConvertTo-PutapinProjectKey 'D:\a-B\c9' | Should -BeExactly 'D--a-B-c9'
    }
    It 'replaces spaces and non-ASCII letters' {
        # Built with [char] because PS 5.1 reads BOM-less scripts as Windows-1252.
        ConvertTo-PutapinProjectKey ('C:\My Caf' + [char]0xE9) | Should -BeExactly 'C--My-Caf-'
    }
}

Describe 'Test-PutapinSession' {
    BeforeEach {
        $script:savedConfigDir = $env:CLAUDE_CONFIG_DIR
        # $TestDrive is shared by every test in a Describe, so isolate each test's directories.
        $env:CLAUDE_CONFIG_DIR = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:projectDir = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:keyDir = Join-Path (Join-Path $env:CLAUDE_CONFIG_DIR 'projects') (ConvertTo-PutapinProjectKey $script:projectDir)
    }
    AfterEach {
        $env:CLAUDE_CONFIG_DIR = $script:savedConfigDir
    }

    It 'is true when a jsonl exists for the directory' {
        New-Item -ItemType Directory -Force -Path $script:keyDir | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:keyDir 's.jsonl') | Out-Null
        Test-PutapinSession $script:projectDir | Should -BeTrue
    }
    It 'is false when the project folder is missing' {
        Test-PutapinSession $script:projectDir | Should -BeFalse
    }
    It 'is false when the folder has no jsonl' {
        New-Item -ItemType Directory -Force -Path $script:keyDir | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:keyDir 'notes.txt') | Out-Null
        Test-PutapinSession $script:projectDir | Should -BeFalse
    }
    It 'falls back to ~/.claude when CLAUDE_CONFIG_DIR is unset' {
        $env:CLAUDE_CONFIG_DIR = $null
        $fakeHome = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $dir = Join-Path (Join-Path (Join-Path $fakeHome '.claude') 'projects') (ConvertTo-PutapinProjectKey $script:projectDir)
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir 's.jsonl') | Out-Null
        Mock Get-PutapinHome { $fakeHome }
        Test-PutapinSession $script:projectDir | Should -BeTrue
    }
}

Describe 'Read-PutapinLine' {
    AfterEach {
        [Console]::SetIn([IO.StreamReader]::new([Console]::OpenStandardInput()))
    }

    It 'shows the prompt on the host (not the pipeline) and returns the typed line' {
        [Console]::SetIn([IO.StringReader]::new("y`n"))
        $info = $null
        $result = Read-PutapinLine -InformationVariable info
        $result | Should -BeExactly 'y'
        ($info | Out-String) | Should -Match ([regex]::Escape('Resume prior session? (Y/n) '))
    }
    It 'returns $null on EOF' {
        [Console]::SetIn([IO.StringReader]::new(''))
        Read-PutapinLine 6>$null | Should -BeNullOrEmpty
        $null -eq (Read-PutapinLine 6>$null) | Should -BeTrue
    }
}

Describe 'Read-PutapinAnswer' {
    BeforeEach {
        $script:answers = [System.Collections.Queue]::new()
        Mock Read-PutapinLine { $script:answers.Dequeue() }
    }

    It 'treats <answer> as <expected>' -ForEach @(
        @{ answer = '';      expected = 'yes' }
        @{ answer = 'y';     expected = 'yes' }
        @{ answer = 'Y';     expected = 'yes' }
        @{ answer = 'yes';   expected = 'yes' }
        @{ answer = 'YeS';   expected = 'yes' }
        @{ answer = 'n';     expected = 'no' }
        @{ answer = 'N';     expected = 'no' }
        @{ answer = 'No';    expected = 'no' }
        @{ answer = "  y `t"; expected = 'yes' }
        @{ answer = ' n  ';  expected = 'no' }
        @{ answer = '   ';   expected = 'yes' }
    ) {
        $script:answers.Enqueue($answer)
        Read-PutapinAnswer | Should -BeExactly $expected
    }
    It 're-prompts on garbage until a valid answer' {
        'maybe', 'yess', 'n' | ForEach-Object { $script:answers.Enqueue($_) }
        Read-PutapinAnswer | Should -BeExactly 'no'
        Should -Invoke Read-PutapinLine -Times 3 -Exactly
    }
    It 'aborts on EOF' {
        $script:answers.Enqueue($null)
        Read-PutapinAnswer | Should -BeExactly 'abort'
    }
    It 'aborts on EOF after garbage' {
        'x', $null | ForEach-Object { $script:answers.Enqueue($_) }
        Read-PutapinAnswer | Should -BeExactly 'abort'
        Should -Invoke Read-PutapinLine -Times 2 -Exactly
    }
}

Describe 'Test-PutapinInteractive' {
    It 'is false when output is redirected (as under Pester/CI)' {
        # Pester's host is not an interactive console; the true branch is in the manual checklist.
        if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
            Set-ItResult -Skipped -Because 'running in a real console'
        }
        Test-PutapinInteractive | Should -BeFalse
    }
}

Describe 'Get-PutapinRealClaude' {
    BeforeAll {
        $script:savedPath = $env:PATH
        $script:binDir = Join-Path $TestDrive 'bin'
        New-Item -ItemType Directory -Force -Path $script:binDir | Out-Null
        Set-Content -LiteralPath (Join-Path $script:binDir 'claude.ps1') -Value '"STUB"'
        $env:PATH = $script:binDir + [IO.Path]::PathSeparator + $env:PATH
    }
    AfterAll {
        $env:PATH = $script:savedPath
    }

    It 'finds the claude executable or script on PATH, not the wrapper function' {
        $cmd = Get-PutapinRealClaude
        $cmd.CommandType | Should -Not -Be 'Function'
        $cmd.Source | Should -BeExactly (Join-Path $script:binDir 'claude.ps1')
    }
}

Describe 'claude wrapper' {
    BeforeAll {
        $script:stub = Join-Path $TestDrive 'claude.ps1'
        Set-Content -LiteralPath $script:stub -Value @'
if ($env:PUTAPIN_STUB_ARGV) { 'ARGV:' + (($args | ForEach-Object { "[$_]" }) -join '') }
else { "ARGS:$($args -join ' ')" }
exit $(if ($env:PUTAPIN_STUB_EXIT) { [int]$env:PUTAPIN_STUB_EXIT } else { 0 })
'@
    }
    BeforeEach {
        Mock Get-PutapinRealClaude { Get-Command $script:stub }
        Mock Test-PutapinInteractive { $true }
        Mock Test-PutapinSession { $true }
        Mock Read-PutapinAnswer { 'yes' }
        $env:PUTAPIN_STUB_EXIT = $null
        $env:PUTAPIN_STUB_ARGV = $null
        $env:PUTAPIN_FLAGS = $null
    }
    AfterAll {
        $env:PUTAPIN_STUB_ARGV = $null
        $env:PUTAPIN_FLAGS = $null
    }

    It 'passes arguments straight through without prompting' {
        claude -p 'hello world' | Should -BeExactly 'ARGS:-p hello world'
        Should -Invoke Read-PutapinAnswer -Times 0 -Exactly
    }
    It 'runs plain claude without prompting when not interactive' {
        Mock Test-PutapinInteractive { $false }
        claude | Should -BeExactly 'ARGS:'
        Should -Invoke Read-PutapinAnswer -Times 0 -Exactly
    }
    It 'runs plain claude without prompting when there is no prior session' {
        Mock Test-PutapinSession { $false }
        claude | Should -BeExactly 'ARGS:'
        Should -Invoke Read-PutapinAnswer -Times 0 -Exactly
    }
    It 'resumes with --continue on yes' {
        claude | Should -BeExactly 'ARGS:--continue'
        Should -Invoke Read-PutapinAnswer -Times 1 -Exactly
    }
    It 'starts fresh on no' {
        Mock Read-PutapinAnswer { 'no' }
        claude | Should -BeExactly 'ARGS:'
    }
    It 'launches nothing on abort and sets exit code 130' {
        Mock Read-PutapinAnswer { 'abort' }
        claude | Should -BeNullOrEmpty
        $LASTEXITCODE | Should -Be 130
    }
    It 'propagates the real exit code' {
        $env:PUTAPIN_STUB_EXIT = '7'
        claude | Out-Null
        $LASTEXITCODE | Should -Be 7
    }
    It 'checks for sessions using the current filesystem path' {
        Push-Location $TestDrive
        try {
            claude | Out-Null
            $expected = (Get-Location -PSProvider FileSystem).ProviderPath
            Should -Invoke Test-PutapinSession -Times 1 -Exactly -ParameterFilter { $Path -eq $expected }
        } finally {
            Pop-Location
        }
    }
    It 'prepends PUTAPIN_FLAGS when resuming' {
        $env:PUTAPIN_FLAGS = '--x'
        claude | Should -BeExactly 'ARGS:--x --continue'
    }
    It 'prepends PUTAPIN_FLAGS when starting fresh' {
        $env:PUTAPIN_FLAGS = '--x'
        Mock Read-PutapinAnswer { 'no' }
        claude | Should -BeExactly 'ARGS:--x'
    }
    It 'prepends PUTAPIN_FLAGS when passing arguments through' {
        $env:PUTAPIN_FLAGS = '--x'
        claude -p hi | Should -BeExactly 'ARGS:--x -p hi'
    }
    It 'prepends PUTAPIN_FLAGS when not interactive' {
        $env:PUTAPIN_FLAGS = '--x'
        Mock Test-PutapinInteractive { $false }
        claude | Should -BeExactly 'ARGS:--x'
    }
    It 'splits PUTAPIN_FLAGS like command arguments, respecting quotes' {
        $env:PUTAPIN_STUB_ARGV = '1'
        $env:PUTAPIN_FLAGS = "--model opus --append-system-prompt 'be brief' --dangerously-skip-permissions"
        claude | Should -BeExactly 'ARGV:[--model][opus][--append-system-prompt][be brief][--dangerously-skip-permissions][--continue]'
    }
    It 'falls back to whitespace splitting when PUTAPIN_FLAGS does not parse' {
        $env:PUTAPIN_STUB_ARGV = '1'
        $env:PUTAPIN_FLAGS = "--x 'unclosed"
        claude | Should -BeExactly "ARGV:[--x]['unclosed][--continue]"
    }
    It 'adds nothing for an empty or blank PUTAPIN_FLAGS' {
        $env:PUTAPIN_STUB_ARGV = '1'
        $env:PUTAPIN_FLAGS = '   '
        claude -p hi | Should -BeExactly 'ARGV:[-p][hi]'
    }
    It 'writes a putapin error when the real claude is missing' {
        Mock Get-PutapinRealClaude { $null }
        # Pester runs tests with ErrorActionPreference=Stop; a real session uses Continue,
        # where Write-Error is non-terminating. claude is a simple function (so -p etc.
        # pass through) and has no -ErrorAction, so set the preference and capture 2>&1.
        $ErrorActionPreference = 'Continue'
        (claude 2>&1 | Out-String) | Should -Match 'putapin'
    }
}

Describe 'guard: never clobber an existing alias or function' {
    # Each case runs in a fresh child process so definitions don't leak between tests.
    BeforeAll {
        $script:exe = (Get-Process -Id $PID).Path
        function Invoke-Child([string]$Code) {
            $full = "`$ErrorActionPreference = 'Continue'; $Code"
            & $script:exe -NoProfile -NonInteractive -Command $full 2>&1 3>&1 | Out-String
        }
    }

    It 'leaves an existing alias alone, with a warning' {
        $out = Invoke-Child "function Get-Other { 'ALIASED' }; Set-Alias claude Get-Other; . '$script:ModPath'; 'SOURCED-OK'; claude"
        $out | Should -Match ([regex]::Escape("putapin: 'claude' is already an alias; not installing the resume prompt."))
        $out | Should -Match 'SOURCED-OK'
        $out.TrimEnd() | Should -Match 'ALIASED$'
    }
    It 'leaves an existing function alone, with a warning' {
        $out = Invoke-Child "function claude { 'OTHER-WRAPPER' }; . '$script:ModPath'; 'SOURCED-OK'; claude"
        $out | Should -Match ([regex]::Escape("putapin: 'claude' is already a function; not installing the resume prompt."))
        $out.TrimEnd() | Should -Match 'OTHER-WRAPPER$'
    }
    It 'keeps a wrapper defined after putapin when re-sourced' {
        $out = Invoke-Child ". '$script:ModPath'; function claude { 'OTHER-WRAPPER' }; . '$script:ModPath'; claude"
        $out | Should -Match "putapin: 'claude' is already a function"
        $out.TrimEnd() | Should -Match 'OTHER-WRAPPER$'
    }
    It 're-sourcing putapin is silent and keeps the wrapper' {
        $out = Invoke-Child ". '$script:ModPath'; . '$script:ModPath'; (Get-Command claude).ScriptBlock.ToString() -match 'Read-PutapinAnswer'"
        $out | Should -Not -Match 'putapin:'
        $out.Trim() | Should -BeExactly 'True'
    }
}
