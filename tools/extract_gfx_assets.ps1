<#
.SYNOPSIS
  Pulls the graphics assets out of game/Assets.zip.

.DESCRIPTION
  The port reads assets from plain files rather than opening Assets.zip itself,
  which is the same choice already made for the spell and status-effect tables:
  tools/extract_spell_data.ps1 and tools/extract_status_effects.ps1 generate
  OCaml from the archive, and nothing at run time depends on a zip reader.

  Assets.zip is 51MB and PHYSFS is the only thing in the game that reads it.
  Depending on a zip library just to pull one 292KB sheet out would add a
  dependency for no gain, so the sheet is extracted here instead.

  Re-run after replacing Assets.zip. Output is deterministic, so committing the
  result does not create noise.

.PARAMETER OutDir
  Where to write. Defaults to assets/gfx beside the repository root.
#>
[CmdletBinding()]
param(
  [string]$OutDir,
  [string]$Zip
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Resolved in the body rather than as parameter defaults: $PSScriptRoot is not
# yet set when a param default is evaluated, so a default built from it is empty.
$repo = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $repo "assets\gfx" }
if (-not $Zip) { $Zip = Join-Path $repo "game\Assets.zip" }

# Only what the battle screen needs to draw a board. Adding a sheet here means
# adding it to gfx/assets.ml too - the frame table there is written against
# Assets.xml, not against this list.
$wanted = @(
  "Assets/Skin/Skin_Gems_Grid.png",
  "Assets/Skin/Skin_Battle_Misc.png",
  "Assets/Skin/Skin_Backdrop_Battle.jpg"
)

if (-not (Test-Path -LiteralPath $Zip)) {
  Write-Error "Assets.zip not found at $Zip"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$archive = [System.IO.Compression.ZipFile]::OpenRead($Zip)
try {
  $entries = @{}
  foreach ($e in $archive.Entries) { $entries[$e.FullName] = $e }

  foreach ($name in $wanted) {
    if (-not $entries.ContainsKey($name)) {
      Write-Warning "not in archive, skipping: $name"
      continue
    }
    $dest = Join-Path $OutDir (Split-Path -Leaf $name)
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile(
      $entries[$name], $dest, $true)
    $len = (Get-Item -LiteralPath $dest).Length
    Write-Host ("extracted {0,-40} {1,9:N0} bytes" -f (Split-Path -Leaf $name), $len)
  }
}
finally {
  $archive.Dispose()
}

Write-Host "done -> $OutDir"