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
#
# arm64-v8a ONLY (see AGENTS.md <-"Hard constraints">). The LiteRT-LM engine
# ships native libs for arm64 alone: a fat APK still installs on armeabi-v7a /
# x86_64 (e.g. an emulator) but has NO engine there, so the offline AI fails in
# a way that looks exactly like a bug. Use `flutter run` for emulator/UI work.

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

# Pre-build source verification (mirrors build_release.sh). Guards the two
# runtime failures the artifact checks below cannot see: a wrong model URL and
# a missing engine registration. Both shipped an APK that passed every
# structural check and still could not answer offline.
Write-Host "==> Verifying source before build..."
$preFailed = $false

$mainDart = Get-Content (Join-Path $RepoRoot "lib\main.dart") -Raw
if ($mainDart -match "LiteRtLmEngine\(\)") {
  Write-Host "  OK  LiteRtLmEngine registered in main.dart"
} else {
  Write-Host "  FAIL  main.dart does not register LiteRtLmEngine() — offline AI"
  Write-Host "        throws 'add the engine package' at runtime."
  $preFailed = $true
}

# Real Dart invariant: every downloadable variant uses a .litertlm URL, never
# the repo's -web.task (a WebAssembly build the Android engine cannot open).
& flutter test (Join-Path $RepoRoot "test\unit\device_capability_test.dart") 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
  Write-Host "  OK  Model catalog verified (.litertlm URLs, sizes, gated variants)"
} else {
  Write-Host "  FAIL  device_capability_test failed — a variant likely points at a"
  Write-Host "        .task URL or has a wrong size. Run the test to see which."
  $preFailed = $true
}

if ($preFailed) { Write-Error "==> Source is not demo-safe"; exit 1 }

# 3. Build (arm64-v8a only).
if ([string]::IsNullOrEmpty($Key) -or $Key -eq $Placeholder) {
  Write-Host "==> GEMINI_API_KEY not set. Building OFFLINE (cloud fallback disabled)."
  Write-Host "==> This is the correct path for the demo-submission APK."
  flutter build apk --release --target-platform android-arm64
} else {
  Write-Host "==> GEMINI_API_KEY detected. Building with cloud AI fallback enabled."
  Write-Host "==> WARNING: the key will be embedded in the APK. Do not ship this build"
  Write-Host "==> publicly. For the demo, rebuild without .env (or with the placeholder)."
  flutter build apk --release --target-platform android-arm64 --dart-define=GEMINI_API_KEY=$Key
}

# 4. Post-build verification. A green build does NOT mean the on-device model
#    works: both historical breakages were invisible to analyze/test/run and
#    only ever showed up in an installed release APK.
$Apk = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $Apk)) { Write-Error "APK not found at $Apk"; exit 1 }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($Apk)
try {
  $names = $zip.Entries | ForEach-Object { $_.FullName }
} finally {
  $zip.Dispose()
}

$failed = $false
if ($names | Where-Object { $_ -match 'lib/arm64-v8a/.*(litert|gemma)' }) {
  Write-Host "  OK  LiteRT-LM engine libs present (arm64-v8a)"
} else {
  Write-Host "  FAIL  NO LiteRT-LM engine libs — offline AI cannot run."
  $failed = $true
}
if ($names | Where-Object { $_ -match 'lib/(armeabi-v7a|x86|x86_64|mips)/' }) {
  Write-Host "  FAIL  Non-arm64 ABI present — installs without an AI engine."
  $failed = $true
} else {
  Write-Host "  OK  arm64-v8a only"
}

# R8 must not have deleted any Java class the engine reflects into. Dormant
# while MediaPipe is absent; real again if flutter_gemma_mediapipe is added.
$usageTxt = Join-Path $RepoRoot "build\app\outputs\mapping\release\usage.txt"
if (Test-Path $usageTxt) {
  $stripped = (Select-String -Path $usageTxt -Pattern '^com\.google\.(mediapipe|protobuf|odml)[^:]*$').Count
  if ($stripped -eq 0) {
    Write-Host "  OK  R8 stripped no MediaPipe/protobuf classes"
  } else {
    Write-Host "  FAIL  R8 deleted $stripped MediaPipe/protobuf classes — see"
    Write-Host "        android/app/proguard-rules.pro (-dontwarn does NOT keep them)."
    $failed = $true
  }
}

if ($failed) { Write-Error "==> BUILD IS NOT DEMO-SAFE"; exit 1 }
Write-Host ("==> OK: {0} ({1:N0} MB)" -f $Apk, ((Get-Item $Apk).Length / 1MB))
