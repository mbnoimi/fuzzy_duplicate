import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:xxh3/xxh3.dart';

class FileInfo {
  final String filePath;
  final String fileName;
  final int fileSize;
  final String? hash;
  final DateTime? modifiedDate;

  FileInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.hash,
    this.modifiedDate,
  });

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'hash': hash,
      'modifiedDate': modifiedDate?.millisecondsSinceEpoch,
    };
  }

  static FileInfo fromMap(Map<String, dynamic> map) {
    return FileInfo(
      filePath: map['filePath'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      hash: map['hash'],
      modifiedDate: map['modifiedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['modifiedDate'])
          : null,
    );
  }
}

class DuplicateGroup {
  final List<FileInfo> files;
  final double similarity;

  DuplicateGroup({required this.files, required this.similarity});
}

class FuzzyDuplicateService {
  final Map<String, List<String>> _fileTypeExtensions = {
    'videos': [
      'mp4',
      'avi',
      'mkv',
      'mov',
      'wmv',
      'flv',
      'webm',
      'm4v',
      'ogv',
      'ogm',
      '3gp',
      '3g2',
      'ts',
      'mts',
      'm2ts',
      'vob',
      'f4v',
      'asf',
      'rm',
      'rmvb',
      'divx'
    ],
    'documents': [
      'pdf',
      'doc',
      'docx',
      'docm',
      'dot',
      'dotx',
      'dotm',
      'txt',
      'rtf',
      'odt',
      'ott',
      'xls',
      'xlsx',
      'xlsm',
      'ods',
      'ppt',
      'pptx',
      'pptm',
      'odp',
      'csv',
      'tsv',
      'md',
      'markdown',
      'html',
      'htm',
      'xml',
      'xhtml',
      'mhtml',
      'epub',
      'mobi',
      'azw',
      'azw3',
      'tex',
      'log'
    ],
    'images': [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'tiff',
      'tif',
      'svg',
      'webp',
      'ico',
      'cur',
      'ani',
      'heic',
      'heif',
      'raw',
      'nef',
      'cr2',
      'arw',
      'dng',
      'psd',
      'xcf',
      'ai'
    ],
    'audio': [
      'mp3',
      'wav',
      'flac',
      'aac',
      'ogg',
      'oga',
      'opus',
      'wma',
      'm4a',
      'm4b',
      'm4p',
      'm4r',
      'amr',
      'mid',
      'midi',
      'aiff',
      'alac',
      'ape',
      'ra'
    ],
    'archives': [
      'zip',
      'rar',
      '7z',
      'tar',
      'gz',
      'bz2',
      'xz',
      'lzma',
      'zst',
      'tgz',
      'tbz',
      'txz',
      'cab',
      'iso',
      'dmg',
      'deb',
      'rpm',
      'apk'
    ]
  };

  List<String> getExtensionsForType(String fileType,
      [String? customExtension]) {
    if (fileType.toLowerCase() == 'all') {
      return ['*'];
    }
    if (fileType.toLowerCase() == 'custom' &&
        customExtension != null &&
        customExtension.isNotEmpty) {
      return customExtension
          .split(',')
          .map((ext) => ext.trim().toLowerCase().replaceFirst('.', ''))
          .where((ext) => ext.isNotEmpty)
          .toList();
    }
    return _fileTypeExtensions[fileType.toLowerCase()] ?? [];
  }

  List<String> getExcludeExtensions(String? excludeExtensions) {
    if (excludeExtensions == null || excludeExtensions.isEmpty) {
      return [];
    }

    return excludeExtensions
        .split(',')
        .map((ext) => ext.trim().toLowerCase().replaceFirst('.', ''))
        .where((ext) => ext.isNotEmpty)
        .toList();
  }

  // Core hash calculation - shared by both services
  String calculateFileHash(String filePath) {
    try {
      final file = File(filePath);
      final bytes = file.readAsBytesSync();

      // Use xxHash3 which is extremely fast (5-10x faster than MD5)
      // Perfect for non-cryptographic duplicate detection
      final hash = xxh3(bytes);
      return hash.toString();
    } catch (e) {
      return '';
    }
  }

  // Optimized scanDirectory - Uses parallel processing and batch operations
  Future<List<FileInfo>> scanDirectory(
    String directoryPath,
    String fileType, [
    String? customExtension,
    String? excludeExtensions,
    Function(double, String)? onProgress,
  ]) async {
    final extensions = getExtensionsForType(fileType, customExtension);
    final excludeExts = getExcludeExtensions(excludeExtensions);
    final extensionSet = Set<String>.from(extensions);
    final excludeSet = Set<String>.from(excludeExts);
    final hasWildcard = extensionSet.contains('*');

    try {
      // Stage 1: Directory discovery (10%)
      onProgress?.call(0.1, 'Discovering files in directory...');

      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        throw Exception('Directory does not exist: $directoryPath');
      }

      // Collect all file entities first (faster than processing one-by-one)
      final List<FileSystemEntity> entities = await dir
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File)
          .toList();

      // Stage 2: File filtering and processing (20-80%)
      onProgress?.call(0.2, 'Filtering and processing files...');

      final List<FileInfo> files = [];
      final batchSize = 100;

      for (int i = 0; i < entities.length; i += batchSize) {
        final batch = entities.skip(i).take(batchSize);
        final batchResults = await Future.wait(
          batch.map((entity) async {
            final file = entity as File;
            final extension =
                path.extension(file.path).toLowerCase().replaceFirst('.', '');

            // Quick extension check
            if (excludeSet.contains(extension)) return null;
            if (!hasWildcard && !extensionSet.contains(extension)) return null;

            try {
              final stat = await file.stat();
              return FileInfo(
                filePath: file.path,
                fileName: path.basename(file.path),
                fileSize: stat.size,
                modifiedDate: stat.modified,
              );
            } catch (_) {
              return null;
            }
          }),
        );

        files.addAll(batchResults.whereType<FileInfo>());

        // Update progress during file processing (20% to 80%)
        final progress = 0.2 + (i + batchSize) / entities.length * 0.6;
        onProgress?.call(
            progress.clamp(0.2, 0.8), 'Processed ${files.length} files...');
      }

      // Stage 3: Finalizing file list (90%)
      onProgress?.call(0.9, 'Finalizing file list...');

      // Stage 4: Complete (100%)
      onProgress?.call(1.0, 'File scanning complete');

      return files;
    } catch (e) {
      throw Exception('Error scanning directory: $e');
    }
  }

  // Core duplicate detection algorithm - works with both FileInfo and Map data
  Future<List<DuplicateGroup>> findFuzzyDuplicates(
    List<FileInfo> files, {
    double similarityThreshold = 0.8,
    bool checkContent = false,
    double sizeTolerance = 0.5,
    bool ignoreFileSize = false,
    bool matchExtension = false,
    int minFileCount = 2,
    Function(double, [String?])? onProgress,
    bool enableUIYielding = true,
  }) async {
    final List<DuplicateGroup> duplicateGroups = [];
    final Set<int> processedFiles = {};

    // Stage 1: Preparation (0-10%)
    onProgress?.call(0.0, 'Preparing duplicate detection...');

    // Stage 2: Hash computation if needed (10-30%)
    if (checkContent) {
      onProgress?.call(0.1, 'Computing file hashes...');
      final batchSize = 50;
      for (int i = 0; i < files.length; i += batchSize) {
        final endIdx = (i + batchSize).clamp(0, files.length);

        // Process hashes in parallel batches
        await Future.wait(
          List.generate(endIdx - i, (idx) async {
            final fileIdx = i + idx;
            if (!processedFiles.contains(fileIdx)) {
              final hash = await Future(
                  () => calculateFileHash(files[fileIdx].filePath));
              files[fileIdx] = FileInfo(
                filePath: files[fileIdx].filePath,
                fileName: files[fileIdx].fileName,
                fileSize: files[fileIdx].fileSize,
                hash: hash,
                modifiedDate: files[fileIdx].modifiedDate,
              );
            }
          }),
        );

        // Update hash computation progress (10% to 30%)
        final progress = 0.1 + (i + batchSize) / files.length * 0.2;
        onProgress?.call(progress.clamp(0.1, 0.3),
            'Hashed ${i + batchSize > files.length ? files.length : i + batchSize}/${files.length} files...');

        if (enableUIYielding) {
          await Future.delayed(Duration.zero);
        }
      }
    }

    // Stage 3: Grouping and indexing (30-40%)
    onProgress?.call(0.3, 'Indexing files for comparison...');

    // Create lookup maps for faster comparison
    final Map<String, List<int>> sizeGroups = {};
    final Map<String, List<int>> extensionGroups = {};

    for (int i = 0; i < files.length; i++) {
      // Group by size buckets (within tolerance)
      if (!ignoreFileSize) {
        final sizeBucket = (files[i].fileSize / 1024).round();
        sizeGroups.putIfAbsent('$sizeBucket', () => []).add(i);
      }

      // Group by extension if needed
      if (matchExtension) {
        final ext = path.extension(files[i].fileName).toLowerCase();
        extensionGroups.putIfAbsent(ext, () => []).add(i);
      }
    }

    // Stage 4: Core comparison process (40-90%)
    onProgress?.call(0.4, 'Finding similar files...');

    // Cache basename extraction and similarity calculations
    final Map<int, String> basenameCache = {};
    final Map<String, double> similarityCache = {};

    String getBasename(int idx) {
      return basenameCache.putIfAbsent(
        idx,
        () => path.basenameWithoutExtension(files[idx].fileName),
      );
    }

    for (int i = 0; i < files.length; i++) {
      if (processedFiles.contains(i)) continue;

      // Report current file being processed with stage progress (40% to 90%)
      final stageProgress = 0.4 + (i / files.length) * 0.5;
      onProgress?.call(stageProgress, files[i].fileName);

      // Yield control to prevent UI freezing (only for main thread)
      if (enableUIYielding && i % 10 == 0) {
        await Future.delayed(Duration.zero);
      }

      final List<FileInfo> similarFiles = [files[i]];
      final String baseName = getBasename(i);

      // Determine comparison candidates based on constraints
      List<int> candidates;
      if (matchExtension) {
        final ext = path.extension(files[i].fileName).toLowerCase();
        candidates = extensionGroups[ext] ?? [];
      } else if (!ignoreFileSize) {
        final sizeBucket = (files[i].fileSize / 1024).round();
        candidates = [];
        // Check nearby size buckets
        for (int offset = -1; offset <= 1; offset++) {
          candidates.addAll(sizeGroups['${sizeBucket + offset}'] ?? []);
        }
      } else {
        candidates = List.generate(files.length, (idx) => idx);
      }

      for (final j in candidates) {
        if (j <= i || processedFiles.contains(j)) continue;

        // Yield control frequently to prevent UI freezing (only for main thread)
        if (enableUIYielding && j % 20 == 0) {
          await Future.delayed(Duration.zero);
        }

        bool isSimilar = false;

        if (checkContent && files[i].hash != null && files[j].hash != null) {
          isSimilar = files[i].hash == files[j].hash;
        } else {
          // Cache similarity calculation
          final cacheKey = '$i-$j';
          final nameSimilarity = similarityCache.putIfAbsent(
            cacheKey,
            () => ratio(baseName, getBasename(j)) / 100.0,
          );

          // Early termination if name similarity is too low
          if (nameSimilarity < similarityThreshold) continue;

          final sizeDifference = (files[i].fileSize - files[j].fileSize).abs() /
              files[i].fileSize.clamp(1, double.infinity);

          final nameMatch = nameSimilarity >= 0.99;
          final sizeMatch = ignoreFileSize ||
              (nameMatch && !ignoreFileSize) ||
              sizeDifference <= sizeTolerance;

          isSimilar = sizeMatch;

          if (isSimilar && matchExtension) {
            final ext1 = path.extension(files[i].fileName).toLowerCase();
            final ext2 = path.extension(files[j].fileName).toLowerCase();
            isSimilar = ext1 == ext2;
          }
        }

        if (isSimilar) {
          similarFiles.add(files[j]);
          processedFiles.add(j);
        }
      }

      if (similarFiles.length >= minFileCount) {
        final avgSimilarity = similarFiles.length > 2
            ? 0.9
            : similarityCache['$i-${files.indexOf(similarFiles[1])}'] ?? 0.9;

        duplicateGroups.add(
          DuplicateGroup(files: similarFiles, similarity: avgSimilarity),
        );
      }

      processedFiles.add(i);

      if (enableUIYielding && i % 50 == 0) {
        final stageProgress = 0.4 + (i / files.length) * 0.5;
        onProgress?.call(stageProgress, files[i].fileName);
        await Future.delayed(Duration.zero);
      }
    }

    // Stage 5: Finalizing results (90-95%)
    onProgress?.call(0.9, 'Finalizing duplicate groups...');

    // Stage 6: Complete (95-100%)
    onProgress?.call(0.95, 'Preparing results for display...');

    // Allow time for UI to update with "Displaying results" message
    if (enableUIYielding) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    onProgress?.call(1.0, 'Duplicate detection complete');

    return duplicateGroups;
  }

  Future<void> moveFiles(List<String> filePaths, String targetDirectory) async {
    final targetDir = Directory(targetDirectory);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        final fileName = path.basename(filePath);
        final targetPath = path.join(targetDirectory, fileName);

        await file.rename(targetPath);
      } catch (e) {
        throw Exception('Failed to move $filePath: $e');
      }
    }
  }

  Future<void> deleteFiles(List<String> filePaths) async {
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        await file.delete();
      } catch (e) {
        throw Exception('Failed to delete $filePath: $e');
      }
    }
  }
}
