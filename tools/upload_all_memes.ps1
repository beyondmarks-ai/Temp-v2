param(
  [string]$StickerFolder = "D:\Sticker",
  [string]$SoundFolder = "C:\Sounds",
  [string]$ProjectId = "temptations-2a6c0",
  [string]$Bucket = "temptations-2a6c0.firebasestorage.app",
  [switch]$WriteFirestore
)

$ErrorActionPreference = "Stop"

$stickers = Get-ChildItem -LiteralPath $StickerFolder -File -Filter *.png | Sort-Object BaseName
if ($stickers.Count -eq 0) {
  throw "No PNG stickers found in $StickerFolder"
}

$uploaded = 0
foreach ($sticker in $stickers) {
  $audio = Join-Path $SoundFolder "$($sticker.BaseName).mp3"
  if (-not (Test-Path -LiteralPath $audio)) {
    throw "Missing matching audio for $($sticker.Name): $audio"
  }

  $title = ($sticker.BaseName -replace "-", " ")
  $title = (Get-Culture).TextInfo.ToTitleCase($title)

  $existingDoc = Join-Path (Get-Location) "admin_uploads\memes\$($sticker.BaseName)\$($sticker.BaseName).firestore.json"
  if ($WriteFirestore -and (Test-Path -LiteralPath $existingDoc)) {
    Write-Host "Skipping $($sticker.BaseName), existing upload JSON found."
    continue
  }

  $uploadArgs = @{
    Id = $sticker.BaseName
    Title = $title
    StickerPath = $sticker.FullName
    AudioPath = $audio
    ProjectId = $ProjectId
    Bucket = $Bucket
  }

  if ($WriteFirestore) {
    $uploadArgs.WriteFirestore = $true
  }

  Write-Host ""
  Write-Host "Uploading $($sticker.BaseName)..."
  & "$PSScriptRoot\upload_meme.ps1" @uploadArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Upload failed for $($sticker.BaseName)"
  }
  $uploaded++
}

Write-Host ""
Write-Host "Uploaded $uploaded meme pair(s)."
