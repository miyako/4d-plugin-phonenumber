#!/bin/bash
# Builds the phonenumber synthetic-boundary ownership harness against a source
# tree with ASan/UBSan and runs every test in its own process (macOS only).
#
#   tests/ownership/run.sh <plugin-source-dir> <fixed|baseline>
#
# <plugin-source-dir> (the repository's phonenumber/ folder) provides the
# plugin sources, the vendored libraries and the bundled 4D Plugin API.
# The harness itself always comes from this script's directory, so the SAME
# harness can be run against an immutable baseline (git archive of the base
# SHA) and against the fixed tree.
#
# In "fixed" mode every test must pass. In "baseline" mode the tests named
# in EXPECTED_BASELINE_FAILURES must fail and every other test (the
# controls) must pass; anything else is a harness or model error.
set -euo pipefail

SRC=$(cd "$1" && pwd)
MODE=$2
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

EXPECTED_BASELINE_FAILURES="
defect_picture_fromfile_ownership
defect_picture_setbytes_leak
defect_picture_createcopy_ownership
defect_picture_grayscale_owner_leak
defect_picture_getsize_owner_leak
defect_picture_thumbnail_owner_leak
"

SAN="-g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=undefined"
API="$SRC/4D Plugin API"
# Same prefix header (GCC_PREFIX_HEADER) and user header paths as the Xcode target.
INC=(-include "$SRC/4D Plugin_Prefix.pch" -I "$API" -I "$API/Classes" -I "$SRC" -I "$SRC/include" -I "$SRC/include/mac")

objs=()
cc() { # <file> [extra flags...]
    local file=$1; shift
    local o="$OUT/$(basename "$file").o"
    # The Xcode target compiles every source as Objective-C++ (explicitFileType).
    xcrun clang $SAN -w -x objective-c++ "${INC[@]}" -std=c++17 "$@" -c "$file" -o "$o"
    objs+=("$o")
}

cc "$API/4DPluginAPI.c"
for f in "$API"/Classes/*.cpp; do cc "$f"; done
cc "$SRC/4DPlugin.cpp" -fno-objc-arc
cc "$HERE/engine_harness.mm" -fno-objc-arc

# Vendored static libraries, as linked by the Xcode target.
LIBS=()
for l in phonenumber geocoding protobuf re2 icui18n icuuc icudata boost_thread-mt jsoncpp; do LIBS+=("$SRC/a/lib$l.a"); done
xcrun clang++ $SAN "${objs[@]}" "${LIBS[@]}" -framework Foundation -framework CoreFoundation -framework Carbon -framework Cocoa -o "$OUT/harness"

export ASAN_OPTIONS=abort_on_error=0:halt_on_error=1
export UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1

bad=0
for t in $("$OUT/harness" --list); do
    if "$OUT/harness" "$t" >"$OUT/$t.log" 2>&1; then got=pass; else got=fail; fi
    expect=pass
    if [ "$MODE" = baseline ] && grep -qx "$t" <<<"$EXPECTED_BASELINE_FAILURES"; then expect=fail; fi
    if [ "$got" = "$expect" ]; then status=OK; else status=UNEXPECTED; bad=1; fi
    printf '%-12s %-5s (expected %-4s) %s\n' "$status" "$got" "$expect" "$t"
    if [ "$got" = fail ]; then sed 's/^/    | /' "$OUT/$t.log"; fi
    # A sanitizer report or engine violation is only acceptable as a named
    # baseline failure.
    if [ "$expect" = pass ] && grep -qE 'ERROR: AddressSanitizer|runtime error:|ENGINE VIOLATION' "$OUT/$t.log"; then
        echo "UNEXPECTED   sanitizer/engine violation in $t"; bad=1
    fi
done

if [ $bad -ne 0 ]; then echo "RESULT ($MODE): FAILED"; exit 1; fi
echo "RESULT ($MODE): all outcomes as expected"
