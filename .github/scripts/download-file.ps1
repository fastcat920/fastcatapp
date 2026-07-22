param(
  [Parameter(Mandatory = $true)]
  [string]$Uri,

  [Parameter(Mandatory = $true)]
  [string]$OutFile,

  [int64]$MinimumBytes = 1MB,

  [int]$MaxAttempts = 5
)

$ErrorActionPreference = "Stop"
$destination = [IO.Path]::GetFullPath($OutFile)
$partial = "$destination.part"
$parent = Split-Path -Parent $destination
if ($parent) {
  New-Item -Force -ItemType Directory $parent | Out-Null
}

function Test-DownloadedFile([string]$Path) {
  if (-not (Test-Path $Path -PathType Leaf)) { return $false }
  $file = Get-Item $Path
  if ($file.Length -lt $MinimumBytes) {
    throw "Downloaded file is too small: $($file.Length) bytes"
  }
  return $true
}

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
  if (Test-Path $partial) {
    [IO.File]::Delete($partial)
  }

  try {
    Write-Host "Download attempt $attempt/$MaxAttempts: $Uri"
    if ($attempt -le 2) {
      Invoke-WebRequest -Uri $Uri -OutFile $partial -UseBasicParsing
    } else {
      & curl.exe --fail --location --silent --show-error `
        --connect-timeout 30 --max-time 600 `
        --retry 2 --retry-delay 2 --retry-all-errors `
        --output $partial $Uri
      if ($LASTEXITCODE -ne 0) {
        throw "curl.exe failed with exit code $LASTEXITCODE"
      }
    }

    if (Test-DownloadedFile $partial) {
      Move-Item $partial $destination -Force
      $size = (Get-Item $destination).Length
      Write-Host "Downloaded $destination ($size bytes)"
      return
    }
  } catch {
    Write-Warning "Download attempt $attempt failed: $($_.Exception.Message)"
    if ($attempt -eq $MaxAttempts) { break }
    Start-Sleep -Seconds ([Math]::Min(30, [Math]::Pow(2, $attempt)))
  }
}

if (Test-Path $partial) {
  [IO.File]::Delete($partial)
}
throw "Failed to download $Uri after $MaxAttempts attempts"
