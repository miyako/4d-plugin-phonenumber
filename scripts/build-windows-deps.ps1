# Builds the Windows x64 dependencies for phonenumber.4DX on windows-latest:
#   vcpkg (pinned baseline) -> protobuf 3.21.12, icu 73.1, jsoncpp 1.9.5
#   libphonenumber v8.12.21 (cmake, geocoder ON, std::mutex, no boost/re2)
# Outputs land in lib/windows64/*.lib, which phonenumber.vcxproj links via
# $(SolutionDir)lib\windows64. Everything is idempotent: actions/cache restores
# vcpkg/, deps/ and lib/windows64/ between runs and each step no-ops when its
# products already exist.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot/..

$VCPKG_REF = '2023.10.19'          # baseline: protobuf 3.21.12 / icu 73.1 / jsoncpp 1.9.5
$LIBPHONENUMBER_REF = 'v8.12.21'   # matches the macOS build (README)
$TRIPLET = 'x64-windows-static'

# --- vcpkg -------------------------------------------------------------------
if (-not (Test-Path 'vcpkg/vcpkg.exe')) {
    if (-not (Test-Path 'vcpkg')) {
        git clone --depth 1 --branch $VCPKG_REF https://github.com/microsoft/vcpkg.git vcpkg
    }
    & '.\vcpkg\bootstrap-vcpkg.bat' -disableMetrics
    if ($LASTEXITCODE -ne 0) { throw "vcpkg bootstrap failed ($LASTEXITCODE)" }
}

$env:VCPKG_PLATFORM_TOOLSET = 'v143'   # match the toolset the plugin builds with
& '.\vcpkg\vcpkg.exe' install --triplet $TRIPLET protobuf icu jsoncpp
if ($LASTEXITCODE -ne 0) { throw "vcpkg install failed ($LASTEXITCODE)" }

$VcpkgPrefix = Join-Path $PWD 'vcpkg/installed/x64-windows-static'
$VcpkgLib = Join-Path $VcpkgPrefix 'lib'
$VcpkgBin = Join-Path $VcpkgPrefix 'tools/protobuf'

# --- sanity: the artifacts the vcxproj links must exist ----------------------
$expected = @('libprotobuf.lib', 'jsoncpp.lib', 'icudt.lib', 'icuuc.lib')
$i18nLib = $null
foreach ($name in @('icuin.lib', 'icui18n.lib')) {
    if (Test-Path (Join-Path $VcpkgLib $name)) { $i18nLib = $name; break }
}
if (-not $i18nLib) { throw "No icuin.lib/icui18n.lib in $VcpkgLib" }
$expected += $i18nLib
foreach ($lib in $expected) {
    if (-not (Test-Path (Join-Path $VcpkgLib $lib))) {
        throw "Missing $lib in $VcpkgLib - vcpkg port layout changed?"
    }
}
$protoc = Get-ChildItem $VcpkgBin -Filter 'protoc*.exe' -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $protoc) { throw "protoc.exe not found under $VcpkgBin" }
Write-Host "vcpkg deps OK (i18n lib: $i18nLib, protoc: $($protoc.Name))"

# --- libphonenumber + geocoder ------------------------------------------------
if (-not (Test-Path 'deps/libphonenumber')) {
    New-Item -ItemType Directory -Force -Path deps | Out-Null
    git clone --depth 1 --branch $LIBPHONENUMBER_REF https://github.com/google/libphonenumber.git deps/libphonenumber
}

$BuildDir = Join-Path $PWD 'deps/libphonenumber-build'
$LibOut = Join-Path $PWD 'lib/windows64'
New-Item -ItemType Directory -Force -Path $LibOut | Out-Null

# pick the newest Visual Studio generator cmake knows about (windows-latest
# may carry VS2022, VS18, or both)
$generator = (cmake --help | Select-String -Pattern 'Visual Studio (\d+) (\d{4})' -AllMatches |
    ForEach-Object { $_.Matches } |
    ForEach-Object { "Visual Studio $($_.Groups[1].Value) $($_.Groups[2].Value)" } |
    Sort-Object { [int](($_ -split ' ')[2]) } -Descending | Select-Object -First 1)
if (-not $generator) { throw "No Visual Studio CMake generator found" }
Write-Host "CMake generator: $generator"

$icuI18nPath = Join-Path $VcpkgLib $i18nLib
$icuUcPath = Join-Path $VcpkgLib 'icuuc.lib'
$protobufPath = Join-Path $VcpkgLib 'libprotobuf.lib'

cmake -S 'deps/libphonenumber/cpp' -B $BuildDir -G "Visual Studio $generator" -A x64 -T v143 `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_PREFIX_PATH="$VcpkgPrefix" `
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 `
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded `
    -DBUILD_GEOCODER=ON `
    -DUSE_BOOST=OFF `
    -DUSE_STDMUTEX=ON `
    -DUSE_RE2=OFF `
    -DUSE_PROTOBUF_LITE=OFF `
    -DREGENERATE_METADATA=OFF `
    -DBUILD_TESTING=OFF `
    "-DICU_UC_LIB=$icuUcPath" `
    "-DICU_I18N_LIB=$icuI18nPath" `
    "-DICU_UC_INCLUDE_DIR=$VcpkgPrefix/include" `
    "-DICU_I18N_INCLUDE_DIR=$VcpkgPrefix/include" `
    "-DPROTOBUF_LIB=$protobufPath" `
    "-DPROTOBUF_INCLUDE_DIR=$VcpkgPrefix/include" `
    "-DPROTOC_BIN=$($protoc.FullName)"
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed ($LASTEXITCODE)" }

cmake --build $BuildDir --config Release
if ($LASTEXITCODE -ne 0) { throw "cmake build failed ($LASTEXITCODE)" }

# collect the two static libs the plugin links
foreach ($name in @('phonenumber.lib', 'geocoding.lib')) {
    $found = Get-ChildItem $BuildDir -Recurse -Filter $name -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $found) { throw "$name not produced under $BuildDir" }
    Copy-Item $found.FullName (Join-Path $LibOut $name) -Force
    Write-Host "installed $name -> lib/windows64/"
}

Get-ChildItem $LibOut
Write-Host "Windows dependency build complete."
