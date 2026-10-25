#!/bin/sh
# Builds the game for Windows and Mac into builds/, ready to send to testers:
#   builds/RedAce-<version>-windows.zip   (RedAce.exe + a how-to note)
#   builds/RedAce-<version>-mac.zip       (Red Ace.app + a how-to note)
#
# Run from the project folder:  sh tools/export.sh
# Close the Godot editor first if you've changed project settings.

set -e
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
VERSION=${VERSION:-0.1.0}

# Every build carries the project's version (Windows wants four numbers).
sed -i '' \
	-e "s/^application\/file_version=.*/application\/file_version=\"$VERSION.0\"/" \
	-e "s/^application\/product_version=.*/application\/product_version=\"$VERSION.0\"/" \
	-e "s/^application\/short_version=.*/application\/short_version=\"$VERSION\"/" \
	-e "s/^application\/version=.*/application\/version=\"$VERSION\"/" \
	export_presets.cfg

rm -rf builds/windows builds/mac
mkdir -p builds/windows builds/mac

echo "Building Windows..."
"$GODOT" --headless --path . --export-release "Windows" builds/windows/RedAce.exe >builds/export-windows.log 2>&1
echo "Building Mac..."
"$GODOT" --headless --path . --export-release "macOS" builds/mac/RedAce.zip >builds/export-mac.log 2>&1

# The Mac export is a zip holding the .app: unpack it so the note can sit beside it.
(cd builds/mac && unzip -q RedAce.zip && rm RedAce.zip)

cp tools/tester_readme.txt "builds/windows/How to play.txt"
cp tools/tester_readme.txt "builds/mac/How to play.txt"

rm -f "builds/RedAce-$VERSION-windows.zip" "builds/RedAce-$VERSION-mac.zip"
(cd builds/windows && zip -qr "../RedAce-$VERSION-windows.zip" .)
# ditto keeps the Mac app's permissions and signature intact.
(cd builds && ditto -c -k --sequesterRsrc mac "RedAce-$VERSION-mac.zip")

echo "Done:"
ls -lh builds/*.zip
