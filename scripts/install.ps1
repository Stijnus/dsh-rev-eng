# Install the dsh-rev-eng skill pack into a dsh skill root (drop-in install,
# no bundle needed). Windows PowerShell 5.1+ or PowerShell 7+.
#
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -Project <dir>
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -UserAgents
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -List
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -Uninstall
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -Uninstall -Project <dir>
#
# Targets (choose one):
#   (default)        $env:DSH_HOME\skills (~\.dsh\skills), rank 400, dsh user root
#   -Project <dir>   <dir>\.dsh\skills, rank 100, this project only
#   -UserAgents      $env:DSH_AGENTS_HOME\skills (~\.agents\skills), rank 500, shared agent root
#
# dsh watches its skill roots, so a new session picks the skills up
# automatically.

[CmdletBinding()]
param(
  [string]$Project,
  [switch]$UserAgents,
  [switch]$List,
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

if ($PSScriptRoot) {
  $packRoot = Split-Path -Parent $PSScriptRoot
} else {
  $packRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
$skillsDir = Join-Path $packRoot 'skills'

if (-not (Test-Path -LiteralPath $skillsDir -PathType Container)) {
  throw "skills directory not found: $skillsDir"
}

$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
$agentsHome = if ($env:DSH_AGENTS_HOME) {
  $env:DSH_AGENTS_HOME
} elseif ($env:AGENTS_HOME) {
  $env:AGENTS_HOME
} else {
  Join-Path $HOME '.agents'
}

if ($Project -and $UserAgents) {
  throw "choose one target: -Project <dir> or -UserAgents"
}

$targetKind = 'default'
$target = Join-Path $dshHome 'skills'
if ($UserAgents) {
  $target = Join-Path $agentsHome 'skills'
  $targetKind = '-UserAgents'
} elseif ($Project) {
  if (-not (Test-Path -LiteralPath $Project -PathType Container)) {
    throw "project directory not found: $Project"
  }
  $projectRoot = (Resolve-Path -LiteralPath $Project).ProviderPath
  $target = Join-Path (Join-Path $projectRoot '.dsh') 'skills'
  $targetKind = '-Project'
}

# The shipped skills: directories at the pack's skills root that carry a
# SKILL.md, sorted for stable output.
$skillNames = @(
  Get-ChildItem -LiteralPath $skillsDir -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf } |
    Sort-Object -Property Name
)

if ($skillNames.Count -eq 0) {
  throw "no skills found under $skillsDir"
}

if ($List) {
  Write-Host "dsh-rev-eng: $($skillNames.Count) shipped skill(s)"
  Write-Host ""
  foreach ($skill in $skillNames) {
    Write-Host "  $($skill.Name)"
  }
  Write-Host ""
  Write-Host "target roots (dsh skill discovery rank):"
  Write-Host "  default        $(Join-Path $dshHome 'skills')  [rank 400]"
  Write-Host "  -Project       <dir>\.dsh\skills  [rank 100]"
  Write-Host "  -UserAgents    $(Join-Path $agentsHome 'skills')  [rank 500]"
  Write-Host ""
  Write-Host "install with: powershell -ExecutionPolicy Bypass -File scripts\install.ps1 [-Project <dir> | -UserAgents]"
  exit 0
}

# Refuse the filesystem root as a target, for install and uninstall alike.
$resolvedTarget = [System.IO.Path]::GetFullPath($target)
if ($resolvedTarget -eq [System.IO.Path]::GetPathRoot($resolvedTarget)) {
  throw "refusing to operate on the filesystem root: $resolvedTarget"
}

if ($Uninstall) {
  if (-not (Test-Path -LiteralPath $target -PathType Container)) {
    Write-Host "nothing to uninstall: $target does not exist"
    exit 0
  }
  Write-Host "uninstalling this pack's skills from $target ($targetKind)"
  Write-Host ""
  $removed = 0
  foreach ($skill in $skillNames) {
    $dst = Join-Path $target $skill.Name
    if (Test-Path -LiteralPath $dst -PathType Container) {
      Remove-Item -LiteralPath $dst -Recurse -Force
      Write-Host "removed   $($skill.Name)"
      $removed++
    }
  }
  Write-Host ""
  if ($removed -eq 0) {
    Write-Host "nothing to uninstall: none of this pack's skills are in $target"
  } else {
    Write-Host "uninstalled $removed skill(s) from $target"
  }
  Write-Host "left every other entry in that directory untouched"
  Write-Host "start a new dsh session to see the skills disappear"
  exit 0
}

Write-Host "installing $($skillNames.Count) skill(s) into $target ($targetKind)"
Write-Host ""
New-Item -ItemType Directory -Force -Path $target | Out-Null

$installed = 0
foreach ($skill in $skillNames) {
  $dst = Join-Path $target $skill.Name
  if (Test-Path -LiteralPath $dst) {
    Remove-Item -LiteralPath $dst -Recurse -Force
  }
  Copy-Item -LiteralPath $skill.FullName -Destination $dst -Recurse -Force
  Write-Host "installed $($skill.Name)"
  $installed++
}

Write-Host ""
Write-Host "done: $installed skill(s) -> $target"
Write-Host ""
Write-Host "next steps:"
Write-Host "  1. Start a new dsh session. dsh watches its skill roots, so the skills are available without a restart."
Write-Host "  2. Type /rev-eng for this pack's router, or /bama for the Mac-app pipeline."
Write-Host "  3. REA's MCP tools are optional. From a terminal:"
Write-Host "       npx -y rea-agents@6.8.0 setup --client dsh --skill=false --dry-run --json"
Write-Host "     Review the plan, then rerun with --yes and restart dsh. Do not enable this"
Write-Host "     and patches/rea-mcp.yml at the same time: two rows with serverName rea conflict."
