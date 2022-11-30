# Get-GPAutoLogon

One feature of Windows that never seems to go away is the ability to configure automatic logons. What this feature will do is upon a reboot of the system, it will automatically log onto the account you designate. While this adds a level of convenience, it also introduces significant risks that could result in sophisticated attack chains against your environment should it be discovered and exploited by an adversary.

One of the repercussions from configuring this feature is that the credentials will be stored as plain text within the [registry](https://learn.microsoft.com/en-us/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon) on the machine that it's configured for and is accessible by the `Authenticated Users` group. In addition to the registry, if you were to deploy these configurations through Group Policy, then all those credentials will be available within the SYSVOL share on your domain controllers, which will also be in stored as plaintext and accessible.

Whether you're a penetration tester or a defender, Get-GPAutoLogon is a simple script that can be used to determine whether or not an environment is exposing credentials due to the automatic logon configurations set through Group Policy.

## Requirements

This script has been tested on PowerShell versions 7.3.0 and 5.1.14393.5127.

## Comment-Based Help

```powershell
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
        [*] Parsing through 214 files
        [*] Saving results to file autologons.csv

    .INPUTS
        System.Switch

    .OUTPUTS
        System.Object

    .NOTES
        Keep in mind that special characters, such as an ampersand (&), will be formatted
        as '&amp;' within these files, which I explicitly replace within the script.
#>
```
