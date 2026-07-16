param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("x86", "x64", "arm64")]
  [string]$Arch,

  [Parameter(Mandatory = $true)]
  [string]$OutputDir,

  [Parameter(Mandatory = $true)]
  [string]$RedistVersion,

  [Parameter(Mandatory = $true)]
  [string]$SourceUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

$dllAllowList = @(
  "vcruntime140.dll",
  "vcruntime140_1.dll",
  "msvcp140.dll",
  "concrt140.dll",
  "vccorlib140.dll",
  "vcamp140.dll",
  "vcomp140.dll"
)

$sourceDir = if ($Arch -eq "x86") {
  Join-Path $env:WINDIR "SysWOW64"
} else {
  Join-Path $env:WINDIR "System32"
}

if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
  throw "Runtime source directory was not found: $sourceDir"
}

$artifactRoot = Join-Path $OutputDir "artifact"
$payloadDir = Join-Path (Join-Path (Join-Path $artifactRoot "vcruntime") "windows") $Arch

Remove-Item -LiteralPath $artifactRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null

$copiedDlls = @()
foreach ($dllName in $dllAllowList) {
  $sourcePath = Join-Path $sourceDir $dllName
  if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
    Copy-Item -LiteralPath $sourcePath -Destination $payloadDir
    $copiedDlls += $dllName
  }
}

if ($copiedDlls -notcontains "vcruntime140.dll") {
  throw "Required vcruntime140.dll was not found under $sourceDir"
}

$noticePath = Join-Path $payloadDir "NOTICE.txt"
@"
This archive contains Microsoft Visual C++ Redistributable runtime DLLs
installed from the official Microsoft Visual C++ v14 Redistributable package.

Redistribution is permitted only under the applicable Microsoft Visual Studio
license terms. See:

https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files
https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist

Source package: $SourceUrl
Installed redistributable version: $RedistVersion
"@ | Set-Content -LiteralPath $noticePath -Encoding ASCII

$manifestPath = Join-Path $payloadDir "manifest.txt"
$manifestLines = @(
  "name=vcruntime",
  "platform=windows",
  "arch=$Arch",
  "redist_version=$RedistVersion",
  "source_url=$SourceUrl",
  "generated_at_utc=$((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))",
  "license_notice=NOTICE.txt"
)

foreach ($dllName in ($copiedDlls | Sort-Object)) {
  $dllPath = Join-Path $payloadDir $dllName
  $hash = (Get-FileHash -LiteralPath $dllPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifestLines += "dll=$dllName"
  $manifestLines += "sha256_$dllName=$hash"
}

$manifestLines | Set-Content -LiteralPath $manifestPath -Encoding ASCII

$archivePath = Join-Path $OutputDir "vcruntime-windows-$Arch.tar.gz"
Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue

Push-Location $artifactRoot
try {
  & tar -czf $archivePath "vcruntime"
  if ($LASTEXITCODE -ne 0) {
    throw "tar failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

Write-Host $archivePath
