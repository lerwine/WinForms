Function Get-NormalizedBlankLines {
    [OutputType([string[]])]
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [string[]]$Content
    )

    if ($Content.Length -eq 0) { return $Content }

    $prevLineLength = 0;

    $result = [string[]]($Content | ForEach-Object {
        $l = $_.TrimEnd();
        if ($l.Length -gt 0 -or $prevLineLength -gt 0) { $l }
        $prevLineLength = $l.Length;
    });

    if ($result.Length -eq 0 -or $prevLineLength -gt 0) { return $result }

    if ($result.Length -eq 1) { return @() }

    return [string[]]($result[0..($result.Length - 2)]);
}

Function Get-IndentedLines {
    [OutputType([string[]])]
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [string[]]$Content = @( ),
        
        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [string[]]$BeforeContent = (New-Object string[] -ArgumentList:0),
        
        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [string[]]$AfterContent = (New-Object string[] -ArgumentList:0)
    )

    $result = $BeforeContent;
    if ($Content.Length -gt 0) {
        foreach ($s in $Content) {
            $result = $result + ("`t$s").TrimEnd();
        }
    }

    if ($AfterContent.Length -gt 0) {
        foreach ($s in $AfterContent) {
            $result = $result + $s;
        }
    }

    return [string[]]$result;
}

function Get-DynamicParametersFunctionLines {
    Param(
        [Parameter(Mandatory=$true)]
        [Type]$Type
    )

    $properties = @{ };

    foreach ($p in Get-ViableProperties -Type:$Type) {
        if (-not $properties.ContainsKey($p.Name)) {
            $properties.Add($p.Name, $p);
        }
    }

    $lines = @();

    $baseType = Get-ViableBase -Type:$Type;

    if ($baseType -ne $null) {
        $lines = $lines + '$result = ' + "Get-$($baseType.Name)DynamicParameters " + '-Parameters:$Parameters';
    } else {
        $lines = $lines + '$result = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute];'
    }

    foreach ($k in $properties.Keys) {
        $lines = $lines + '';
        $lines = $lines + ("`t" + 'if ($Properties.ContainsKey(' + "'$k')) {");
        $lines = $lines + ("`t`t" + 'Add-RuntimeDefinedParameter -Dictionary:$result -Name:' + "'$k''Text' -ParameterType:[$($properties[$k].PropertyType.FullName)];");
        $lines = $lines + ("`t}");
    }

    return @(
        "function Get-$($Type.Name)DynamicParameters {",
        "`t<#",
        "`t`t.SYNOPSIS",
        "`t`t`tDescribe the function here",
        "`t`t.DESCRIPTION",
        "`t`t`tDescribe the function in more detail",
        "`t`t.EXAMPLE",
        "`t`t`tGive an example of how to use it",
        "`t`t.EXAMPLE",
        "`t`t`tGive another example of how to use it",
        "`t`t.PARAMETER computername",
        "`t`t`tThe computer name to query. Just one.",
        "`t`t.PARAMETER logname",
        "`t`t`tThe name of a file to write failed computer names to. Defaults to errors.txt.",
        "`t#>",
        '',
        "`tParam(",
        "`t`t[Parameter(Mandatory=$true)]",
        "`t`t[hashtable]$Properties",
        "`t)",
        '',
        $lines,
        '',
        ("`t" + 'return $result;'),
        '}'
    );
}

