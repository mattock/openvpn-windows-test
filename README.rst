openvpn-windows-test
====================

Powershell scripts for testing OpenVPN on Windows. The test-openvpn.ps1 script can test OpenVPN
from the command-line (cmd.exe), using OpenVPN-GUI and with openvpnserv2.
Success and failure are based on simple ping tests.

A typical use-case for these scripts is smoke-testing an installer prior to a
major release.

Usage
=====

The main script tests only one VPN connection:
::
  Usage: Test-Openvpn.ps1 -Config <openvpn-config-file> -Ping <host> [-Openvpn <openvpn-exe>] [-Gui <openvpn-gui-exe>] [-TestCmdexe] [-TestService] [-TestGui] [-Help]
  
  Parameters:
     -Openvpn     Path to openvpn.exe (defaults to C:\Program Files\OpenVPN\bin\openvpn.exe)
     -Gui         Path to openvpn-gui.exe (defaults to C:\Program Files\OpenVPN\bin\openvpn-gui.exe)
     -Config      Path to the OpenVPN configuration file
     -Ping        Target host inside VPN to ping (should succeed)
     -Suspend     Test suspend and resume [UNIMPLEMENTED]
     -TestCmdexe  Test connection from the command-line
     -TestGui     Test OpenVPN-GUI
     -TestService Test openvpnserv2.exe
     -Help        Display this help
  
  Example: .\Test-Openvpn -Config "C:\Program Files\OpenVPN\config\company.ovpn" -Ping 192.168.40.7 -TestCmdexe -TestService -TestGui

To test several connections in a row create a wrapper such as this and name it
run.ps1:
::

  # run.ps1
  $configdir = "C:\Program Files\OpenVPN\config"
  
  .\Test-Openvpn.ps1 -TestCmdexe -TestGui -TestService -Config "${configdir}\company.ovpn" -Ping 10.5.18.8
  .\Test-Openvpn.ps1 -TestCmdexe -TestGui -TestService -Config "${configdir}\university.ovpn" -Ping 10.19.199.3
  .\Test-Openvpn.ps1 -TestCmdexe -TestGui -TestService -Config "${configdir}\home.ovpn" -Ping 192.168.7.2

Now you can verify that your particular version of OpenVPN works with all of
your VPN connections.

To verify that the connections do not succeed because of a bug or by accident,
-Ping to a fake IP that can only fail.

Warnings
========

The script brutally kills every openvpn.exe and openvpn-gui.exe it finds at
startup, as well as stops OpenVPNService. Similarly, when it is done with a
particular cmd.exe or openvpn-gui.exe test, it kills the processes without
signaling them.

The openvpnserv2 tests move irrelevant .ovpn files out of the way to the
current working directory before launching the service. After the test the
files are put back where they belong.

While this script seems to work fine, it can potentially cause issues. At minimum make sure
that your VPN configurations have been backed up. If Windows starts acting up, rebooting is
probably in order.