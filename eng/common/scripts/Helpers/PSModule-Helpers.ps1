$DefaultPSRepository =  "PSGallery"
$DefaultPSRepositoryUrl = "https://www.powershellgallery.com/api/v2"
$global:CurrentUserModulePath = ""

function Update-PSModulePath()
{
  # Information on PSModulePath taken from docs
  # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath

  # Information on Az custom module paths on hosted agents taken from
  # https://github.com/microsoft/azure-pipelines-tasks/blob/c9771bc064cd60f47587c68e5c871b7cd13f0f28/Tasks/AzurePowerShellV5/Utility.ps1

  if ($IsWindows) {
    $hostedAgentModulePath = $env:SystemDrive + "\Modules"
    $moduleSeperator = ";"
  } else {
    $hostedAgentModulePath = "/usr/share"
    $moduleSeperator = ":"
  }

  # Find the path that is under user home directory
  $homeDirectories = ($env:PSModulePath -split $moduleSeperator).Where({ $_.StartsWith($home) })
  if ($homeDirectories.Count -gt 0) {
    $global:CurrentUserModulePath = $homeDirectories[0]
    if ($homeDirectories.Count -gt 1) {
      Write-Verbose "Found more then one module path starting with $home so selecting the first one $global:CurrentUserModulePath"
    }
  }
  else {
    Write-Error "Did not find a module path starting with $home to set up a user module path in $env:PSModulePath"
  }

  # Add az_ module paths from hosted images
  $AzModulePath = (Get-ChildItem "$hostedAgentModulePath/az_*" -Attributes Directory) -join $moduleSeperator
  if ($AzModulePath -and $env.PSModulePath -notcontains $env:AzModulePath) {
    $env:PSModulePath = $AzModulePath + $moduleSeperator + $env:PSModulePath
  }
}

# If we want to use another default repository other then PSGallery we can update the default parameters
function Install-ModuleIfNotInstalled($moduleName, $version, $repositoryName = $DefaultPSRepository, $repositoryUrl = $DefaultPSRepositoryUrl)
{
  # Check installed modules
  $modules = (Get-Module -ListAvailable $moduleName).Where({ $_.Version -ge $version })

  if ($modules.Count -eq 0)
  {
    Unregister-PSRepository $repositoryName -ErrorAction "Ignore"

    # You need to use -Default option when registory powershell gallery.
    if ($repositoryUrl -eq "https://www.powershellgallery.com/api/v2")
    {
      Register-PSRepository -Default -InstallationPolicy Trusted
    }
    else
    {
      Register-PSRepository $repositoryName $repositoryUrl -InstallationPolicy Trusted
    }

    Write-Host "Installing module $moduleName with min version $version from $repositoryUrl"
    # Install under CurrentUser scope so that the end up under $CurrentUserModulePath for caching
    Install-Module $moduleName -MinimumVersion $version -Repository $repositoryName -Scope CurrentUser -Force

    # Ensure module installed
    $modules = (Get-Module -ListAvailable $moduleName).Where({ $_.Version -ge $version })
    if ($modules.Count -eq 0)
    {
      Write-Error "Failed to install module $moduleName with version $version"
      return
    }
  }
  return $modules
}

Update-PSModulePath