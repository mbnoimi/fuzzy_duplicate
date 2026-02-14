# Fuzzy Duplicate Finder

<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/0/00/Flag_of_Palestine.svg" alt="Palestine Flag" width="60" height="40">
  <img src="https://upload.wikimedia.org/wikipedia/commons/b/b8/Flag_of_Syria_%281930%E2%80%931958%2C_1961%E2%80%931963%29.svg" alt="Syria Flag" width="70" height="40">
  <img src="https://upload.wikimedia.org/wikipedia/commons/4/49/Flag_of_Ukraine.svg" alt="Ukraine Flag" width="60" height="40">
</p>

<p align="center">
  <b>🕊️ Freedom for Palestine, Ukraine, Syria, and all nations fighting against tyrants 🕊️</b>
</p>

<p align="center">
  <sub>Free Palestine • Free Syria • Peace for Ukraine</sub>
</p>

<br>

<p align="center">
  <img src="assets/icons/logo.svg" alt="Fuzzy Duplicate Finder Logo" width="120" height="120">
</p>

<p align="center">
  A cross-platform duplicate file finder with fuzzy matching and an intuitive GUI & CLI interface
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-usage">Usage</a> •
  <a href="#build-from-source">Building</a> •
  <a href="#-contributing">Contributing</a> •
  <a href="#%EF%B8%8F-roadmap">Roadmap</a>
</p>

---

## ✨ Features

- **🎯 Fuzzy Matching** - Find duplicates by similar filenames using intelligent string matching
- **🔐 Content Verification** - Optional xxHash3-based content checking for 100% accuracy
- **📁 Multiple File Types** - Support for videos, documents, images, audio, archives, and custom extensions
- **🖥️ Dual Interface** - Beautiful Material 3 GUI and powerful CLI for automation
- **⚡ High Performance** - Optimized scanning with parallel processing and progress tracking
- **💾 Memory Efficient** - Handles millions of files with <100 MB RAM usage (streaming architecture)
- **🎨 Modern UI** - Clean, responsive interface with dark/light/system theme support
- **🛡️ Safe Operations** - Review before moving or deleting, with undo-friendly workflows

---

## 📦 Installation

### Pre-built Binaries

