# Obsidian ARM64 .deb Repackager

Obsidian does not officially provide a `.deb` package for ARM64/aarch64 Linux systems. However, they do provide an ARM64 AppImage. This project repackages the official AMD64 `.deb` structure with the ARM64 binaries from the AppImage to produce a working ARM64 `.deb` package.

## How It Works

1. **Downloads** the official AMD64 `.deb` (for packaging structure: control files, postinst/postrm scripts, desktop entry, icons) and the ARM64 `.AppImage` (for the actual aarch64 binaries)
2. **Unpacks** the `.deb` with `dpkg-deb -R`
3. **Extracts** the AppImage's embedded squashfs filesystem (locates the squashfs magic bytes, carves with `dd`, extracts with `unsquashfs`)
4. **Swaps** all ELF binaries and shared libraries with their ARM64 counterparts from the AppImage
5. **Preserves** deb-only files like the AppArmor profile
6. **Patches** `DEBIAN/control` to set `Architecture: arm64` and recalculates `Installed-Size`
7. **Regenerates** `md5sums` and **rebuilds** the `.deb` with `dpkg-deb --build`

## Prerequisites

- Debian/Ubuntu-based system (needs `dpkg-deb`)
- `squashfs-tools` (`sudo apt-get install squashfs-tools`)
- `python3` (for finding the squashfs offset in the AppImage)
- `wget` (for downloading)

## Usage

### Manual

```bash
# Download source files (example for version 1.12.7)
wget https://github.com/obsidianmd/obsidian-releases/releases/download/v1.12.7/obsidian_1.12.7_amd64.deb
wget https://github.com/obsidianmd/obsidian-releases/releases/download/v1.12.7/Obsidian-1.12.7-arm64.AppImage

# Run the repackager (version is required)
bash repack-arm64.sh 1.12.7

# Install on ARM64 Debian system
sudo dpkg -i obsidian_1.12.7_arm64.deb
sudo apt-get install -f  # fix any missing dependencies
```

### With Claude Code

If you have [Claude Code](https://claude.com/claude-code) set up in this project, simply run:

```
/repack 1.12.7
```

Or omit the version to automatically detect and use the latest:

```
/repack
```

## File Structure

```
.
├── repack-arm64.sh              # Main repackaging script
├── obsidian_X.Y.Z_amd64.deb    # Downloaded AMD64 deb (source)
├── Obsidian-X.Y.Z-arm64.AppImage  # Downloaded ARM64 AppImage (source)
├── obsidian_X.Y.Z_arm64.deb    # Output ARM64 deb (result)
├── README.md
├── CLAUDE.md
└── .claude/
    └── skills/
        └── repack/
            └── SKILL.md         # Claude Code /repack skill
```

## Known Notes

- The native Node modules (`btime/binding.node`, `get-fonts/binding.node`) are x86-64 in the upstream ARM64 AppImage itself. This is an upstream packaging issue, not introduced by this repackager. They likely have JS fallbacks or are unused on Linux.
- The AppArmor profile from the `.deb` is preserved as-is since it's architecture-independent.

## Version History

- **1.12.7** — First version repackaged (2026-04-15)
