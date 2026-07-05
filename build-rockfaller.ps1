# Compile les sources Haxe de Rock Faller (rockfaller/src) en rockfaller/web/game.js via la toolchain embarquée.
# Usage : pwsh build-rockfaller.ps1
$ErrorActionPreference = "Stop"

$repo = $PSScriptRoot
$base = Join-Path $repo "tools\haxe4"
$neko = Join-Path $base "neko-2.4.0-win64"
$hdir = Join-Path $base "haxe-4.3.7-win"
$haxe = Join-Path $hdir "haxe.exe"

if (-not (Test-Path $haxe)) { Write-Error "Haxe introuvable : $haxe"; exit 1 }

$env:NEKOPATH     = $neko
$env:HAXELIB_PATH = Join-Path $base "haxelib_repo"
$env:PATH         = "$neko;$hdir;" + $env:PATH

Push-Location $repo
try {
  & $haxe "rockfaller\src\rockfaller.hxml"
  if ($LASTEXITCODE -ne 0) { Write-Error "Echec compilation Haxe (exit $LASTEXITCODE)"; exit 1 }
  $out = Join-Path $repo "rockfaller\web\game.js"
  $kb = [math]::Round((Get-Item $out).Length / 1024, 1)
  Write-Output "OK -> rockfaller/web/game.js ($kb Ko)"
} finally {
  Pop-Location
}