Download the latest release for your platform from the [Releases](https://github.com/mbnoimi/fuzzy_duplicate/releases) page.

**Supported Platforms:**
- Linux (x64)
- Windows (x64)
- macOS (coming soon)

### Build from Source

#### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (3.0.0 or higher)

#### Steps

```bash
# Clone the repository
git clone https://github.com/mbnoimi/fuzzy_duplicate.git
cd fuzzy_duplicate

# Install dependencies
flutter pub get

# Build for your platform
# Linux
flutter build linux --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

---

## 🚀 Usage

### GUI Mode

Launch without arguments to open the graphical interface:

```bash
# Linux
./fuzzy_duplicate

# Windows
fuzzy_duplicate.exe
```

**GUI Features:**
1. Select source directory to scan
2. Choose target directory (for moving duplicates)
3. Pick file type or set custom extensions
4. Adjust similarity threshold (1-100%)
5. Click "Scan" to find duplicates
6. Review results and select files to move/delete

### CLI Mode

Perfect for automation, scripts, and headless servers. The CLI provides powerful duplicate detection with detailed progress output.

#### Quick Start Examples

**Linux/macOS:**
```bash
# Preview what would be done (dry run) - recommended first step
./fuzzy_duplicate -t videos -s ~/Videos -T ~/Duplicates --dry-run

# Move duplicate videos to another folder
./fuzzy_duplicate -t videos -s ~/Videos -T ~/Duplicates

# Delete duplicate documents with 95% similarity
./fuzzy_duplicate -t documents -s ~/Documents -d -S 0.95

# Find duplicates by content hash (100% accurate, slower)
./fuzzy_duplicate -t images -s ~/Pictures -T ~/Dups -c

# Find all file types
./fuzzy_duplicate -t all -s ~/Downloads -T ~/Duplicates

# Find specific log files only
./fuzzy_duplicate -t custom -e log -s /var/log -T /backup/logs

# Find multiple code file types
./fuzzy_duplicate -t custom -e "js,ts,jsx,tsx" -s ~/Projects -T ~/CodeDups

# Exclude temporary files
./fuzzy_duplicate -t all -s ~/Data -T ~/Dups -x "tmp,temp,bak,~"
```

**Windows:**
```powershell
# Preview what would be done (dry run)
fuzzy_duplicate.exe -t videos -s C:\Users\User\Videos -T C:\Duplicates --dry-run

# Move duplicate videos
fuzzy_duplicate.exe -t videos -s C:\Users\User\Videos -T C:\Duplicates

# Delete duplicate documents
fuzzy_duplicate.exe -t documents -s C:\Users\User\Documents -d -S 0.95

# Find by content
fuzzy_duplicate.exe -t images -s C:\Users\User\Pictures -T C:\Dups -c

# Find all files
fuzzy_duplicate.exe -t all -s C:\Users\User\Downloads -T C:\Duplicates

# Custom extensions
fuzzy_duplicate.exe -t custom -e log -s C:\Logs -T C:\Backup

# Exclude temp files
fuzzy_duplicate.exe -t all -s C:\Data -T C:\Dups -x "tmp,temp,bak"
```

#### CLI Options Reference

| Option | Short | Description | Required |
|--------|-------|-------------|----------|
| `--type` | `-t` | File type: `all`, `videos`, `documents`, `images`, `audio`, `archives`, `custom` | ✅ |
| `--source` | `-s` | Source directory path | ✅ |
| `--target` | `-T` | Target directory for moving duplicates | * |
| `--delete` | `-d` | Delete duplicates instead of moving | * |
| `--dry-run` | `-n` | Preview mode - no files modified | ❌ |
| `--extension` | `-e` | Custom extensions (comma-separated, e.g., `log,txt` or `js,ts`) | * |
| `--exclude` | `-x` | Extensions to exclude (comma-separated, e.g., `tmp,temp,bak`) | ❌ |
| `--similarity` | `-S` | Similarity threshold 0.5-1.0 (default: 0.8). Higher = stricter | ❌ |
| `--content` | `-c` | Check file content using xxHash3 (slower but 100% accurate) | ❌ |
| `--help` | `-h` | Show detailed help with all examples | ❌ |

*Either `--target`, `--delete`, or `--dry-run` is required

#### File Types

The `-t` option supports these predefined categories:

| Type | Extensions Included |
|------|-------------------|
| `all` | All files (*) |
| `videos` | mp4, avi, mkv, mov, wmv, flv, webm, m4v, ogv, 3gp, ts, mts, vob, etc. |
| `documents` | pdf, doc, docx, txt, rtf, odt, xls, xlsx, ppt, pptx, csv, md, html, etc. |
| `images` | jpg, jpeg, png, gif, bmp, tiff, svg, webp, ico, heic, raw, psd, etc. |
| `audio` | mp3, wav, flac, aac, ogg, opus, wma, m4a, midi, aiff, etc. |
| `archives` | zip, rar, 7z, tar, gz, bz2, xz, tgz, cab, iso, dmg, deb, rpm, etc. |
| `custom` | User-defined extensions via `-e` flag |

#### Advanced Usage Patterns

**Automation Scripts:**
```bash
#!/bin/bash
# Daily duplicate cleanup script

# Clean up download folder
./fuzzy_duplicate -t all -s ~/Downloads -T ~/Duplicates/$(date +%Y-%m-%d) -S 0.9

# Remove temp files from projects
./fuzzy_duplicate -t all -s ~/Projects -d -x "tmp,temp,log" -S 0.99
```

**Cron Job Example:**
```bash
# Run weekly on Sundays at 2 AM
0 2 * * 0 /usr/local/bin/fuzzy_duplicate -t all -s /home/user/Downloads -T /backup/duplicates/$(date +\%Y-\%m-\%d) >> /var/log/dedup.log 2>&1
```

**PowerShell Pipeline:**
```powershell
# Find and export duplicates list
fuzzy_duplicate.exe -t documents -s C:\Docs -T C:\Dups -n | Out-File duplicates.txt
```

#### Tips & Best Practices

1. **Always use `--dry-run` first** to preview what will be affected
2. **Start with lower similarity** (0.8) and increase if getting too many false positives
3. **Use content checking (`-c`)** for media files where filenames may differ
4. **Use custom extensions** for specific workflows (e.g., `-e "js,ts"` for code projects)
5. **Exclude temp files** to avoid matching cache/temp files: `-x "tmp,temp,cache"`
6. **Organize by date** when moving: `-T ~/Duplicates/$(date +%Y-%m-%d)`

#### Development Mode

```bash
# Run directly from source
dart run lib/main.dart -t videos -s /path/to/videos -T /path/to/duplicates

# With hot reload during development
flutter run -d linux lib/main.dart -- -t images -s ~/Pictures -T ~/Dups -n
```

---


## 🛠️ Technology Stack

- **Framework:** [Flutter](https://flutter.dev/) - Cross-platform UI toolkit
- **Language:** [Dart](https://dart.dev/) - Optimized for client-side development
- **State Management:** [Provider](https://pub.dev/packages/provider) - Simple and scalable
- **File Hashing:** [xxHash3](https://pub.dev/packages/xxh3) - Ultra-fast non-cryptographic hash
- **Fuzzy Matching:** [fuzzywuzzy](https://pub.dev/packages/fuzzywuzzy) - Levenshtein distance algorithm
- **Icons:** Material Design 3 with custom themes

---

## 🤝 Contributing

We welcome contributions from the community! Here's how you can help:

### Getting Started

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`flutter test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- Follow the existing code style and conventions
- Write clear, concise commit messages
- Update documentation for any new features
- Add tests for new functionality
- Ensure the app runs on both desktop and CLI modes

### Reporting Issues

Found a bug or have a feature request? [Open an issue](https://github.com/mbnoimi/fuzzy_duplicate/issues) with:
- Clear description of the problem
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- Screenshots (if applicable)
- Your platform and version

---

## 🗺️ Roadmap

- [x] Core duplicate detection with fuzzy matching
- [x] Material 3 GUI with dark/light themes
- [x] CLI interface for automation
- [x] Cross-platform builds (Linux, Windows)
- [x] Windows distribution
- [ ] Implement flatpak packaging
- [ ] Publish in flathub.org
- [ ] Multi-language support
- [ ] Github build system integration
- [ ] Set default theme to `system`
- [ ] Use ready made theme package ex. `flex_color_scheme`
- [ ] Add Windows distribution into **choco** package manager.
- [ ] Dynamic layout for landscape/portrait modes
- [ ] Android distribution
- [ ] MacOSX distribution
- [ ] Cloud storage integration

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Flutter Team](https://flutter.dev/) for the amazing framework
- [Material Design](https://m3.material.io/) for the beautiful design system
- [xxHash](https://github.com/Cyan4973/xxHash) for the ultra-fast hashing algorithm
- All [contributors](https://github.com/mbnoimi/fuzzy_duplicate/graphs/contributors) who help improve this project

---

<p align="center">
  Made with ❤️ by a Syrian developer who believes in freedom for Palestine, Ukraine, Syria, and any nation standing against tyrants
</p>

<p align="center">
  ⭐ Star this repo if you find it useful!
</p>
