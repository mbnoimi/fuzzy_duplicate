import 'dart:io';
import 'dart:typed_data';
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

  // Core hash calculation - uses chunked reading to handle large files
  // without loading entire file into memory (max 1MB chunks)
  Future<String> calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();

      // For small files (< 10MB), use simple hash
      if (fileSize < 10 * 1024 * 1024) {
        final bytes = await file.readAsBytes();
        return xxh3(bytes).toString();
      }

      // For large files, sample multiple chunks
      final chunks = <Uint8List>[];
      final raf = await file.open();

      // Read first 1MB
      chunks.add(await raf.read(1024 * 1024));

      // Read middle chunk
      await raf.setPosition(fileSize ~/ 2);
      chunks.add(await raf.read(1024 * 1024));

      // Read last 1MB
      await raf.setPosition(fileSize - 1024 * 1024);
      chunks.add(await raf.read(1024 * 1024));

      await raf.close();

      // Combine chunks and hash
      final totalLength =
          chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final combined = Uint8List(totalLength);
      var offset = 0;
      for (final chunk in chunks) {
        combined.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      return xxh3(combined).toString();
    } catch (e) {
      return '';
    }
  }

  // Optimized scanDirectory - Uses streaming to handle large directories
  // without loading all files into memory at once
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

      // Stage 2: File filtering and processing using streaming (10-90%)
      onProgress?.call(0.2, 'Filtering and processing files...');

      final List<FileInfo> files = [];
      final batchSize = 100;
      var currentBatch = <Future<FileInfo?>>[];
      var totalProcessed = 0;

      // Use streaming to process files as they're discovered
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;

        final extension =
            path.extension(entity.path).toLowerCase().replaceFirst('.', '');

        // Quick extension check
        if (excludeSet.contains(extension)) continue;
        if (!hasWildcard && !extensionSet.contains(extension)) continue;

        // Add to batch
        currentBatch.add(Future(() async {
          try {
            final stat = await entity.stat();
            return FileInfo(
              filePath: entity.path,
              fileName: path.basename(entity.path),
              fileSize: stat.size,
              modifiedDate: stat.modified,
            );
          } catch (_) {
            return null;
          }
        }));

        // Process batch when it reaches batchSize
        if (currentBatch.length >= batchSize) {
          final batchResults = await Future.wait(currentBatch);
          files.addAll(batchResults.whereType<FileInfo>());
          totalProcessed += currentBatch.length;
          currentBatch = [];

          // Update progress (capped at 90% since we don't know total count)
          onProgress?.call(
              0.2 + (totalProcessed / (totalProcessed + 1000)).clamp(0.0, 0.6),
              'Processed ${files.length} files...');
        }
      }

      // Process remaining items in batch
      if (currentBatch.isNotEmpty) {
        final batchResults = await Future.wait(currentBatch);
        files.addAll(batchResults.whereType<FileInfo>());
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

    // FAST PATH: For 100% similarity without content check, use exact name matching
    // This avoids expensive fuzzy matching and is O(n) instead of O(n²)
    if (similarityThreshold >= 0.999 && !checkContent) {
      onProgress?.call(0.2, 'Using fast exact name matching...');

      final Map<String, List<FileInfo>> nameGroups = {};

      for (int i = 0; i < files.length; i++) {
        final baseName = path.basenameWithoutExtension(files[i].fileName);
        final key = matchExtension
            ? '$baseName${path.extension(files[i].fileName).toLowerCase()}'
            : baseName;
        nameGroups.putIfAbsent(key, () => []).add(files[i]);

        if (enableUIYielding && i % 100 == 0) {
          onProgress?.call(0.2 + (i / files.length) * 0.7, 'Grouping files...');
          await Future.delayed(Duration.zero);
        }
      }

      onProgress?.call(0.9, 'Creating duplicate groups...');

      for (final entry in nameGroups.entries) {
        if (entry.value.length >= minFileCount) {
          // Filter by size tolerance if needed
          if (!ignoreFileSize && entry.value.length > 1) {
            final filtered = <FileInfo>[];
            for (int i = 0; i < entry.value.length; i++) {
              bool hasSimilarSize = false;
              for (int j = 0; j < entry.value.length; j++) {
                if (i != j) {
                  final sizeDiff =
                      (entry.value[i].fileSize - entry.value[j].fileSize)
                              .abs() /
                          entry.value[i].fileSize.clamp(1, double.infinity);
                  if (sizeDiff <= sizeTolerance) {
                    hasSimilarSize = true;
                    break;
                  }
                }
              }
              if (hasSimilarSize || entry.value.length == 1) {
                filtered.add(entry.value[i]);
              }
            }
            if (filtered.length >= minFileCount) {
              duplicateGroups.add(
                DuplicateGroup(files: filtered, similarity: 1.0),
              );
            }
          } else {
            duplicateGroups.add(
              DuplicateGroup(files: entry.value, similarity: 1.0),
            );
          }
        }
      }

      onProgress?.call(1.0, 'Duplicate detection complete');
      return duplicateGroups;
    }

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
              final hash = await calculateFileHash(files[fileIdx].filePath);
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

    // Cache basename extraction only (not similarity - to save memory)
    final Map<int, String> basenameCache = {};

    String getBasename(int idx) {
      return basenameCache.putIfAbsent(
        idx,
        () => path.basenameWithoutExtension(files[idx].fileName),
      );
    }

    for (int i = 0; i < files.length; i++) {
      if (processedFiles.contains(i)) continue;

      // Report current file being processed with stage progress (40% to 90%)
      // Throttle updates to avoid excessive UI rebuilds (every 50 files)
      if (i % 50 == 0 || i == files.length - 1) {
        final stageProgress = 0.4 + (i / files.length) * 0.5;
        onProgress?.call(stageProgress, files[i].fileName);
      }

      // Yield control to prevent UI freezing (only for main thread)
      if (enableUIYielding && i % 10 == 0) {
        await Future.delayed(Duration.zero);
      }

      final List<FileInfo> similarFiles = [files[i]];
      final String baseName = getBasename(i);
      double? firstSimilarity;

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
        double nameSimilarity = 0.0;

        if (checkContent && files[i].hash != null && files[j].hash != null) {
          isSimilar = files[i].hash == files[j].hash;
          nameSimilarity = 1.0; // Hash match means 100% similar
        } else {
          // Compute similarity on-the-fly (no cache to save memory)
          nameSimilarity = ratio(baseName, getBasename(j)) / 100.0;

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
          firstSimilarity ??= nameSimilarity;
        }
      }

      if (similarFiles.length >= minFileCount) {
        final avgSimilarity =
            similarFiles.length > 2 ? 0.9 : (firstSimilarity ?? 0.9);

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
