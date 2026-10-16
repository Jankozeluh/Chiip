#!/usr/bin/env bash
# Prints the release notes of one version: the body of its section in CHANGELOG.md (M12, D-179).
#
#     bash tools/release_notes.sh 0.1.0
#
# The section starts at the line "## [0.1.0] - date" and ends before the next "## [" line; the
# heading itself and the blank lines around the text are left out. docs/RELEASING.md feeds the
# output to `gh release create --notes-file`, and the website's Updates page shows that text.
# Exit code 1 (and a message on stderr) when the version has no section or an empty one.

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
	echo "Usage: bash tools/release_notes.sh <version>   (for example 0.1.0)" >&2
	exit 64
fi
CHANGELOG="$(cd "$(dirname "$0")/.." && pwd)/CHANGELOG.md"

notes="$(awk -v tag="[$VERSION]" '
	/^## \[/ { if (inside) exit; if (index($0, tag)) { inside = 1; next } }
	inside { print }
' "$CHANGELOG" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | sed '/./,$!d')"

if [ -z "$notes" ]; then
	echo "CHANGELOG.md has no section for version $VERSION" >&2
	exit 1
fi
printf '%s\n' "$notes"
