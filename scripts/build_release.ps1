# Build the shippable release APK.
#
# Usage:
#   .\scripts\build_release.ps1                                        # the one you want
#   $env:ALLOW_EMBEDDED_KEY="1"; .\scripts\build_release.ps1           # local dev only
#
# NO API KEY IS COMPILED IN BY DEFAULT, and .env is deliberately ignored.
# A --dart-define value ends up as a plaintext literal in libapp.so, so any
# public APK built with one has a public key. The app fetches its key at
# runtime from Firestore config/cloud_ai instead - out of the binary, and
# revocable without shipping a new build.
#
# ALLOW_EMBEDDED_KEY=1 restores the old behaviour for local cloud-AI work.
# That build is NOT publishable.
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

# The Firebase project every device must sync against. google-services.json is
# gitignored and downloaded per-developer, so two people can hold valid files
# for DIFFERENT projects — the build succeeds on both and the phones then talk
# to two separate backends, which looks exactly like "sync is broken". Pinning
# the id turns that into a build failure. Not a secret: it ships in the APK.
$FirebaseProjectId = "shongjog-007"

$AllowEmbeddedKey =
  [System.Environment]::GetEnvironmentVariable("ALLOW_EMBEDDED_KEY") -eq "1"

# Resolve a key ONLY when explicitly opted in. The default path never reads
# .env at all - leaving the file on disk must not silently produce an
# unpublishable APK.
$Key = $null
if ($AllowEmbeddedKey) {
  $Key = [System.Environment]::GetEnvironmentVariable("GEMINI_API_KEY")
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
$embeddedKey = $false
if ([string]::IsNullOrEmpty($Key) -or $Key -eq $Placeholder) {
  Write-Host "==> No key compiled in - this build is publishable."
  Write-Host "==> Cloud AI still works on device: the app fetches its key at first"
  Write-Host "==> launch from Firestore config/cloud_ai. On-device Gemma 4 needs"
  Write-Host "==> no key at all."
  flutter build apk --release --target-platform android-arm64
} else {
  $embeddedKey = $true
  Write-Host "==> ALLOW_EMBEDDED_KEY=1 - compiling GEMINI_API_KEY into the binary."
  Write-Host "==> *** DO NOT PUBLISH THIS APK. *** The key is recoverable from it"
  Write-Host "==> with a single grep. Re-run without ALLOW_EMBEDDED_KEY for a build"
  Write-Host "==> you can upload."
  flutter build apk --release --target-platform android-arm64 --dart-define=GEMINI_API_KEY=$Key
}

# 4. Post-build verification. A green build does NOT mean the on-device model
#    works: both historical breakages were invisible to analyze/test/run and
#    only ever showed up in an installed release APK.
$Apk = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $Apk)) { Write-Error "APK not found at $Apk"; exit 1 }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($Apk)

# Decode APK entries in memory — the Firebase/notification checks below look
# INSIDE resources.arsc, classes*.dex and the binary manifest, not just at the
# file listing. $encoding is 'ASCII' for the first two and 'Unicode' for the
# manifest, whose binary-XML string pool is UTF-16.
function Get-EntryText($zip, $pattern, $encoding) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($e in $zip.Entries) {
    if ($e.FullName -notlike $pattern) { continue }
    $s = $e.Open()
    try {
      $ms = New-Object System.IO.MemoryStream
      $s.CopyTo($ms)
      [void]$sb.Append([System.Text.Encoding]::$encoding.GetString($ms.ToArray()))
      $ms.Dispose()
    } finally { $s.Dispose() }
  }
  return $sb.ToString()
}

try {
  $names = $zip.Entries | ForEach-Object { $_.FullName }
  $arscText = Get-EntryText $zip "resources.arsc" "ASCII"
  $dexText = Get-EntryText $zip "classes*.dex" "ASCII"
  $manifestText = Get-EntryText $zip "AndroidManifest.xml" "Unicode"
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

# Cross-device sync checks (mirrors build_release.sh). The admin panel syncs
# over Firestore and an incoming broadcast raises a tray notification on every
# other device. All three are invisible to analyze/test — they live in the
# merged manifest and the packaged dex — and each fails silently at runtime:
# no crash, just an admin whose broadcast reaches nobody.
if ($arscText.Contains($FirebaseProjectId)) {
  Write-Host "  OK  Firebase wired to $FirebaseProjectId"
} else {
  Write-Host "  FAIL  APK carries no reference to Firebase project $FirebaseProjectId."
  Write-Host "        android/app/google-services.json is for a different project —"
  Write-Host "        admin broadcasts will not reach other devices."
  $failed = $true
}
if ($dexText.Contains("flutterlocalnotifications")) {
  Write-Host "  OK  Local-notification plugin packaged"
} else {
  Write-Host "  FAIL  flutter_local_notifications is not in the APK — incoming"
  Write-Host "        admin broadcasts will sync silently, with no notification."
  $failed = $true
}
# No Gemini key compiled into the Dart binary. --dart-define values are
# plaintext literals in libapp.so, so a public APK built with one has a public
# key. The key is delivered at runtime from Firestore instead. Scans libapp.so
# ONLY: the Firebase Android API key is also an AIzaSy string, but it lives in
# resources.arsc and is meant to ship.
$zip2 = [System.IO.Compression.ZipFile]::OpenRead($Apk)
try {
  $libappText = Get-EntryText $zip2 "lib/arm64-v8a/libapp.so" "ASCII"
} finally { $zip2.Dispose() }
# Matches BOTH credential shapes this project has actually had in .env:
# 'AIzaSy...' (a real Google API key) and 'AQ.Ab...' (the OAuth-style
# ephemeral token). A check for AIzaSy alone would wave the latter through.
if (-not ($libappText -match 'AIzaSy|AQ\.Ab')) {
  Write-Host "  OK  No API key compiled into libapp.so"
} elseif ($embeddedKey) {
  # Opted in above, so this is expected - say it loudly rather than failing,
  # or there'd be no way to make a local cloud-AI build at all.
  Write-Host "  !   API key IS baked into libapp.so (ALLOW_EMBEDDED_KEY=1)"
  Write-Host "      This APK is for local testing only - do not upload it."
} else {
  Write-Host "  FAIL  A Gemini API key is baked into libapp.so, but this build"
  Write-Host "        never passed one. Something else injected it - inspect"
  Write-Host "        before shipping."
  $failed = $true
}

if ($manifestText.Contains("POST_NOTIFICATIONS")) {
  Write-Host "  OK  POST_NOTIFICATIONS declared"
} else {
  Write-Host "  FAIL  POST_NOTIFICATIONS missing from the merged manifest —"
  Write-Host "        Android 13+ devices will silently drop every notification."
  $failed = $true
}

if ($failed) { Write-Error "==> BUILD IS NOT DEMO-SAFE"; exit 1 }
Write-Host ("==> OK: {0} ({1:N0} MB)" -f $Apk, ((Get-Item $Apk).Length / 1MB))
