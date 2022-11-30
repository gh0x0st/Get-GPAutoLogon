Function Get-GPAutoLogon
{
<#
    .SYNOPSIS
        Scans the group policy config Registry.xml files for autologon credentials.

    .DESCRIPTION
        This function will identify the primary domain controller for the current 
        domain and use that information to form the path to the policies folder within
        the SYSVOL share and look for all instances of the Registry.xml file. For each XML file 
        that is found, it will use regex to parse the files for the DefaultUsername 
        and DefaultPassword settings and extract their configured value. Additionally we can
        instruction the function in include the path to the registry file, which includes the GUID
        of the corresponding policy item for reporting purposes.

    .PARAMETER  IncludeXmlPath
        This parameter will instruct the function to include the path to the 
        Registry.xml file for the given set of discovered credentials.

    .PARAMETER  OutFile
        This parameter will instruct the function to write the results 
        the given path as csv file.

    .EXAMPLE
        PS C:\> Get-GPAutoLogon

            >> Group Policy Auto Logon Credentials
            >> https://github.com/gh0x0st

        [*] Scanning \\dc.lab.com\SYSVOL\lab.com\Policies\
        [*] Parsing through 214 files

        Username                 Password                                                                                            
        --------                 --------                                                                                            
        generic01                Auto123
        generic02                Logons123                                                                                           
        generic03                Are123
        generic04                Dangerous123

    .EXAMPLE
        PS C:\> Get-GPAutoLogon -IncludeXmlPath -OutFile autologons.csv

            >> Group Policy Auto Logon Credentials
            >> https://github.com/gh0x0st

        [*] Scanning \\dc.lab.com\SYSVOL\lab.com\Policies\
        [*] Parsing through 4 files
        [*] Saving results to file autologons.csv

    .INPUTS
        System.Switch

    .OUTPUTS
        System.Object

    .NOTES
        Keep in mind that special characters, such as an ampersand (&), will be formatted
        as '&amp;' within these files, which I explicitly replace within the script.
#>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [Switch]$IncludeXmlPath,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String]$OutFile
    )
    Begin
    {
        Try
        {
            Write-Output ''
            Write-Output '     >> Group Policy Auto Logon Credentials'
            Write-Output '     >> https://github.com/gh0x0st'
            Write-Output ''
            
            # Grabbing the primary domain controller
            $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            $PDC = $Domain.PdcRoleOwner
            $SysvolPath = "\\$($PDC.Name)\SYSVOL\$($PDC.Domain)\Policies\"
        }
        Catch
        {
            Write-Output "[!]$(Get-Date -Format '[MM-dd-yyyy][HH:mm:ss]') - ScriptLine: $($_.InvocationInfo.ScriptLineNumber) | ExceptionType: $($_.Exception.GetType().FullName) | ExceptionMessage: $($_.Exception.Message)"
            Break
        }
    }
    Process
    {
        Try
        {
            Write-Host "[*] Scanning $SysvolPath"
            $XML = Get-ChildItem $SysvolPath -Recurse -Filter Registry.xml -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

            # Create runspace
            $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, 5)
            $RunspacePool.Open()

            # Create pipeline input and output objects for BeginInvoke()
            # We only use $JobOutput but include $JobInclude as it's required
            $JobInput = New-Object 'System.Management.Automation.PSDataCollection[PSObject]'
            $JobOutput = New-Object 'System.Management.Automation.PSDataCollection[PSObject]'

            # Create runspace instructions
            $ScriptBlock = {
                param (
                    [String]$Path = '',
                    [switch]$IncludeXmlPath
                )
                
                # Load the contents from the XML file
                $Content = [System.IO.File]::ReadAllLines($Path)
                                
                # Extract DefaultUsername value
                $Exists = ($Content | Select-String $([Regex]::new('^.*name="DefaultUsername" type="REG_SZ" value="(.*)"\/>')) -AllMatches)
                If ($Exists) {
                    $Username = $Exists.Matches.Groups[1].Value
                }
                
                # Extract DefaultPassword value
                $Exists = ($Content | Select-String $([Regex]::new('^.*name="DefaultPassword" type="REG_SZ" value="(.*)"\/>')) -AllMatches)
                If ($Exists) {
                    $Password = $Exists.Matches.Groups[1].Value -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>' -replace '&quot;','"' -replace '&apos;','''' 
                }

                # Output if either values are found
                If ($Username -or $Password) {
                    if ($IncludeXmlPath) {
                        [PSCUstomObject]@{'Username' = $Username; 'Password' = $Password; 'XML' = $Path}
                    } Else {
                        [PSCUstomObject]@{'Username' = $Username; 'Password' = $Password}
                    }
                }
            }

            # Execute jobs through the runspace pool
            Write-Host "[*] Parsing through $($XML.Count) registry.xml files"
            $Jobs = (0..$XML.Count) | ForEach-Object {
                $Params = @{ Path = $XML[$_]; IncludeXmlPath = $IncludeXmlPath}
                $PowerShell = [powershell]::Create().AddScript($ScriptBlock).AddParameters($Params)
                $PowerShell.RunspacePool = $RunspacePool
                [PSCustomObject]@{
                    Instance = $PowerShell
                    State = $PowerShell.BeginInvoke($JobInput,$JobOutput)
                }
            }
            
            # Wait for each runspace instance to finish running before exiting
            while ( $Jobs.State.IsCompleted -contains $False) { 
                Start-Sleep -Milliseconds 10 
            }
        }
        Catch
        {
            Write-Output "[!]$(Get-Date -Format '[MM-dd-yyyy][HH:mm:ss]') - ScriptLine: $($_.InvocationInfo.ScriptLineNumber) | ExceptionType: $($_.Exception.GetType().FullName) | ExceptionMessage: $($_.Exception.Message)"
            Break
        }
        Finally
        {
            [GC]::Collect()
        }
    }
    End
    {
        Try
        {
            If (!$OutFile) {
                Write-Output $JobOutput
            } Else {
                Write-Host "[*] Saving results to file $OutFile"
                Write-Output $JobOutput | Export-CSV $OutFile
            }
        }
        Catch
        {
            Write-Output "[!]$(Get-Date -Format '[MM-dd-yyyy][HH:mm:ss]') - ScriptLine: $($_.InvocationInfo.ScriptLineNumber) | ExceptionType: $($_.Exception.GetType().FullName) | ExceptionMessage: $($_.Exception.Message)"
            Break
        }
    }
}
