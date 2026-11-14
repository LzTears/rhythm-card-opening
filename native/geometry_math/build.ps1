param([Parameter(Mandatory=$true)][string]$Zig)
$ErrorActionPreference = 'Stop'
$nativeRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$compiler = [IO.Path]::GetFullPath($Zig)
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw "Zig executable not found: $compiler" }
$version = (& $compiler version).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne '0.14.1') { throw 'This reproducible build requires official Zig 0.14.1.' }
$headers = [IO.Path]::GetFullPath((Join-Path $nativeRoot '../feedback_math'))
$output = Join-Path $nativeRoot 'bin/roundcard_geometry.windows.x86_64.dll'
New-Item -ItemType Directory -Path (Join-Path $nativeRoot 'bin') -Force | Out-Null
& $compiler cc -std=c11 -O3 -fno-fast-math -ffp-contract=off -shared -target x86_64-windows-gnu -I $headers (Join-Path $nativeRoot 'geometry_math.c') -o $output
if ($LASTEXITCODE -ne 0) { throw "Native build failed: $LASTEXITCODE" }
Get-FileHash -LiteralPath $output -Algorithm SHA256
