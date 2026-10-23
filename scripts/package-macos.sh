#!/bin/bash
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(git -C "$app_dir" rev-parse --show-toplevel)"
if [[ "$repo_dir" == "$app_dir" ]]; then source_path="."; else source_path="apps/creator"; fi
dirty="$(git -C "$repo_dir" status --porcelain --untracked-files=all -- "$source_path")"
if [[ -n "$dirty" ]]; then
  printf 'Refusing to package uncommitted Creator source; commit the exact app revision first.\n' >&2
  exit 2
fi
source_sha="$(git -C "$repo_dir" rev-parse HEAD)"
out_dir="${1:-$app_dir/build/variants/$source_sha}"
if [[ -e "$out_dir" ]]; then
  printf 'Refusing to overwrite existing package output: %s\n' "$out_dir" >&2
  exit 2
fi
mkdir -p "$out_dir"
manifest="$out_dir/release-manifest.txt"
printf 'source_commit=%s\n' "$source_sha" > "$manifest"
cd "$app_dir"
swift build -c release --product PipCreator
binary="$app_dir/.build/release/PipCreator"
for variant in neutral-core neutral-plus pip-core pip-plus; do
  case "$variant" in
    neutral-core) display="Creator Studio"; theme="neutral"; plus=false ;;
    neutral-plus) display="Creator Studio Plus"; theme="neutral"; plus=true ;;
    pip-core) display="Pip Creator"; theme="pip"; plus=false ;;
    pip-plus) display="Pip Creator Plus"; theme="pip"; plus=true ;;
  esac
  bundle="$out_dir/$display.app"
  mkdir -p "$bundle/Contents/MacOS"
  cp "$binary" "$bundle/Contents/MacOS/PipCreator"
  cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$display</string>
<key>CFBundleDisplayName</key><string>$display</string>
<key>CFBundleIdentifier</key><string>com.ghostzy.pipcreator.$variant</string>
<key>CFBundleExecutable</key><string>PipCreator</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0-alpha.1</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>PIPCreatorTheme</key><string>$theme</string>
<key>PIPCreatorPlus</key><$plus/>
<key>PIPCreatorSourceCommit</key><string>$source_sha</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
  codesign --force --deep --sign - "$bundle"
  codesign --verify --deep --strict "$bundle"
  archive="$out_dir/$variant.zip"
  ditto -c -k --sequesterRsrc --keepParent "$bundle" "$archive"
  binary_sha="$(shasum -a 256 "$bundle/Contents/MacOS/PipCreator" | awk '{print $1}')"
  archive_sha="$(shasum -a 256 "$archive" | awk '{print $1}')"
  printf '%s binary_sha256=%s archive_sha256=%s\n' "$variant" "$binary_sha" "$archive_sha" | tee -a "$manifest"
done
printf 'source_sha=%s\noutput=%s\n' "$source_sha" "$out_dir"
