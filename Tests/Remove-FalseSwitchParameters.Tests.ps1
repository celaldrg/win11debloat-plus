BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Remove-FalseSwitchParameters.ps1')

    # Returns the $PSBoundParameters that PowerShell builds for the given arguments, like the one
    # Win11Debloat.ps1 stores as $script:Params
    function Get-BoundParameterSet {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [switch]$FirstFeature,
            [switch]$SecondFeature,
            [string]$User,
            [string]$Apps
        )

        $PSBoundParameters
    }
}

Describe 'Remove-FalseSwitchParameters' {
    It 'removes a switch that was passed as -Name:$false' {
        $parameters = Get-BoundParameterSet -FirstFeature:$false
        $parameters.ContainsKey('FirstFeature') | Should -BeTrue

        Remove-FalseSwitchParameters $parameters

        $parameters.Count | Should -Be 0
    }

    It 'removes WhatIf, Confirm, Verbose and Debug passed as $false' {
        $parameters = Get-BoundParameterSet -WhatIf:$false -Confirm:$false -Verbose:$false -Debug:$false
        $parameters.Count | Should -Be 4

        Remove-FalseSwitchParameters $parameters

        $parameters.Count | Should -Be 0
    }

    It 'keeps present switches and every value that is not a switch' {
        $parameters = Get-BoundParameterSet -FirstFeature -SecondFeature:$false -User 'False' -Apps '' -WhatIf

        Remove-FalseSwitchParameters $parameters

        $parameters.Count | Should -Be 4
        $parameters.ContainsKey('SecondFeature') | Should -BeFalse
        $parameters['FirstFeature'].IsPresent | Should -BeTrue
        $parameters['WhatIf'].IsPresent | Should -BeTrue
        $parameters['User'] | Should -BeExactly 'False'
        $parameters.ContainsKey('Apps') | Should -BeTrue
        $parameters['Apps'] -is [string] | Should -BeTrue
    }

    It 'keeps false values that are not switches in a hashtable' {
        $parameters = @{ FalseSwitch = [switch]$false; TrueSwitch = [switch]$true; FalseBoolean = $false; Zero = 0 }

        Remove-FalseSwitchParameters $parameters

        $parameters.Count | Should -Be 3
        $parameters.ContainsKey('FalseSwitch') | Should -BeFalse
    }

    It 'updates $PSBoundParameters of the calling function and writes no output' {
        function Get-CleanedParameterNames {
            [CmdletBinding()]
            param([switch]$FirstFeature, [switch]$SecondFeature)

            $params = $PSBoundParameters
            $output = @(Remove-FalseSwitchParameters $params)
            [PSCustomObject]@{ Names = @($PSBoundParameters.Keys); OutputCount = $output.Count }
        }

        $result = Get-CleanedParameterNames -FirstFeature:$false -SecondFeature

        $result.OutputCount | Should -Be 0
        $result.Names | Should -HaveCount 1
        $result.Names[0] | Should -BeExactly 'SecondFeature'
    }

    It 'accepts an empty dictionary' {
        $parameters = Get-BoundParameterSet
        $parameters.Count | Should -Be 0

        { Remove-FalseSwitchParameters $parameters } | Should -Not -Throw
        $parameters.Count | Should -Be 0
    }
}

Describe 'Win11Debloat.ps1 false switch cleanup' {
    BeforeAll {
        $tokens = $null
        $parseErrors = $null
        $script:MainScriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '..\Win11Debloat.ps1'), [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
    }

    It 'dot-sources the helper' {
        $imports = @($script:MainScriptAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Dot -and
                $node.CommandElements[0].Extent.Text -ceq '"$PSScriptRoot/Scripts/Helpers/Remove-FalseSwitchParameters.ps1"'
        }, $true))

        $imports | Should -HaveCount 1
    }

    It 'cleans $script:Params right after it is created, before anything else uses it' {
        $statements = @($script:MainScriptAst.EndBlock.Statements)
        $assignmentIndex = -1
        $cleanupIndex = -1
        $firstUseIndex = -1
        for ($i = 0; $i -lt $statements.Count; $i++) {
            $text = $statements[$i].Extent.Text
            if ($assignmentIndex -lt 0) {
                if ($text -ceq '$script:Params = $PSBoundParameters') { $assignmentIndex = $i }
                continue
            }
            if ($cleanupIndex -lt 0 -and $text -ceq 'Remove-FalseSwitchParameters $script:Params') {
                $cleanupIndex = $i
                continue
            }
            if ($firstUseIndex -lt 0 -and $text.Contains('$script:Params')) { $firstUseIndex = $i }
        }

        $assignmentIndex | Should -BeGreaterOrEqual 0
        $cleanupIndex | Should -BeGreaterThan $assignmentIndex
        $firstUseIndex | Should -BeGreaterThan $cleanupIndex
    }
}
