$ErrorActionPreference = "Stop"

$SourceDir = "D:\work\POLYGON\faces"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$DestDir = Join-Path $RepoRoot "faces"

if (!(Test-Path $SourceDir)) { throw "Source folder not found: $SourceDir" }
if (!(Test-Path $DestDir)) { throw "Repo faces folder not found: $DestDir" }

function Has-Command($name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Optimize-Image($inPath, $outPath) {
  if (!(Has-Command "magick")) {
    Copy-Item -LiteralPath $inPath -Destination $outPath -Force
    return
  }

  $ext = ([IO.Path]::GetExtension($inPath)).ToLowerInvariant()

  if ($ext -eq ".png") {
    magick $inPath -strip -filter Lanczos -resize "900x900>" -define png:compression-level=9 $outPath | Out-Null
    return
  }

  if ($ext -eq ".jpg" -or $ext -eq ".jpeg") {
    magick $inPath -strip -filter Lanczos -resize "900x900>" -quality 82 -interlace Plane $outPath | Out-Null
    return
  }

  if ($ext -eq ".webp") {
    magick $inPath -strip -filter Lanczos -resize "900x900>" -quality 80 $outPath | Out-Null
    return
  }

  Copy-Item -LiteralPath $inPath -Destination $outPath -Force
}

$exts = @("*.jpg","*.jpeg","*.png","*.webp")
$srcFiles = foreach ($e in $exts) { Get-ChildItem -LiteralPath $SourceDir -Filter $e -File -ErrorAction SilentlyContinue }

foreach ($f in $srcFiles) {
  $destPath = Join-Path $DestDir $f.Name

  $copy = $true
  if (Test-Path $destPath) {
    $srcTime = (Get-Item -LiteralPath $f.FullName).LastWriteTimeUtc
    $dstTime = (Get-Item -LiteralPath $destPath).LastWriteTimeUtc
    if ($dstTime -ge $srcTime) { $copy = $false }
  }

  if ($copy) {
    Optimize-Image -inPath $f.FullName -outPath $destPath
  }
}

Push-Location $RepoRoot
try {
  if (!(Has-Command "git")) { throw "git not found in PATH" }

  git add faces | Out-Null
  $changes = git status --porcelain
  if ($changes) {
    $msg = "Sync faces (" + (Get-Date -Format "yyyy-MM-dd HH:mm") + ")"
    git commit -m $msg | Out-Null
    git push | Out-Null
    Write-Host "Synced + pushed new/updated faces."
  } else {
    Write-Host "No new/updated faces to push."
  }
} finally {
  Pop-Location
}

