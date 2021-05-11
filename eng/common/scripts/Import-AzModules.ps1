[CmdletBinding()]
param (
  [string]$AzModuleVersion = $null # null equates to latest
)

. (Join-Path $PSScriptRoot Helpers PSModule-Helpers.ps1)

Install-ModuleIfNotInstalled "Az" $AzModuleVersion | Import-Module