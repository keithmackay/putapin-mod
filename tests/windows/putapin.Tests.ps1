BeforeAll {
    . (Join-Path $PSScriptRoot (Join-Path '..' (Join-Path '..' (Join-Path 'windows' 'putapin.ps1'))))
}

Describe 'harness' {
    It 'dot-sources cleanly' {
        $true | Should -BeTrue
    }
}
