#!/usr/bin/env bash
# Packs the exported builds into the three zip files of a GitHub Release (M12, D-172).
#
#     bash tools/package_release.sh            # reads the version from project.godot
#     BUILDS=<folder> bash tools/package_release.sh   # the builds are in another folder
#
# Run it after exporting (docs/DEVELOPING.md, "Exporting the game"), from anywhere. It first runs
# tools/check_export.sh on the macOS build and stops if shooting doesn't work there (D-159). It needs
# builds/windows/Chiip.exe, builds/linux/Chiip.x86_64 and builds/macos/Chiip.app (in $BUILDS,
# builds/ in the project by default), and writes
#
#     $BUILDS/release/Chiip-<version>-windows-x86_64.zip
#     $BUILDS/release/Chiip-<version>-linux-x86_64.zip
#     $BUILDS/release/Chiip-<version>-macos-universal.zip
#     $BUILDS/release/SHA256SUMS.txt        (the SHA-256 checksum of each zip, D-180)
#
# Each zip holds one folder with the game and, next to it, the licences (LICENSE, LICENSE-ASSETS,
# THIRD_PARTY_NOTICES.md), so they ship with every download besides being inside the game's data.
# The Linux file keeps its executable bit (zip stores it); the macOS app is zipped with `ditto`,
# which keeps the bundle's symlinks and signature intact (without the ._ files of extended attributes). Needs only bash, zip and ditto (macOS).

set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT"

VERSION="$(grep -m1 '^config/version=' project.godot | cut -d'"' -f2)"
if [ -z "$VERSION" ]; then
	echo "No config/version in project.godot" >&2
	exit 64
fi

BUILDS="${BUILDS:-builds}"
OUT="$BUILDS/release"
STAGE="$OUT/stage"
NOTICES="LICENSE LICENSE-ASSETS THIRD_PARTY_NOTICES.md"

for built in "$BUILDS/windows/Chiip.exe" "$BUILDS/linux/Chiip.x86_64" "$BUILDS/macos/Chiip.app"; do
	if [ ! -e "$built" ]; then
		echo "Missing $built: export it first (docs/DEVELOPING.md)." >&2
		exit 66
	fi
done

# Shooting must work in the build (v0.1.0 shipped without hit zones, D-159): the Mac app is
# checked on this Mac, and the other two are exported from the same project and its cache.
if ! APP="$BUILDS/macos/Chiip.app" bash "$PROJECT/tools/check_export.sh"; then
	echo "The macOS build fails the hit check: not packing a release." >&2
	exit 1
fi

rm -rf "$OUT"
mkdir -p "$STAGE"

# One staged folder per system: the game and the notices.
stage_folder() { # $1 = system name, $2... = what to copy in
	local name="Chiip-$VERSION-$1"
	shift
	mkdir -p "$STAGE/$name"
	cp -R "$@" "$STAGE/$name/"
	for notice in $NOTICES; do
		cp "$notice" "$STAGE/$name/"
	done
	echo "$name"
}

windows="$(stage_folder windows-x86_64 "$BUILDS/windows/Chiip.exe")"
linux="$(stage_folder linux-x86_64 "$BUILDS/linux/Chiip.x86_64")"
macos="$(stage_folder macos-universal "$BUILDS/macos/Chiip.app")"

(cd "$STAGE" && zip -qr "../$windows.zip" "$windows")
(cd "$STAGE" && zip -qr "../$linux.zip" "$linux")
ditto -c -k --keepParent --norsrc --noextattr "$STAGE/$macos" "$OUT/$macos.zip"

rm -rf "$STAGE"

# The checksums go with the release, so a download can be checked (README, "Check your download").
(cd "$OUT" && shasum -a 256 Chiip-"$VERSION"-*.zip > SHA256SUMS.txt)
ls -l "$OUT"
cat "$OUT/SHA256SUMS.txt"
