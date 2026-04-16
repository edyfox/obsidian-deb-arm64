# Obsidian ARM64 .deb Repackager

## What This Project Does

Repackages the official Obsidian AMD64 `.deb` into an ARM64 `.deb` by transplanting binaries from the official ARM64 AppImage. Obsidian does not ship an ARM64 deb, but does ship an ARM64 AppImage — this project bridges that gap.

## Key Files

- `repack-arm64.sh` — Main repackaging script. Requires a version argument (e.g. `bash repack-arm64.sh 1.12.7`).
- `.claude/skills/repack/SKILL.md` — Claude Code skill for `/repack [version]`.

## How the Repackaging Works

1. Unpack AMD64 `.deb` with `dpkg-deb -R` (gives us DEBIAN/ control files, postinst/postrm, desktop entry, icons)
2. Extract ARM64 AppImage squashfs: find `hsqs` magic bytes with Python, carve with `dd`, extract with `unsquashfs`
3. Swap all ELF binaries/libs in `opt/Obsidian/` with ARM64 versions from AppImage
4. Preserve deb-only files (e.g. `resources/apparmor-profile`)
5. Patch `DEBIAN/control`: `Architecture: arm64`, recalculate `Installed-Size`
6. Regenerate `md5sums`, rebuild with `dpkg-deb --build`

## Prerequisites

- `dpkg-deb` (standard on Debian)
- `squashfs-tools` (for `unsquashfs`) — must be installed manually: `sudo apt-get install squashfs-tools`
- `python3`
- `wget`

## Download URLs Pattern

- AMD64 deb: `https://github.com/obsidianmd/obsidian-releases/releases/download/v{VERSION}/obsidian_{VERSION}_amd64.deb`
- ARM64 AppImage: `https://github.com/obsidianmd/obsidian-releases/releases/download/v{VERSION}/Obsidian-{VERSION}-arm64.AppImage`
- Latest version can be found at: https://obsidian.md/download

## Known Quirks

- Native Node modules (`btime/binding.node`, `get-fonts/binding.node`) are x86-64 even in the upstream ARM64 AppImage. This is an upstream issue — don't try to fix it.
- The AppImage cannot be `--appimage-extract`'d on a non-ARM64 host (exec format error). Instead, find the squashfs offset and use `unsquashfs` directly.
