#!/bin/bash
set -euo pipefail

#
# Repackage Obsidian AMD64 .deb into ARM64 .deb
# by swapping in binaries from the ARM64 AppImage.
#

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.12.7"
    exit 1
fi
VERSION="$1"
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
DEB_SRC="${WORK_DIR}/obsidian_${VERSION}_amd64.deb"
APPIMAGE_SRC="${WORK_DIR}/Obsidian-${VERSION}-arm64.AppImage"
BUILD_DIR="${WORK_DIR}/build"
OUTPUT="${WORK_DIR}/obsidian_${VERSION}_arm64.deb"

# Paths for intermediate extraction
DEB_EXTRACT="${BUILD_DIR}/deb_extract"
APPIMAGE_EXTRACT="${WORK_DIR}/squashfs-root"

echo "=== Obsidian ARM64 .deb Repackager ==="
echo "Version: ${VERSION}"
echo ""

# --- Sanity checks ---
for f in "$DEB_SRC" "$APPIMAGE_SRC"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: Missing required file: $f"
        exit 1
    fi
done

if ! command -v dpkg-deb &>/dev/null; then
    echo "ERROR: dpkg-deb is required but not found."
    exit 1
fi

# --- Clean previous build ---
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# --- Step 1: Unpack the AMD64 .deb ---
echo "[1/5] Unpacking AMD64 .deb..."
mkdir -p "${DEB_EXTRACT}"
dpkg-deb -R "${DEB_SRC}" "${DEB_EXTRACT}"

# --- Step 2: Extract AppImage squashfs (if not already extracted) ---
if [[ ! -d "${APPIMAGE_EXTRACT}" ]]; then
    echo "[2/5] Extracting ARM64 AppImage squashfs..."
    if ! command -v unsquashfs &>/dev/null; then
        echo "ERROR: unsquashfs (squashfs-tools) is required but not found."
        exit 1
    fi
    OFFSET=$(python3 -c "
data = open('${APPIMAGE_SRC}', 'rb').read(300000)
idx = data.find(b'hsqs')
if idx == -1:
    raise RuntimeError('squashfs magic not found in AppImage')
print(idx)
")
    dd if="${APPIMAGE_SRC}" of="${BUILD_DIR}/squashfs.img" bs=1 skip="${OFFSET}" 2>/dev/null
    unsquashfs -d "${APPIMAGE_EXTRACT}" "${BUILD_DIR}/squashfs.img"
    rm -f "${BUILD_DIR}/squashfs.img"
else
    echo "[2/5] Using existing AppImage extraction at ${APPIMAGE_EXTRACT}"
fi

# --- Step 3: Swap in ARM64 binaries/libs from AppImage ---
echo "[3/5] Replacing AMD64 binaries with ARM64 equivalents..."
OPT_DIR="${DEB_EXTRACT}/opt/Obsidian"

# Files to replace: all ELF binaries and shared libraries, plus architecture-
# sensitive data files. We copy everything from the AppImage's root that has a
# counterpart in the deb's opt/Obsidian, EXCEPT for the resources/ subtree
# which we handle separately below.
for src_file in "${APPIMAGE_EXTRACT}"/*; do
    fname="$(basename "$src_file")"
    dst_file="${OPT_DIR}/${fname}"

    # Skip AppImage-only files that don't belong in the deb
    case "$fname" in
        AppRun|obsidian.desktop|obsidian.png|.DirIcon|usr) continue ;;
    esac

    if [[ -f "$src_file" && -f "$dst_file" ]]; then
        cp -f "$src_file" "$dst_file"
    elif [[ -d "$src_file" && "$fname" != "resources" ]]; then
        # Replace entire directory (e.g. locales)
        rm -rf "$dst_file"
        cp -a "$src_file" "$dst_file"
    fi
done

# Handle resources/ subtree: replace arch-sensitive files, keep deb-only files
echo "    Replacing resources/ contents..."
APPIMAGE_RES="${APPIMAGE_EXTRACT}/resources"
DEB_RES="${OPT_DIR}/resources"

# Replace files that exist in both
for src_file in "${APPIMAGE_RES}"/*; do
    fname="$(basename "$src_file")"
    dst_file="${DEB_RES}/${fname}"
    if [[ -f "$src_file" ]]; then
        cp -f "$src_file" "$dst_file"
    elif [[ -d "$src_file" ]]; then
        rm -rf "$dst_file"
        cp -a "$src_file" "$dst_file"
    fi
done
# apparmor-profile exists only in the deb — it's a text file, keep it as-is.

# Also replace icons from AppImage
if [[ -d "${APPIMAGE_EXTRACT}/usr/share/icons" ]]; then
    echo "    Replacing icons..."
    rm -rf "${DEB_EXTRACT}/usr/share/icons"
    cp -a "${APPIMAGE_EXTRACT}/usr/share/icons" "${DEB_EXTRACT}/usr/share/icons"
fi

# --- Step 4: Fix DEBIAN/control for arm64 ---
echo "[4/5] Patching DEBIAN/control for arm64..."
CONTROL="${DEB_EXTRACT}/DEBIAN/control"

# Change architecture
sed -i 's/^Architecture: amd64$/Architecture: arm64/' "$CONTROL"

# Recalculate installed size (in KB)
INSTALLED_SIZE=$(du -sk "${DEB_EXTRACT}" | awk '{print $1}')
sed -i "s/^Installed-Size: .*/Installed-Size: ${INSTALLED_SIZE}/" "$CONTROL"

echo "    Updated control file:"
cat "$CONTROL"

# --- Step 4b: Regenerate md5sums ---
echo "    Regenerating md5sums..."
(cd "${DEB_EXTRACT}" && find . -type f ! -path './DEBIAN/*' -exec md5sum {} + | sed 's| \./| |') > "${DEB_EXTRACT}/DEBIAN/md5sums"

# --- Step 5: Repack into arm64 .deb ---
echo "[5/5] Building ARM64 .deb package..."
# Ensure correct permissions on maintainer scripts
chmod 0755 "${DEB_EXTRACT}/DEBIAN/postinst" "${DEB_EXTRACT}/DEBIAN/postrm"

dpkg-deb --build --root-owner-group "${DEB_EXTRACT}" "${OUTPUT}"

echo ""
echo "=== Done! ==="
echo "Output: ${OUTPUT}"
echo "Size: $(du -h "${OUTPUT}" | awk '{print $1}')"
echo ""
echo "Install with: sudo dpkg -i ${OUTPUT}"
echo "If dependencies are missing: sudo apt-get install -f"