function Add-RuntimeDefinedParameter {
    [CmdletBinding(DefaultParameterSetName="NotSwitch")]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ $_ -is 'System.Management.Automation.RuntimeDefinedParameterDictionary' })]
        [object]$Dictionary,

        [Parameter(Mandatory=$true)]
        [ValidateScript({ $_.Length -gt 0 -and $_.Trim().Length -eq $_.Length })]
        [string]$Name,
        
        [Parameter(Mandatory=$true, ParameterSetName="NotSwitch")]
        [System.Type]$ParameterType,
        
        [Parameter(Mandatory=$false, ParameterSetName="NotSwitch")]
        [object]$Value,
        
        [Parameter(Mandatory=$true, ParameterSetName="IsSwitch")]
        [switch]$SwitchParameter
    );
    
    $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute];
    
    $paramType = $null;
    
    if ($PsCmdlet.ParameterSetName -eq "NotSwitch") {
        $paramType = $ParameterType;
    } else {
        $paramType = [System.Type]::GetType('System.Management.Automation.SwitchParameter');
    }
        
    $parameter = New-Object System.Management.Automation.RuntimeDefinedParameter -ArgumentList $Name, $paramType, $attributeCollection;
    
    if ($PsCmdlet.ParameterSetName -eq "NotSwitch") {
        if ($PSBoundParameters.ContainsKey("IsNotSwitchParameter")) { $parameter.SwitchParameter = $false; }
        if ($PSBoundParameters.ContainsKey("Value")) { $parameter.Value = $Value; }
    } else {
        $parameter.SwitchParameter = $true;
    }
        
    $Dictionary.Add($parameter.Name, $parameter);
}

function Set-ControlTypeProperties {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.Windows.Forms.Control]$Control,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Parameters
    );
    
    if ($Parameters.ContainsKey("Text")) { $control.Text = $Parameters['Text'] }
    if ($Parameters.ContainsKey("Name")) { $control.Name = $Parameters['Name'] }
    if ($Parameters.ContainsKey("Dock")) { $control.Dock = $Parameters['Dock'] }
    if ($Parameters.ContainsKey("Size")) { $control.Size = $Parameters['Size'] }
    if ($Parameters.ContainsKey("Margin")) { $control.Margin = $Parameters['Margin'] }
    if ($Parameters.ContainsKey("Padding")) { $control.Padding = $Parameters['Padding'] }
    if ($Parameters.ContainsKey("TabIndex")) { $control.TabIndex = $Parameters['TabIndex'] }
    if ($Parameters.ContainsKey("Parent")) {
        $parent = $Parameters['Parent'];
        $parent.Controls.Add($Control);
        
        if ($parent.GetType().FullName -eq 'System.Windows.Forms.TableLayoutPanel') {
            if ($Parameters.ContainsKey("Row")) { $parent.SetRow($Control, $Parameters['Row']) }
            if ($Parameters.ContainsKey("Column")) { $parent.SetColumn($Control, $Parameters['Column']) }
            if ($Parameters.ContainsKey("RowSpan")) { $parent.SetRowSpan($Control, $Parameters['RowSpan']) }
            if ($Parameters.ContainsKey("ColSpan")) { $parent.SetColumnSpan($Control, $Parameters['ColSpan']) }
        }
    }
}

function New-ControlType {
    <#
        .SYNOPSIS
            Describe the function here
        .DESCRIPTION
            Describe the function in more detail
        .EXAMPLE
            Give an example of how to use it
        .EXAMPLE
            Give another example of how to use it
        .PARAMETER computername
            The computer name to query. Just one.
        .PARAMETER logname
            The name of a file to write failed computer names to. Defaults to errors.txt.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [boolean]$AutoSize = $false,
        
        [Parameter(Mandatory=$false)]
        [System.Windows.Forms.AutoSizeMode]$AutoSizeMode,
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [ValidateScript({ $_ -gt 0 })]
        [int]$RowCount,
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [ValidateScript({ $_ -gt 0 })]
        [int]$ColumnCount
    )
    
    DynamicParam {
        return Get-DefaultDynamicParameters -ExistingParameters:$PSBoundParameters
    }
    
    Process {
        $result = New-Object System.Windows.Forms.TableLayoutPanel;

        $result.AutoSize = $autoSize;
        
        if ($autoSizeMode -ne $null) { $result.AutoSizeMode = $autoSizeMode }
        if ($rowCount -gt 0) { $result.RowCount = $rowCount }
        if ($columnCount -gt 0) { $result.ColumnCount = $columnCount }
        
        Apply-CommonControlSettings -Control:$result -Parameters:$PSBoundParameters;
        
        return $result;
    }
}

function Get-ViableProperties {
    [OutputType([System.Reflection.PropertyInfo[]])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [Type]$Type
    )
    
    return [System.Reflection.PropertyInfo[]]@($Type.GetProperties() | Where-Object { $_.CanRead -and $_.GetSetMethod() -ne $null -and $_.DeclaringType.Equals($Type) });
}

