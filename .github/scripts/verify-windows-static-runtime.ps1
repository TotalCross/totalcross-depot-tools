# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$InputPath,
  [ValidateSet('Release')]
  [string]$Configuration = 'Release',
  [string]$JsonOutput
)

$ErrorActionPreference = 'Stop'
$temporaryDirectories = [System.Collections.Generic.List[string]]::new()

function Find-Dumpbin {
  $command = Get-Command dumpbin.exe -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }

  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (-not (Test-Path -LiteralPath $vswhere)) {
    throw 'dumpbin.exe was not found and Visual Studio vswhere.exe is unavailable.'
  }
  $installationPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (-not $installationPath) { throw 'vswhere.exe did not find a Visual Studio C++ installation.' }
  $candidate = Get-ChildItem -Path (Join-Path $installationPath 'VC\Tools\MSVC') -Directory |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'bin\Hostx64\x64\dumpbin.exe' } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
  if (-not $candidate) { throw 'Visual Studio is installed but dumpbin.exe was not found.' }
  return $candidate
}

function Add-LibrariesFromPath([string]$Path, [System.Collections.Generic.List[object]]$Libraries) {
  if (-not (Test-Path -LiteralPath $Path)) {
    $matches = @(Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue)
    if ($matches.Count -eq 0) { throw "Input '$Path' matched nothing." }
    foreach ($match in $matches) { Add-LibrariesFromPath $match.FullName $Libraries }
    return
  }
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    if ($Path -match '\.tar\.gz$') {
      $directory = Join-Path ([System.IO.Path]::GetTempPath()) ("totalcross-runtime-" + [guid]::NewGuid())
      New-Item -ItemType Directory -Path $directory | Out-Null
      $temporaryDirectories.Add($directory)
      & tar.exe -xzf $Path -C $directory
      if ($LASTEXITCODE -ne 0) { throw "Could not extract '$Path'." }
      $found = @(Get-ChildItem -Path $directory -Filter '*.lib' -File -Recurse)
      if ($found.Count -eq 0) { throw "Artifact '$Path' contains no .lib files." }
      foreach ($library in $found) { $Libraries.Add([pscustomobject]@{ Artifact = $Path; Library = $library.FullName }) }
      return
    }
    if ($Path -match '\.lib$') { $Libraries.Add([pscustomobject]@{ Artifact = $Path; Library = (Resolve-Path -LiteralPath $Path).Path }); return }
    throw "Input '$Path' is neither a .lib nor a .tar.gz artifact."
  }
  $found = @(Get-ChildItem -LiteralPath $Path -Filter '*.lib' -File -Recurse -ErrorAction SilentlyContinue)
  if ($found.Count -eq 0) { throw "Input '$Path' matched no .lib files." }
  foreach ($library in $found) { $Libraries.Add([pscustomobject]@{ Artifact = $Path; Library = $library.FullName }) }
}

try {
  $libraries = [System.Collections.Generic.List[object]]::new()
  foreach ($path in $InputPath) { Add-LibrariesFromPath $path $libraries }
  if ($libraries.Count -eq 0) { throw 'No .lib files were provided.' }
  $dumpbin = Find-Dumpbin
  $results = foreach ($item in $libraries) {
    $directives = (& $dumpbin /nologo /directives $item.Library 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "dumpbin failed for '$($item.Library)'." }
    $defaultLibraries = @([regex]::Matches($directives, '/DEFAULTLIB:(?:"([^"]+)"|([^\s\r\n]+))', 'IgnoreCase') | ForEach-Object {
      if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value }
    } | ForEach-Object { $_.Trim('"').ToUpperInvariant() } | Select-Object -Unique)
    $dynamic = @($defaultLibraries | Where-Object { $_ -in @('MSVCRT','MSVCRTD','VCRUNTIME','VCRUNTIMED','UCRT','UCRTD') })
    $debug = @($defaultLibraries | Where-Object { $_ -in @('LIBCMTD','LIBVCRUNTIMED','LIBUCRTD') })
    $reason = $null
    if ($dynamic.Count) { $reason = "dynamic runtime default library: $($dynamic -join ', ')" }
    elseif ($debug.Count) { $reason = "debug runtime default library: $($debug -join ', ')" }
    elseif ($defaultLibraries -notcontains 'LIBCMT') { $reason = 'missing static LIBCMT runtime evidence' }
    [pscustomobject]@{ artifactPath = $item.Artifact; libraryPath = $item.Library; defaultLibraries = $defaultLibraries; result = if ($reason) { 'fail' } else { 'pass' }; failureReason = $reason }
  }
  foreach ($result in $results) { Write-Host "[$($result.result)] $($result.libraryPath): $($result.defaultLibraries -join ', ')$($(if ($result.failureReason) { " ($($result.failureReason))" }))" }
  if ($JsonOutput) { $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $JsonOutput -Encoding utf8 }
  if (@($results | Where-Object result -eq 'fail').Count) { exit 1 }
}
finally {
  foreach ($directory in $temporaryDirectories) { Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue }
}
