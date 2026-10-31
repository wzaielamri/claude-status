#!/usr/bin/env bash
# Build the GNOME Shell extension from this repo:
#   gnome/build.sh [--gnome43] [OUT_DIR]   (default gnome/build)
# makes OUT_DIR/talpy-den@wzaielamri.github.io/ (the extension folder) and
# OUT_DIR/talpy-den@wzaielamri.github.io.shell-extension.zip (for
# `gnome-extensions install`). The Python helpers, Talpy (the pet), its
# pictures and the new-chat icon come from the Plasma widget's
# package/contents, so both front ends share them.
# --gnome43 converts the result for GNOME Shell 43/44 (gnome/gnome43/port43.py).
set -euo pipefail
gnome43=0
if [ "${1:-}" = --gnome43 ]; then
  gnome43=1
  shift
fi
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(dirname "$here")"
uuid="talpy-den@wzaielamri.github.io"
out="$(realpath -m "${1:-$here/build}")"
dest="$out/$uuid"
zip="$out/$uuid.shell-extension.zip"

rm -rf "$dest" "$zip"
mkdir -p "$dest/code" "$dest/pets" "$dest/ui/talpy" "$dest/icons"
cp -r "$here/extension/." "$dest/"
cp "$repo"/package/contents/code/*.py "$dest/code/"
cp "$repo"/package/contents/pets/*.svg "$repo/package/contents/pets/README.md" "$dest/pets/"
cp "$repo"/package/contents/icons/*-symbolic.svg "$dest/icons/"   # (the icons St colors like text)
# Talpy, the pet, is the widget's own code (ES modules: .mjs there, .js here)
for f in "$repo"/package/contents/ui/talpy/*.mjs; do
  sed "s/\.mjs';\$/.js';/" "$f" > "$dest/ui/talpy/$(basename "${f%.mjs}").js"
done
# and the icon table, one icon per meaning in every front end
cp "$repo/package/contents/ui/icons.mjs" "$dest/ui/icons.js"
cp "$repo/LICENSE" "$dest/"
glib-compile-schemas --strict "$dest/schemas"
if [ "$gnome43" = 1 ]; then
  python3 -I "$here/gnome43/port43.py" "$dest"
fi
# zip it with Python (always there; zip may not be)
(cd "$dest" && python3 -I - "$zip" <<'PY'
import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for folder, dirs, files in os.walk("."):
        dirs[:] = sorted(d for d in dirs if d != "__pycache__")
        for name in sorted(files):
            path = os.path.join(folder, name)
            z.write(path, os.path.relpath(path, "."))
PY
)
echo "$dest"
