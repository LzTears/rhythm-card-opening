param([string]$Zig = 'C:/Users/Administrator/.codex/tmp/roundcard-native-build/zig-x86_64-windows-0.14.1/zig.exe')
$ErrorActionPreference = 'Stop'
$moduleRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$compiler = [IO.Path]::GetFullPath($Zig)
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'Official Zig executable missing.' }
if ((& $compiler version).Trim() -ne '0.14.1') { throw 'This module requires official Zig 0.14.1.' }
$destination = Join-Path $moduleRoot 'bin/roundcard_safe_layout.windows.x86_64.dll'
New-Item -ItemType Directory -Path (Join-Path $moduleRoot 'bin') -Force | Out-Null
& $compiler cc -std=c11 -O3 -fno-fast-math -ffp-contract=off -shared -target x86_64-windows-gnu -I $moduleRoot (Join-Path $moduleRoot 'safe_layout.c') -o $destination
if ($LASTEXITCODE -ne 0) { throw "Safe-layout build failed: $LASTEXITCODE" }
Get-FileHash -LiteralPath $destination -Algorithm SHA256
