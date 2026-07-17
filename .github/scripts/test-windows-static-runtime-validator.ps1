# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("totalcross-runtime-fixture-" + [guid]::NewGuid())
$verifier = Join-Path $PSScriptRoot 'verify-windows-static-runtime.ps1'
New-Item -ItemType Directory -Path $root | Out-Null
try {
  Set-Content -LiteralPath (Join-Path $root 'fixture.c') -Value 'int totalcross_runtime_fixture(void) { return 42; }' -Encoding ascii
  foreach ($runtime in @('MT', 'MD', 'MTd')) {
    & cl.exe /nologo /c "/$runtime" (Join-Path $root 'fixture.c') "/Fo$(Join-Path $root "$runtime.obj")"
    if ($LASTEXITCODE -ne 0) { throw "cl.exe failed for /$runtime" }
    & lib.exe /nologo "/OUT:$(Join-Path $root "$runtime.lib")" (Join-Path $root "$runtime.obj")
    if ($LASTEXITCODE -ne 0) { throw "lib.exe failed for /$runtime" }
  }
  & cl.exe /nologo /c /MT /Zl (Join-Path $root 'fixture.c') "/Fo$(Join-Path $root 'no-directives.obj')"
  & lib.exe /nologo "/OUT:$(Join-Path $root 'no-directives.lib')" (Join-Path $root 'no-directives.obj')
  & $verifier (Join-Path $root 'MT.lib')
  if ($LASTEXITCODE -ne 0) { throw '/MT fixture was rejected.' }
  foreach ($fixture in @('MD.lib', 'MTd.lib', 'no-directives.lib')) {
    & $verifier (Join-Path $root $fixture)
    if ($LASTEXITCODE -eq 0) { throw "$fixture was unexpectedly accepted." }
  }
  & tar.exe -czf (Join-Path $root 'MT.tar.gz') -C $root MT.lib
  & $verifier (Join-Path $root 'MT.tar.gz')
  if ($LASTEXITCODE -ne 0) { throw 'Packaged /MT fixture was rejected.' }
}
finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
