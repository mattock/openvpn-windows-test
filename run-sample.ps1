$configdir = "C:\Program Files\OpenVPN\config"
$basecmd = ".\Test-OpenVPN.ps1"
$tests = "-TestCmdexe -TestGui -TestService"

Function do_test([string]$configname, [string]$ping) {
    $cmdline = "`"${basecmd}`" ${tests} -Config `"${configdir}\${configname}`" -Ping ${ping}"
    Invoke-Expression "& $cmdline"

}

do_test "company.ovpn" "10.10.112.100"
do_test "university.ovpn" "10.8.21.9"
do_test "home.ovpn" "192.168.0.81"