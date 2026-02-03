# Fuzzy Duplicate Finder

<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/0/00/Flag_of_Palestine.svg" alt="Palestine Flag" width="60" height="40">
  <img src="https://upload.wikimedia.org/wikipedia/commons/4/49/Flag_of_Ukraine.svg" alt="Ukraine Flag" width="60" height="40">
</p>

<p align="center">
  <b>🕊️ We stand in solidarity with Palestine and Ukraine 🕊️</b>
</p>

<p align="center">
  <sub>Free Palestine • Peace for Ukraine</sub>
</p>

<br>

<p align="center">
  <img src="assets/icons/logo.svg" alt="Fuzzy Duplicate Finder Logo" width="120" height="120">
</p>

<p align="center">
  A cross-platform duplicate file finder with fuzzy matching and an intuitive GUI & CLI interface
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#building">Building</a> •
  <a href="#contributing">Contributing</a>
</p>

---

## ✨ Features

- **🎯 Fuzzy Matching** - Find duplicates by similar filenames using intelligent string matching
- **🔐 Content Verification** - Optional xxHash3-based content checking for 100% accuracy
- **📁 Multiple File Types** - Support for videos, documents, images, audio, archives, and custom extensions
- **🖥️ Dual Interface** - Beautiful Material 3 GUI and powerful CLI for automation
- **⚡ High Performance** - Optimized scanning with parallel processing and progress tracking
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

Perfect for automation, scripts, and headless servers:

**Linux/macOS:**
```bash
# Move duplicate videos to another folder
./fuzzy_duplicate -t videos -s /home/user/videos -T /home/user/duplicates

# Delete duplicate documents with 90% similarity
./fuzzy_duplicate -t documents -s /home/user/documents -d -S 0.9

# Find duplicates by content (slower but more accurate)
./fuzzy_duplicate -t images -s /home/user/pictures -T /home/user/dups -c

# Find all file duplicates
./fuzzy_duplicate -t all -s /home/user/downloads -T /home/user/duplicates

# Find duplicates with custom extension
./fuzzy_duplicate -t custom -e log -s /home/user/logs -T /home/user/duplicate_logs
```

**Windows:**
```powershell
# Move duplicate videos to another folder
fuzzy_duplicate.exe -t videos -s C:\Users\user\videos -T C:\Users\user\duplicates

# Delete duplicate documents with 90% similarity
fuzzy_duplicate.exe -t documents -s C:\Users\user\documents -d -S 0.9

# Find duplicates by content (slower but more accurate)
fuzzy_duplicate.exe -t images -s C:\Users\user\pictures -T C:\Users\user\dups -c

# Find all file duplicates
fuzzy_duplicate.exe -t all -s C:\Users\user\downloads -T C:\Users\user\duplicates

# Find duplicates with custom extension
fuzzy_duplicate.exe -t custom -e log -s C:\Users\user\logs -T C:\Users\user\duplicate_logs
```

**Development (from source):**
```bash
# Run directly with Dart/Flutter
dart run lib/main.dart -t videos -s /path/to/videos -T /path/to/duplicates
```

#### CLI Options

| Option | Short | Description | Required |
|--------|-------|-------------|----------|
| `--type` | `-t` | File type (all, videos, documents, images, audio, archives, custom) | ✅ |
| `--source` | `-s` | Source directory path | ✅ |
| `--target` | `-T` | Target directory path (for moving) | * |
| `--extension` | `-e` | Custom extension (when type=custom) | * |
| `--similarity` | `-S` | Similarity threshold 0.5-1.0 (default: 0.8) | ❌ |
| `--content` | `-c` | Check file content (slower) | ❌ |
| `--delete` | `-d` | Delete duplicates instead of moving | * |
| `--help` | `-h` | Show help message | ❌ |

*Either `--target` or `--delete` is required

---

## 🏗️ Building & Packaging

### Linux

```bash
# Build and package for Linux
chmod +x build_linux.sh
./build_linux.sh
```

Creates a `.tar.gz` archive in the `build/` directory.

### Windows

```powershell
# Build and package for Windows
.\build_windows.ps1
```

Creates a portable executable in the `build/` directory.

### Flatpak (Linux)

Coming soon! See our [Roadmap](#roadmap).

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
- [ ] Flatpak packaging for Linux
- [ ] macOS support
- [ ] Multi-language support (i18n)
- [ ] Android distribution
- [ ] Cloud storage integration
- [ ] Advanced filtering and search
- [ ] Duplicate preview (images, videos)

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
  Made with ❤️ by the open source community
</p>

<p align="center">
  ⭐ Star this repo if you find it useful!
</p>
