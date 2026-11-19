<#
.SYNOPSIS
Builds Rust core libraries (Windows + Android arm64-v8a/x86_64) and Flutter app artifacts.
#>
param(
    [switch]$SkipAndroidRust,
    [switch]$SkipWindowsRust,
    [switch]$BuildApk,
    [switch]$UniversalApk,
    [switch]$BuildWindows,
    [switch]$UseChinaMirrors
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$CoreRust = Join-Path $Root "core-rust"
$AppFlutter = Join-Path $Root "app-flutter"

$CargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
if (Test-Path $CargoBin) {
    $env:PATH = "$CargoBin;$env:PATH"
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue) -and (Test-Path "D:\dev\flutter\bin")) {
    $env:PATH = "D:\dev\flutter\bin;$env:PATH"
}

if (-not $env:JAVA_HOME -and (Test-Path "D:\dev\jdk17")) {
    $env:JAVA_HOME = "D:\dev\jdk17"
}
$AndroidSdk = if ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} elseif (Test-Path (Join-Path $env:LOCALAPPDATA "Android\Sdk")) {
    Join-Path $env:LOCALAPPDATA "Android\Sdk"
} elseif (Test-Path "D:\dev\android-sdk") {
    "D:\dev\android-sdk"
} else {
    ""
}
if ($AndroidSdk) {
    $env:ANDROID_HOME = $AndroidSdk
    $env:ANDROID_SDK_ROOT = $AndroidSdk
}

if ($UseChinaMirrors) {
    $env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
    $env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
}

$NdkBin = ""
if (-not $SkipAndroidRust) {
    $NdkRoot = Join-Path $AndroidSdk "ndk"
    if (Test-Path $NdkRoot) {
        $LatestNdk = Get-ChildItem $NdkRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($LatestNdk) {
            $NdkBin = Join-Path $LatestNdk.FullName "toolchains\llvm\prebuilt\windows-x86_64\bin"
        }
    }
    if (-not $NdkBin -or -not (Test-Path $NdkBin)) {
        throw "Android NDK not found under '$NdkRoot'. Set ANDROID_HOME or pass -SkipAndroidRust."
    }
}