Function Get-BaseTypes {
    [OutputType([Type[]])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Type[]]$Type
    )

    $result = @( );

    foreach ($item in $Type) {
        $t = $item;
    
        while ((-not $t.Equals([System.Windows.Forms.Control]) -and (-not $t.Equals([Object])))) {
            $t = $t.BaseType;
            $properties = Get-ViableProperties -Type:$t;
            $baseProperties = Get-ViableProperties -Type:$t.BaseType;

            if ($properties.Length -gt 0) { $result = $result + $t }
        }
    }

    return $result;
}

Function Copy-HashTable {
    [OutputType([HashTable])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable]$SourceTable,

        [Parameter(Mandatory=$false)]
        [string[]]$OmitKeys = @( )
    )

    $result = @{ };
 
    foreach ($key in $SourceTable.Keys) {
        if (-not $OmitKeys.Contains($key)) { $result.Add($key, $SourceTable[$key]) }
    }

    return $result;
}

Function Get-BaseTypeMapping {
    [OutputType([HashTable])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [Type[]]$Types
    )

    $result = @{ };
 
    foreach ($controlType in $Types) {
        $baseTypes = $controlType | Get-BaseTypes;

        if ($baseTypes.Length -eq 0) { continue; }

        foreach ($t in $baseTypes) {
            if ($result.ContainsKey($t.FullName)) {
                if (-not $result[$t.FullName].Contains($controlType)) {
                    $result[$t.FullName] = $result[$t.FullName] + $controlType;
                }
            } else {
                $result.Add($t.FullName, @($t, $controlType));
            }

            $btn = Get-BaseTypeMapping -Types:$baseTypes;

            foreach ($key in $btn.Keys) {
                foreach ($bct in $btn[$key]) {
                    if ($result.ContainsKey($key)) {
                        if (-not $result[$key].Contains($bct)) {
                            $result[$key] = $result[$key] + $bct;
                        }
                    } else {
                        $result.Add($key, @($bct));
                    }
                }
            }
        }
    }

    return $result;
}

Function Get-ParamDefinition {
    [OutputType([string[]])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [System.Reflection.PropertyInfo[]]$Properties
    )

    $result = @();

    for ($i = 0; $i -lt $Properties.Length; $i++) {
        if ($i -gt 0) { $result = $result + '' }
        $result = $result + '[Parameter(Mandatory=$false)]';
        $s = "[$($Properties[$i].PropertyType.FullName)]" + '$' + $Properties[$i].Name;
        if ($i -lt ($Properties.Length - 1)) { $result = $result + ($s + ',') } else { $result = $result + $s }
    }
    
    if ($result.Length -gt 0) {
        return [string[]](Get-IndentedLines -Content:$result -BeforeContent:'Param(' -AfterContent:')');
    }

    return @('Param()');
}

