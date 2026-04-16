---
name: repack
description: Download and repackage Obsidian into an ARM64 .deb package from the official AMD64 .deb and ARM64 AppImage. Use when a new Obsidian version is released or when the user wants to rebuild the ARM64 deb.
allowed-tools: Bash WebFetch Read Edit Write Grep Glob
argument-hint: [version]
---

# Repack Obsidian ARM64 .deb

Repackage Obsidian for ARM64/aarch64 Debian systems.

**Target version:** $ARGUMENTS (if no version specified, check for the latest version)

## Steps

### 1. Determine version

If the user provided a version as `$ARGUMENTS`, use that. Otherwise, fetch the latest version from the Obsidian download page:

- URL: https://obsidian.md/download
- Look for the current version number (e.g. `1.12.7`)

### 2. Download source packages

Download both files into the project root (`/home/edward/workspace/obsidian-arm64/`):

- **AMD64 .deb**: `https://github.com/obsidianmd/obsidian-releases/releases/download/v{VERSION}/obsidian_{VERSION}_amd64.deb`
- **ARM64 AppImage**: `https://github.com/obsidianmd/obsidian-releases/releases/download/v{VERSION}/Obsidian-{VERSION}-arm64.AppImage`

Skip downloading if the files for this version already exist.

### 3. Run the repack script

```bash
bash repack-arm64.sh {VERSION}
```

The script:
1. Unpacks the AMD64 .deb for its packaging structure
2. Extracts the ARM64 AppImage's squashfs (finds the squashfs offset with Python, carves it with `dd`, extracts with `unsquashfs`)
3. Swaps all ELF binaries and shared libs with ARM64 versions from the AppImage
4. Preserves deb-only files (e.g. `apparmor-profile`)
5. Patches `DEBIAN/control` (Architecture: arm64, recalculates Installed-Size)
6. Regenerates md5sums and rebuilds the .deb

**Prerequisite:** `squashfs-tools` must be installed (`sudo apt-get install squashfs-tools`). If missing, ask the user to install it.

### 4. Verify the output

After the script completes, verify:
- The output file `obsidian_{VERSION}_arm64.deb` exists
- `dpkg-deb -I` shows `Architecture: arm64`
- Key binaries inside are `ARM aarch64` ELF (spot-check with `dpkg-deb -R` + `file`)

### 5. Clean up

Remove intermediate files:
- `build/` directory
- `squashfs-root/` directory

Keep the source `.deb`, `.AppImage`, the output `_arm64.deb`, and the `repack-arm64.sh` script.

### 6. Report

Tell the user:
- Output path and size
- Install command: `sudo dpkg -i obsidian_{VERSION}_arm64.deb`
- Dependency fix: `sudo apt-get install -f`
