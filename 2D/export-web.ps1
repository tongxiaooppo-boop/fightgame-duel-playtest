param([string] $Godot = 'godot')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root 'build/duel-web'
New-Item -ItemType Directory -Path $output -Force | Out-Null
& $Godot --headless --path $root --export-release '2D Web' (Join-Path $output 'index.html')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
foreach ($name in 'duel.webmanifest', 'duel-sw.js', 'duel-192.png', 'duel-512.png') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "pwa/$name") -Destination $output
}
Compress-Archive -Path (Join-Path $output '*') -DestinationPath (Join-Path $root 'build/duel-web.zip') -Force
