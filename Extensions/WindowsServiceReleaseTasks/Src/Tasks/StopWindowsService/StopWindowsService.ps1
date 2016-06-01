[CmdletBinding(DefaultParameterSetName = 'None')]
param(
    [string][Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] $serviceName,
    [string][Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] $environmentName,
    [string][Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] $adminUserName,
    [string][Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] $adminPassword,
	[string][Parameter(Mandatory=$true)][ValidateSet("Manual", "Automatic", "Disabled")] $startupType
)

Write-Output "Stopping Windows Service: $serviceName and setting startup type to: $startupType"

$machines = ($environmentName -split ',').Trim()

$securePassword = ConvertTo-SecureString -AsPlainText $adminPassword -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $adminUserName, $securePassword

$machines = $machines | %{ Invoke-Command -Credential $cred -ComputerName $_ -ScriptBlock { Get-Service }} | Where-Object { $_.Name -eq $serviceName } | % { $_.PSComputerName }

if ($machines.Length -eq 0)
{
    Write-Output "No servers have service installed. Exiting."
    return;
}

$guid = "a" + [guid]::NewGuid().ToString().Replace("-", "")

Configuration $guid
{ 
    Node $machines
    {
        Service ServiceResource
        {
            Name = $serviceName
            State = "Stopped"
            StartupType = $startupType
        }
    }
}
 
Invoke-Expression $guid

Start-DscConfiguration -Path $guid -Credential $cred -Wait -Verbose

Remove-Item -Path $guid -Recurse