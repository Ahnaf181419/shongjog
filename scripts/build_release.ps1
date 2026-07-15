# Build the release APK, optionally injecting GEMINI_API_KEY from .env (or env var).
#
# Usage:
#   .\scripts\build_release.ps1                              # reads .env if present
#   $env:GEMINI_API_KEY="xxx"; .\scripts\build_release.ps1   # override via env
#
# The demo-submission APK SHOULD be built WITHOUT a key (offline-purity + no
# billable credential in a public artifact). See CONTRIBUTING.md <-"Build with key">.
#
# Never commit the real .env - it is already in .gitignore.

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$EnvFile  = Join-Path $RepoRoot ".env"
$Placeholder = "YOUR_GOOGLE_AI_STUDIO_KEY_HERE"

# 1. Start from whatever the caller exported (env wins over file).
$Key = [System.Environment]::GetEnvironmentVariable("GEMINI_API_KEY")

# 2. If nothing in env, try .env (parse line by line).
if ([string]::IsNullOrEmpty($Key) -and (Test-Path $EnvFile)) {
  Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
      $parts  = $line -split "=", 2
      $name   = $parts[0].Trim()
      $value  = $parts[1].Trim()
      if ($name -eq "GEMINI_API_KEY") { $Key = $value }
    }
  }
}

# 3. Decide.
if ([string]::IsNullOrEmpty($Key) -or $Key -eq $Placeholder) {
  Write-Host "==> GEMINI_API_KEY not set. Building OFFLINE (cloud fallback disabled)."
  Write-Host "==> This is the correct path for the demo-submission APK."
  flutter build apk --release
} else {
  Write-Host "==> GEMINI_API_KEY detected. Building with cloud AI fallback enabled."
  Write-Host "==> WARNING: the key will be embedded in the APK. Do not ship this build"
  Write-Host "==> publicly. For the demo, rebuild without .env (or with the placeholder)."
  flutter build apk --release --dart-define=GEMINI_API_KEY=$Key
}