function Invoke-Checked {
    param([scriptblock]$Cmd, [string]$Label)
    & $Cmd
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

Push-Location $CoreRust
try {
    if (-not $SkipWindowsRust) {
        Write-Host "==> Building Windows Release DLL (p2p_chat_core.dll)..."
        Invoke-Checked { cargo build --release --lib } "Windows cargo build"
    }

    if (-not $SkipAndroidRust) {
        $env:CC_aarch64_linux_android = Join-Path $NdkBin "aarch64-linux-android24-clang.cmd"
        $env:CXX_aarch64_linux_android = Join-Path $NdkBin "aarch64-linux-android24-clang++.cmd"
        $env:AR_aarch64_linux_android = Join-Path $NdkBin "llvm-ar.exe"
        $env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = Join-Path $NdkBin "aarch64-linux-android24-clang.cmd"

        $env:CC_x86_64_linux_android = Join-Path $NdkBin "x86_64-linux-android24-clang.cmd"
        $env:CXX_x86_64_linux_android = Join-Path $NdkBin "x86_64-linux-android24-clang++.cmd"
        $env:AR_x86_64_linux_android = Join-Path $NdkBin "llvm-ar.exe"
        $env:CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER = Join-Path $NdkBin "x86_64-linux-android24-clang.cmd"

        Write-Host "==> Building Android arm64-v8a (.so)..."
        Invoke-Checked { cargo build --release --lib --target aarch64-linux-android } "Android arm64 cargo build"

        Write-Host "==> Building Android x86_64 (.so)..."
        Invoke-Checked { cargo build --release --lib --target x86_64-linux-android } "Android x86_64 cargo build"

        $Arm64Out = Join-Path $AppFlutter "android\app\src\main\jniLibs\arm64-v8a"
        $X64Out = Join-Path $AppFlutter "android\app\src\main\jniLibs\x86_64"
        New-Item -ItemType Directory -Force -Path $Arm64Out, $X64Out | Out-Null

        Copy-Item -Force (Join-Path $CoreRust "target\aarch64-linux-android\release\libp2p_chat_core.so") (Join-Path $Arm64Out "libp2p_chat_core.so")
        Copy-Item -Force (Join-Path $CoreRust "target\x86_64-linux-android\release\libp2p_chat_core.so") (Join-Path $X64Out "libp2p_chat_core.so")
        Write-Host "==> Copied Android jniLibs into app-flutter/android/app/src/main/jniLibs/"
    }
} finally {
    Pop-Location
}

if ($BuildApk -or $BuildWindows) {
    $DistDir = Join-Path $Root "dist"
    New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

    $PubspecVersionMatch = Select-String -Path (Join-Path $AppFlutter "pubspec.yaml") -Pattern '^version:\s*([^+\s#]+)' | Select-Object -First 1
    $AppVersionDefine = if ($PubspecVersionMatch) { $PubspecVersionMatch.Matches[0].Groups[1].Value.Trim() } else { "0.1.0" }

    Push-Location $AppFlutter
    try {
        if ($BuildWindows) {
            Write-Host "==> Building Windows desktop app (release, v$AppVersionDefine)..."
            Get-Process p2p_chat_app -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 300
            Invoke-Checked { flutter build windows --release --dart-define="APP_VERSION=$AppVersionDefine" } "Flutter Windows release build"

            $WinReleaseDir = Join-Path $AppFlutter "build\windows\x64\runner\Release"
            $RustReleaseDll = Join-Path $CoreRust "target\release\p2p_chat_core.dll"
            if (Test-Path $RustReleaseDll) {
                Copy-Item -Force $RustReleaseDll (Join-Path $WinReleaseDir "p2p_chat_core.dll")
            }

            $WinDebugDir = Join-Path $AppFlutter "build\windows\x64\runner\Debug"
            if (Test-Path $WinDebugDir) {
                Copy-Item -Recurse -Force (Join-Path $WinReleaseDir "*") $WinDebugDir
            }

            $WinZipOut = Join-Path $DistDir "p2p-chat-windows-x64.zip"
            if (Test-Path $WinZipOut) {
                Remove-Item -Force $WinZipOut
            }
            Write-Host "==> Packaging portable Windows bundle into $WinZipOut..."
            Compress-Archive -Path (Join-Path $WinReleaseDir "*") -DestinationPath $WinZipOut -Force
        }
        if ($BuildApk) {
            if ($UniversalApk) {
                Write-Host "==> Building Android Universal APK (release, v$AppVersionDefine)..."
                Invoke-Checked { flutter build apk --release --target-platform android-arm64,android-x64 --dart-define="APP_VERSION=$AppVersionDefine" } "Flutter Universal APK release build"

                $ApkBuilt = Join-Path $AppFlutter "build\app\outputs\flutter-apk\app-release.apk"
                $ApkUnivOut = Join-Path $DistDir "p2p-chat-android-universal-release.apk"
                $ApkCompatOut = Join-Path $DistDir "p2p-chat-android-release.apk"
                Copy-Item -Force $ApkBuilt $ApkUnivOut
                Copy-Item -Force $ApkBuilt $ApkCompatOut
                $UnivMb = [math]::Round((Get-Item $ApkUnivOut).Length / 1MB, 2)
                Write-Host "==> Built Universal APK ($UnivMb MB) -> $ApkUnivOut"
            } else {
                Write-Host "==> Building Android Split-per-ABI APKs (arm64-v8a + x86_64, release, v$AppVersionDefine)..."
                Invoke-Checked { flutter build apk --release --split-per-abi --target-platform android-arm64,android-x64 --dart-define="APP_VERSION=$AppVersionDefine" } "Flutter Split-ABI APK release build"

                $Arm64Built = Join-Path $AppFlutter "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
                $X64Built = Join-Path $AppFlutter "build\app\outputs\flutter-apk\app-x86_64-release.apk"
                $Arm64Out = Join-Path $DistDir "p2p-chat-android-arm64-v8a-release.apk"
                $X64Out = Join-Path $DistDir "p2p-chat-android-x86_64-release.apk"
                $ApkCompatOut = Join-Path $DistDir "p2p-chat-android-release.apk"

                Copy-Item -Force $Arm64Built $Arm64Out
                Copy-Item -Force $Arm64Built $ApkCompatOut
                Copy-Item -Force $X64Built $X64Out

                $ArmMb = [math]::Round((Get-Item $Arm64Out).Length / 1MB, 2)
                $X64Mb = [math]::Round((Get-Item $X64Out).Length / 1MB, 2)
                Write-Host "==> Built arm64-v8a APK ($ArmMb MB) -> $Arm64Out (and $ApkCompatOut)"
                Write-Host "==> Built x86_64 APK    ($X64Mb MB) -> $X64Out"
            }
        }
    } finally {
        Pop-Location
    }
}
