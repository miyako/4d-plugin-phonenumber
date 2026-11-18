# Builds the Windows x64 dependencies for phonenumber.4DX on windows-latest:
#   vcpkg (pinned baseline) -> protobuf 3.21.12 (overlay), icu 79.1, jsoncpp 1.9.6, gtest
#   libphonenumber v8.12.21 (cmake, geocoder ON, std::mutex, no boost/re2)
# Outputs land in lib/windows64/*.lib, which phonenumber.vcxproj links via
# $(SolutionDir)lib\windows64. Everything is idempotent: actions/cache restores
# vcpkg/, deps/ and lib/windows64/ between runs and each step no-ops when its
# products already exist.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot/..

$VCPKG_REF = '2026.10.16'          # current baseline (icu 79.1 / jsoncpp 1.9.6)
$VCPKG_PORTS_REF = '2023.10.19'    # baseline whose protobuf port is 3.21.12
$LIBPHONENUMBER_REF = 'v8.12.21'   # matches the macOS build (README)
$TRIPLET = 'x64-windows-static'

# --- vcpkg -------------------------------------------------------------------
# actions/cache restore-keys can resurrect a vcpkg cloned at an older ref;
# the stamp file makes a stale restore detectable instead of silently reused.
$stamp = 'vcpkg/.vcpkg-ref'
$stampOk = (Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $VCPKG_REF)
if ((Test-Path 'vcpkg') -and -not $stampOk) {
    Write-Host "cached vcpkg missing or at a different ref - recloning"
    Remove-Item -Recurse -Force vcpkg
}
if (-not (Test-Path 'vcpkg/vcpkg.exe')) {
    git clone --depth 1 --branch $VCPKG_REF https://github.com/microsoft/vcpkg.git vcpkg
    if ($LASTEXITCODE -ne 0) { throw "vcpkg clone failed ($LASTEXITCODE)" }
    Set-Content -Path $stamp -Value $VCPKG_REF -NoNewline
    & '.\vcpkg\bootstrap-vcpkg.bat' -disableMetrics
    if ($LASTEXITCODE -ne 0) { throw "vcpkg bootstrap failed ($LASTEXITCODE)" }
}

# protobuf must stay on 3.21.x: the .pb.cc files libphonenumber generates at
# build time are only compatible with a protobuf 3.x runtime. The current
# vcpkg ships protobuf 7.x, so overlay the 3.21.12 port from an old baseline.
if (-not (Test-Path 'vcpkg-overlay/protobuf')) {
    if (-not (Test-Path 'vcpkg-overlay-src')) {
        git clone --depth 1 --filter=blob:none --sparse --branch $VCPKG_PORTS_REF `
            https://github.com/microsoft/vcpkg.git vcpkg-overlay-src
        & git -C vcpkg-overlay-src sparse-checkout set ports/protobuf
        if ($LASTEXITCODE -ne 0) { throw "sparse checkout failed ($LASTEXITCODE)" }
    }
    New-Item -ItemType Directory -Force -Path vcpkg-overlay | Out-Null
    Copy-Item -Recurse -Force 'vcpkg-overlay-src/ports/protobuf' 'vcpkg-overlay/protobuf'
}

$env:VCPKG_PLATFORM_TOOLSET = 'v143'   # match the toolset the plugin builds with
& '.\vcpkg\vcpkg.exe' install --triplet $TRIPLET --overlay-ports=vcpkg-overlay protobuf icu jsoncpp gtest
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

# libphonenumber's CMake build generates src/phonenumbers/geocoding/
# geocoding_data.cc by compiling tools/cpp/generate_geocoding_data, which uses
# POSIX-only dirent.h and cannot build under MSVC. Ship a pre-generated copy
# (produced from the pinned v8.12.21 resources on a POSIX host) and strip the
# generation rules from the CMake files so the static libs compile the checked-in
# file directly.
$geoOut = 'deps/libphonenumber/cpp/src/phonenumbers/geocoding/geocoding_data.cc'
if (-not (Test-Path $geoOut)) {
    $geoGz = 'windows-deps/libphonenumber-geocoding_data.cc.gz'
    if (-not (Test-Path $geoGz)) { throw "missing $geoGz" }
    Add-Type -AssemblyName System.IO.Compression
    $in = [System.IO.File]::OpenRead($geoGz)
    try {
        $gz = New-Object System.IO.Compression.GzipStream($in, [System.IO.Compression.CompressionMode]::Decompress)
        try {
            $out = [System.IO.File]::Create($geoOut)
            try { $gz.CopyTo($out) } finally { $out.Close() }
        } finally { $gz.Close() }
    } finally { $in.Close() }
    Write-Host "installed pre-generated geocoding_data.cc"
}

# The test tree lists a generated geocoding_test_data.cc that the removed
# custom command would have produced; CMake requires every listed source to
# exist at generate time even though we never build the test targets.
$geoTestOut = 'deps/libphonenumber/cpp/test/phonenumbers/geocoding/geocoding_test_data.cc'
if (-not (Test-Path $geoTestOut)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $geoTestOut) | Out-Null
    Set-Content -Path $geoTestOut -Value '// placeholder: test data is never built on Windows' -NoNewline
}

$cmPath = 'deps/libphonenumber/cpp/CMakeLists.txt'
$cm = [System.IO.File]::ReadAllText($cmPath)
$cm = $cm -replace '(?ms)^\s*add_subdirectory\("\$\{CMAKE_CURRENT_SOURCE_DIR\}/\.\./tools/cpp".*?\r?\n', ''
$cm = $cm -replace '(?ms)add_custom_command\s*\(\s*COMMAND generate_geocoding_data.*?\n\s*\)\s*', ''
$cm = $cm -replace '(?m)^\s*add_dependencies\s*\([^)]*generate_geocoding_data[^)]*\)\s*\r?\n', ''
if ($cm -match 'add_subdirectory.*tools/cpp' -or
    $cm -match 'add_dependencies\s*\([^)]*generate_geocoding_data' -or
    $cm -match 'add_custom_command\s*\(\s*COMMAND generate_geocoding_data') {
    throw "CMakeLists patch incomplete - generate_geocoding_data still referenced"
}
[System.IO.File]::WriteAllText($cmPath, $cm)

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

cmake -S 'deps/libphonenumber/cpp' -B $BuildDir -G $generator -A x64 -T v143 `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_PREFIX_PATH="$VcpkgPrefix" `
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" `
    -DCMAKE_CXX_STANDARD=17 `
    "-DCMAKE_CXX_FLAGS=-DNOMINMAX" `
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

cmake --build $BuildDir --config Release --target phonenumber geocoding
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
