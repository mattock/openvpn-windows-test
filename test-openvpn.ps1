Param (
    [string]$Openvpn,
    [string]$Gui,
    [string]$Config,
    [string]$Ping,
    [switch]$TestCmdexe,
    [switch]$TestService,
    [switch]$TestGui,
    [switch]$Help
)

Function Show-Usage {
    Write-Host "Usage: Test-Openvpn.ps1 -Config <openvpn-config-file> -Ping <host> [-Openvpn <openvpn-exe>] [-Gui <openvpn-gui-exe>] [-TestCmdexe] [-TestService] [-TestGui] [-Help]"
    Write-Host
    Write-Host "Parameters:"
    Write-Host "   -Openvpn     Path to openvpn.exe (defaults to C:\Program Files\OpenVPN\bin\openvpn.exe)"
    Write-Host "   -Gui         Path to openvpn-gui.exe (defaults to C:\Program Files\OpenVPN\bin\openvpn-gui.exe)"
    Write-Host "   -Config      Path to the OpenVPN configuration file"
    Write-Host "   -Ping        Target host inside VPN to ping (should succeed)"
    Write-Host "   -Suspend     Test suspend and resume [UNIMPLEMENTED]"
    Write-Host "   -TestCmdexe  Test connection from the command-line"
    Write-Host "   -TestGui     Test OpenVPN-GUI"
    Write-Host "   -TestService Test openvpnserv2.exe"
    Write-Host "   -Help        Display this help"
    Write-Host
    Write-Host "Example: .\Test-Openvpn.ps1 -Config ""C:\Program Files\OpenVPN\config\company.ovpn"" -Ping 192.168.40.7 -TestCmdexe -TestService -TestGui"
}

Function Verify-Path ([string]$mypath) {
    if (! (Test-Path $mypath -PathType leaf) ) {
        Write-Host "ERROR: ${mypath} not found or not a file!"
        Exit 1
    }
}

if (! $Openvpn) {
    $Openvpn = "C:\Program Files\OpenVPN\bin\openvpn.exe"
}

if (! $Gui) {
    $Gui = "C:\Program Files\OpenVPN\bin\openvpn-gui.exe"
}

if (! ($Config -and $Ping) -or $Help) {
    Show-Usage
    Exit 1
}

# Absolute directory from which this script is launched
$cwd = (Get-Item -Path ".\" -Verbose).FullName

# Separate OpenVPN configuration file path from the file name. This allows us
# to use relative certificate/key paths in OpenVPN configuration files.
$Configname = $Config.Split("\")[-1]
if ($Config -match '\\') {
    $Configdir = $Config -replace $Configname, '' -Replace '\\$'
} else {
    $Configdir = '.'
}


Verify-Path $Openvpn
Verify-Path $Gui
Verify-Path $Config

Function Stop-Generic ([string]$processname) {
    $processes = (Get-Process|Where-Object { $_.ProcessName -eq "${processname}" })
    foreach ($process in $processes) {
        Stop-Process $process.Id
    }
}

Function Stop-Openvpn {
    Stop-Generic "openvpn"
}

Function Stop-Gui {
    Stop-Generic "openvpn-gui"
}

Function Stop-Openvpnservice {
    Stop-Service OpenVPNService
    Stop-Service OpenVPNServiceLegacy
}

# Stop all openvpn-related processes
Function Clean-Up {
    # Kill all instances of (stock) OpenVPN
    Stop-Openvpnservice
    Stop-Openvpn
    Stop-Gui
}

Function Check-Connectivity ([string]$test_type) {

    Start-Sleep -Seconds 10

    $connected = (Test-Connection -Computername $Ping -Count 10 -Delay 1 -Quiet)

    if ($connected) {
        $result = "SUCCESS"
    } else {
        $result = "FAILURE"
    }

    Write-Host "${Configname} ${test_type} test: ${result}"
}

Function Test-Cmdexe {

    # Create a .bat file dynamically for launching the OpenVPN connection in a
    # separate cmd.exe windows. This approach was chosen as getting all the
    # whitespace in openvpn.exe command-line quoted properly so that cmd.exe /c
    # works properly was simply too nasty to deal with. Cmd.exe is used instead of
    # Powershell as it allows sending signals (e.g. F4=EXIT) to the OpenVPN process. 

    $bat = "${Configname}.bat"
    $pidfile = "${cwd}\${Configname}.pid"
    Set-Content -Path "${bat}" -Value """${Openvpn}"" --config ""${config}"" --writepid ""${pidfile}"" --cd ""${Configdir}"" & exit"
    Start-Process -FilePath $env:ComSpec -ArgumentList "/c", "start", "${bat}"
    Check-Connectivity "cmdexe"
    Stop-Openvpn
    Remove-Item "${pidfile}"
    Remove-Item "${bat}"
}

Function Test-Gui {
    & $gui --connect "${configname}"
    Check-Connectivity "gui"
    Stop-Openvpn
    Stop-Gui

}

Function Test-Service {
    $moved = @()
    $configs = (Get-ChildItem "${configdir}" -Filter "*.ovpn")
    foreach ($config in $configs) {
        $current = $config.Name
        if  ( ! ($current -eq $configname) ) {
            Move-Item "${configdir}\${current}" "${cwd}\${current}"
            if ($?) {
                $moved += ("${cwd}\${current}")
            }
        }
    }

    Start-Service OpenVPNService
    Check-Connectivity "openvpnserv2"
    # Test if openvpn.exe is respawned correctly on forced kill
    Stop-OpenVPN
    Check-connectivity "openvpnserv2-respawn"
    Stop-Service OpenVPNService

    foreach ($move in $moved) {
        Move-Item "${move}" "${configdir}\"
    }
}

Clean-Up

if ($TestCmdExe) { Test-Cmdexe }
if ($TestGui) { Test-Gui }
if ($TestService) { Test-Service }