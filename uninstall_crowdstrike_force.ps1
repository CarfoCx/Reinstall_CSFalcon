<#
.SYNOPSIS
    Uninstall and re-install the Falcon Sensor using RTR
#>
[CmdletBinding()]
param()
begin {
    <# USER CONFIG ###############################################################################>
    $AuditMessage = 'ReplaceFalcon Real-Time Response script'
    $Hostname = "https://api.crowdstrike.com"
    $Id = 'add_id_here'
    $Secret = 'add_secret_here'
    $InstallerPath = 'C:\Temp\WindowsSensor.exe'
    $InstallArgs = '/install /quiet /norestart CID=add_your_CID_here'
    <############################################################################### USER CONFIG #>


 
    function Invoke-Falcon ($Uri, $Method, $Headers, $Body) {
        $Request = [System.Net.WebRequest]::Create($Uri)
        $Request.Method = $Method
        switch ($Headers.GetEnumerator()) {
            { $_.Key -eq 'accept' } {
                $Request.Accept = $_.Value
            }
            { $_.Key -eq 'content-type' } {
                $Request.ContentType = $_.Value
            }
            default {
                $Request.Headers.Add($_.Key, $_.Value)
            }
        }
        $RequestStream = $Request.GetRequestStream()
        $StreamWriter = [System.IO.StreamWriter]($RequestStream)
        $StreamWriter.Write($Body)
        $StreamWriter.Flush()
        $StreamWriter.Close()
        $Invoke = try {
            $Response = $Request.GetResponse()
            $ResponseStream = $Response.GetResponseStream()
            $StreamReader = [System.IO.StreamReader]($ResponseStream)
            ConvertFrom-Json ($StreamReader.ReadToEnd())
        } catch {
            $_
        }
        return $Invoke
    }
    Add-Type -AssemblyName System.Net.Http
 
    # Registry paths for uninstall information
    $UninstallKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
 
    # HostId value from registry
    $HostId = ([System.BitConverter]::ToString(((Get-ItemProperty ("HKLM:\SYSTEM\CrowdStrike\" +
    "{9b03c1d9-3138-44ed-9fae-d9f4c034b88d}\{16e0423f-7058-48c9-a204-725362b67639}" +
    "\Default") -Name AG).AG)).ToLower() -replace '-','')
}
process {
    if ((-not $Id) -or (-not $Secret)) {
        throw "API credentials not configured in script"
    }
    if ((Test-Path $InstallerPath) -eq $false) {
        throw "Unable to locate WindowsSensor.exe"
    }
    if (-not $InstallArgs) {
        throw "No installation arguments configured in script"
    }
    if (-not $HostId) {
        throw "Unable to retrieve host identifier"
    }
    foreach ($Key in (Get-ChildItem $UninstallKeys)) {
        if ($Key.GetValue("DisplayName") -like "*CrowdStrike Windows Sensor*") {
            # Create uninstall string
            $Uninstall = "/c $($Key.GetValue("QuietUninstallString"))"
        }
    }
    if (-not $Uninstall) {
        throw "QuietUninstallString not found for CrowdStrike Windows Sensor"
    }
    $Param = @{
        Uri = "$($Hostname)/oauth2/token"
        Method = 'post'
        Headers = @{
            accept = 'application/json'
            'content-type' = 'application/x-www-form-urlencoded'
        }
        Body = "client_id=$Id&client_secret=$Secret"
    }
    $Token = Invoke-Falcon @Param
 
    if (-not $Token.access_token) {
        throw "Unable to request token"
    }
    $Param = @{
        Uri = "$($Hostname)/policy/combined/reveal-uninstall-token/v1"
        Method = 'post'
        Headers = @{
            accept = 'application/json'
            'content-type' = 'application/json'
            authorization = "$($Token.token_type) $($Token.access_token)"
        }
        Body = @{
            audit_message = $AuditMessage
            device_id = $HostId
        } | ConvertTo-Json
    }
    $Request = Invoke-Falcon @Param
 
    if (-not $Request.resources) {
        throw "Unable to retrieve uninstall token"
    }
    $Uninstall += " MAINTENANCE_TOKEN=$($Request.resources.uninstall_token)"
 
    Start-Process -FilePath cmd.exe -ArgumentList $Uninstall -PassThru | ForEach-Object {
        Write-Output "[$($_.Id)] '$($_.ProcessName)' beginning removal; sensor will become unresponsive..."
        $WaitInstall = ("-WindowStyle Hidden -Command &{ Wait-Process -Id $($_.Id); Start-Process -FilePath" +
        " $InstallerPath -ArgumentList '$InstallArgs' }")
        Start-Process -FilePath powershell.exe -ArgumentList $WaitInstall
    }
}
