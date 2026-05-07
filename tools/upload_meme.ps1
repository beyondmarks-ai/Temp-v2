param(
  [string]$Id,

  [Parameter(Mandatory = $true)]
  [string]$Title,

  [Parameter(Mandatory = $true)]
  [string]$StickerPath,

  [Parameter(Mandatory = $true)]
  [string]$AudioPath,

  [string]$ProjectId = "temptations-2a6c0",
  [string]$Bucket = "temptations-2a6c0.firebasestorage.app",
  [switch]$WriteFirestore
)

$ErrorActionPreference = "Stop"

function Resolve-RequiredPath([string]$PathValue, [string]$Label) {
  $resolved = Resolve-Path -LiteralPath $PathValue -ErrorAction SilentlyContinue
  if (-not $resolved) {
    throw "$Label not found: $PathValue"
  }

  return $resolved.Path
}

function ConvertTo-Slug([string]$Value) {
  $slug = $Value.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
  $slug = $slug.Trim("-")
  if ([string]::IsNullOrWhiteSpace($slug)) {
    return "meme"
  }

  return $slug
}

function ConvertTo-FirebaseStorageUrl([string]$BucketName, [string]$ObjectName, [string]$Token) {
  $encoded = [System.Uri]::EscapeDataString($ObjectName)
  return "https://firebasestorage.googleapis.com/v0/b/$BucketName/o/$encoded`?alt=media&token=$Token"
}

$removeBgKey = $env:REMOVE_BG_API_KEY
if ([string]::IsNullOrWhiteSpace($removeBgKey)) {
  throw "Set REMOVE_BG_API_KEY first. Example: `$env:REMOVE_BG_API_KEY='your_remove_bg_key'"
}

$sticker = Resolve-RequiredPath $StickerPath "Sticker"
$audio = Resolve-RequiredPath $AudioPath "Audio"
$slug = if ([string]::IsNullOrWhiteSpace($Id)) { ConvertTo-Slug $Title } else { ConvertTo-Slug $Id }
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$id = if ([string]::IsNullOrWhiteSpace($Id)) { "$slug-$timestamp" } else { $slug }

$outDir = Join-Path (Get-Location) "admin_uploads\memes\$id"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$transparentSticker = Join-Path $outDir "$id.png"
$firestoreDoc = Join-Path $outDir "$id.firestore.json"

Write-Host "Removing sticker background with remove.bg..."
& curl.exe `
  -s `
  -f `
  -H "X-Api-Key: $removeBgKey" `
  -F "image_file=@$sticker" `
  -F "size=auto" `
  -F "format=png" `
  -o "$transparentSticker" `
  "https://api.remove.bg/v1.0/removebg"

if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $transparentSticker)) {
  Write-Warning "remove.bg failed for $Title. Falling back to original sticker."
  Copy-Item -LiteralPath $sticker -Destination $transparentSticker -Force
}

$stickerObject = "memes/$id/sticker.png"
$audioExtension = [System.IO.Path]::GetExtension($audio)
if ([string]::IsNullOrWhiteSpace($audioExtension)) {
  $audioExtension = ".mp3"
}
$audioObject = "memes/$id/audio$audioExtension"

$stickerToken = [guid]::NewGuid().ToString()
$audioToken = [guid]::NewGuid().ToString()

Write-Host "Uploading sticker to Firebase Storage..."
& gcloud storage cp "$transparentSticker" "gs://$Bucket/$stickerObject" --project "$ProjectId" --content-type "image/png"
if ($LASTEXITCODE -ne 0) {
  throw "Sticker upload failed."
}

Write-Host "Uploading audio to Firebase Storage..."
& gcloud storage cp "$audio" "gs://$Bucket/$audioObject" --project "$ProjectId"
if ($LASTEXITCODE -ne 0) {
  throw "Audio upload failed."
}

Write-Host "Adding Firebase download tokens..."
& gcloud storage objects update "gs://$Bucket/$stickerObject" --project "$ProjectId" --update-custom-metadata "firebaseStorageDownloadTokens=$stickerToken"
if ($LASTEXITCODE -ne 0) {
  throw "Could not add sticker download token."
}

& gcloud storage objects update "gs://$Bucket/$audioObject" --project "$ProjectId" --update-custom-metadata "firebaseStorageDownloadTokens=$audioToken"
if ($LASTEXITCODE -ne 0) {
  throw "Could not add audio download token."
}

$stickerUrl = ConvertTo-FirebaseStorageUrl $Bucket $stickerObject $stickerToken
$audioUrl = ConvertTo-FirebaseStorageUrl $Bucket $audioObject $audioToken

$doc = [ordered]@{
  title = $Title
  stickerUrl = $stickerUrl
  audioUrl = $audioUrl
  enabled = $true
}

$doc | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $firestoreDoc -Encoding UTF8

if ($WriteFirestore) {
  Write-Host "Writing Firestore document memes/$id..."
  $token = (& gcloud auth print-access-token).Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
    throw "Could not get gcloud access token."
  }

  $firestoreBody = @{
    fields = @{
      title = @{ stringValue = $Title }
      stickerUrl = @{ stringValue = $stickerUrl }
      audioUrl = @{ stringValue = $audioUrl }
      enabled = @{ booleanValue = $true }
    }
  } | ConvertTo-Json -Depth 8
  $firestoreBodyPath = Join-Path $outDir "$id.firestore.rest.json"
  $firestoreBody | Set-Content -LiteralPath $firestoreBodyPath -Encoding UTF8

  $docUrl = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents/memes/$id"
  & curl.exe `
    -s `
    -f `
    -X PATCH `
    -H "Authorization: Bearer $token" `
    -H "Content-Type: application/json" `
    --data-binary "@$firestoreBodyPath" `
    "$docUrl" | Out-Null

  if ($LASTEXITCODE -ne 0) {
    throw "Firestore write failed for memes/$id."
  }
}

Write-Host ""
Write-Host "Done. Create Firestore document:"
Write-Host "Collection: memes"
Write-Host "Document ID: $id"
Write-Host "JSON: $firestoreDoc"
Write-Host ""
Get-Content -LiteralPath $firestoreDoc