Function Get-FunctionCodeLines {
    [OutputType([string[]])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [Type]$OutputType,

        [Parameter(Mandatory=$false)]
        [AllowEmptyCollection()]
        [HashTable]$MandatoryParams,

        [Parameter(Mandatory=$false)]
        [AllowEmptyCollection()]
        [HashTable]$OptionalParams,
        
        [Parameter(Mandatory=$false)]
        [AllowEmptyCollection()]
        [string[]]$DynParamLines,
        
        [Parameter(Mandatory=$false)]
        [AllowEmptyCollection()]
        [string[]]$ProcessLines
    )

    Process {
        $result = @("Function $Name {", "`t[CmdletBinding()]");

        if ($PSBoundParameters.ContainsKey("OutputType")) { $result = $result + "[OutputType([$($OutputType.FullName)])]" }

        if (($PSBoundParameters.ContainsKey("MandatoryParams") -and $PSBoundParameters["MandatoryParams"].Length -gt 0) -or `
            ($PSBoundParameters.ContainsKey("OptionalParams") -and $PSBoundParameters["OptionalParams"].Length -gt 0)) {
            $result = $result + "`tParam(";
            $paramLines = @();
            if ($PSBoundParameters.ContainsKey("MandatoryParams") -and $PSBoundParameters["MandatoryParams"].Length -gt 0) {
                foreach ($paramName in $PSBoundParameters["MandatoryParams"].Keys) {
                    $paramType = $PSBoundParameters["MandatoryParams"][$paramName];
                    if ($paramType -is [Type]) {
                        $paramType = $paramType.FullName;
                    } elseif ($paramType -isnot [string]) {
                        $paramType = $paramType.ToString();
                    }

                    if ($paramLines.Length -gt 0) { $paramLines = $paramLines + '' }
                    $paramLines = $paramLines + '[Parameter(Mandatory=$true)]';
                    $paramLines = $paramLines + ("[$paramType]" + '$' + $paramName);
                }
                
            }
            if ($PSBoundParameters.ContainsKey("OptionalParams") -and $PSBoundParameters["OptionalParams"].Length -gt 0) {
                foreach ($paramName in $PSBoundParameters["OptionalParams"].Keys) {
                    if ($PSBoundParameters.ContainsKey("MandatoryParams") -and $PSBoundParameters["MandatoryParams"].ContainsKey($paramName)) { continue }

                    $paramType = $PSBoundParameters["OptionalParams"][$paramName];
                    if ($paramType -is [Type]) {
                        $paramType = $paramType.FullName;
                    } elseif ($paramType -isnot [string]) {
                        $paramType = $paramType.ToString();
                    }

                    if ($paramLines.Length -gt 0) { $paramLines = $paramLines + '' }
                    $paramLines = $paramLines + '[Parameter(Mandatory=$false)]';
                    $paramLines = $paramLines + ("[$paramType]" + '$' + $paramName);
                }
                
            }

            for ($i = 1; $i -lt $paramLines.Length - 3; $i = $i + 3) {
                $paramLines[$i] = $paramLines[$i] + ',';
            }

            $result = $result + (Get-IndentedLines -Content:(Get-IndentedLines -Content:$paramLines));

            $result = $result + "`t)";
        } else {
            $result = $result + "`tParam()";
        }
    
        if ($PSBoundParameters.ContainsKey("DynParamLines") -and $PSBoundParameters["DynParamLines"].Length -gt 0) {
            $result = $result + "";
            $result = $result + "`tDynamicParam {";
            $result = $result + (Get-IndentedLines -Content:(Get-IndentedLines -Content:$PSBoundParameters["DynParamLines"]));
            $result = $result + "`t}";
            if ($PSBoundParameters.ContainsKey("ProcessLines") -and $PSBoundParameters["ProcessLines"].Length -gt 0) {
                $result = $result + "";
                $result = $result + "`tProcess {";
                $result = $result + (Get-IndentedLines -Content:(Get-IndentedLines -Content:$PSBoundParameters["ProcessLines"]));
                $result = $result + "`t}";
            }
        } elseif ($PSBoundParameters.ContainsKey("ProcessLines") -and $PSBoundParameters["ProcessLines"].Length -gt 0) {
            $result = $result + "";
            $result = $result + (Get-IndentedLines -Content:$PSBoundParameters["ProcessLines"]);
        }

        $result = $result + "}";

        return [string[]]$result;
    }
}

cls;

$controlTypes = @(
    [Type]'System.Windows.Forms.Form',
    [Type]'System.Windows.Forms.Label'
);

$codeLines = @();

$typeMapping = Get-BaseTypeMapping -Types:$controlTypes;

foreach ($ct in $controlTypes) {
    if (-not $typeMapping.ContainsKey($ct.FullName)) {
        $typeMapping.Add($ct.FullName, @($ct));
    }
}

$typeNamesToRender = @();
do {
    $typeNamesToRender = $typeMapping.Keys | Where-Object {
        $key = $_;
        $type = $typeMapping[$key][0];
        ($typeMapping.Keys | Where-Object { $_ -ine $key -and $typeMapping[$_].Contains($type) }).Count -eq 0;
    };

    foreach ($typeName in $typeNamesToRender) {
        $type = $typeMapping[$typeName][0];
        $baseTypes = $type | Get-BaseTypes;
        $properties = Get-ViableProperties -Type:$type;
        $baseProperties = @( );
        if ($baseTypes.Length -gt 0) { $baseProperties = $baseTypes[0].GetProperties() };

        $optionalParams = @{ };

        foreach ($p in $properties) {
            $optionalParams.Add($p.Name, $p.PropertyType);
        }

        if ($typeMapping[$typeName].Length -gt 1) {
            $processLines = @();

            if ($baseTypes.Length -gt 0) {
                $processLines = $processLines + ("Get-$($baseTypes[0].Name)DynamicParameters" + ' -Properties:$Properties');
            }

            $codeLines = $codeLines + (Get-FunctionCodeLines -Name:"Get-$($type.Name)DynamicParameters" `
                -MandatoryParams:@{ Properties = 'HashTable' } -ProcessLines:$processLines);

            $codeLines = $codeLines + "";

            $processLines = @();
            foreach ($p in $properties) {
                $processLines = $processLines + ('if ($PSBoundParameters.ContainsKey("' + $p.Name + '")) { $Control.' + $p.Name + ' = $' + $p.Name + ' }');
            }

            if ($baseTypes.Length -gt 0) {
                if ($baseProperties.Length -gt 0) {
                    foreach ($bp in $baseProperties) {
                        if (($properties | Where-Object { $_.Name -eq $bp.Name }).Count -gt 0) {
                            $processLines = $processLines + ('if ($PSBoundParameters.ContainsKey("' + $bp.Name + '")) { $PSBoundParameters.Remove("' + $bp.Name + '") }');
                        }
                    }
                }

                $processLines = $processLines + "Set-$($baseTypes[0].Name)Properties";
            }

            $codeLines = $codeLines + (Get-FunctionCodeLines -Name:"Set-$($type.Name)Properties" `
                -MandatoryParams:@{ Control = $type } -OptionalParams:$optionalParams `
                -ProcessLines:$processLines);
            $codeLines = $codeLines + "";
        }

        if ($controlTypes.Contains($type)) {
            $dynamicParamLines = @();
            $processLines = @(('$result = New-Object ' + $type.FullName + ';'), '');
            if ($typeMapping[$typeName].Length -gt 1) {
                $processLines = $processLines + '$PSBoundParameters.Add("Control", $result);';
                $processLines = $processLines + "Set-$($type.Name)Properties @PSBoundParameters;";
                $optionalParams = @{ };
            } else {
                foreach ($p in $properties) {
                    $processLines = $processLines + ('if ($PSBoundParameters.ContainsKey("' + $p.Name + '")) { $result.' + $p.Name + ' = $' + $p.Name + ' }');
                }

                if ($baseTypes.Length -gt 0) {
                    $dynamicParamLines = $dynamicParamLines + ("return Get-$($baseTypes[0].Name)DynamicParameters" + ' -Properties:$PSBoundParameters');
                    $processLines = $processLines + '';
                    if ($baseProperties.Length -gt 0) {
                        foreach ($bp in $baseProperties) {
                            if (($properties | Where-Object { $_.Name -eq $bp.Name }).Count -gt 0) {
                                $processLines = $processLines + ('if ($PSBoundParameters.ContainsKey("' + $bp.Name + '")) { $PSBoundParameters.Remove("' + $bp.Name + '") }');
                            }
                        }
                    }
                    $processLines = $processLines + '$PSBoundParameters.Add("Control", $result);';
                    $processLines = $processLines + "Set-$($baseTypes[0].Name)Properties @PSBoundParameters;";
                    if ($properties.Length -gt 0) { $processLines = $processLines + '' };
                }
            }
            
            $processLines = $processLines + 'return $result;';

            $codeLines = $codeLines + (Get-FunctionCodeLines -Name:"New-$($type.Name)" -OutputType:$type -OptionalParams:$optionalParams `
                -ProcessLines:$processLines -DynParamLines:$dynamicParamLines);
            $codeLines = $codeLines + "";
        }

        $typeMapping.Remove($typeName);
    }
} while ($typeNamesToRender.Count -gt 0);

$codeLines;