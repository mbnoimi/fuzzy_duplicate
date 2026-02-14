import 'dart:async';
import 'dart:isolate';
import 'package:path/path.dart' as path;
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import '../core_service.dart';

class IsolateMessage {
  final List<Map<String, dynamic>> files;
  final double similarityThreshold;
  final bool checkContent;
  final double sizeTolerance;
  final bool ignoreFileSize;
  final bool matchExtension;
  final int minFileCount;
  final SendPort responsePort;
  final int startIndex;
  final int endIndex;
  final bool useWindowing;

  IsolateMessage({
    required this.files,
    required this.similarityThreshold,
    required this.checkContent,
    required this.sizeTolerance,
    required this.ignoreFileSize,
    required this.matchExtension,
    required this.minFileCount,
    required this.responsePort,
    this.startIndex = 0,
    this.endIndex = -1,
    this.useWindowing = true,
  });
}

class ProgressMessage {
  final double progress;
  final String fileName;

  ProgressMessage({required this.progress, required this.fileName});
}

class ResultMessage {
  final List<Map<String, dynamic>> duplicateGroups;
  final String? error;

  ResultMessage({required this.duplicateGroups, this.error});
}

class PartitionResult {
  final List<Map<String, dynamic>> duplicateGroups;
  final int partitionId;

  PartitionResult({required this.duplicateGroups, required this.partitionId});
}

// Global abort flag for the isolate
bool _abortRequested = false;

// Core service instance for isolate operations
final FuzzyDuplicateService _coreService = FuzzyDuplicateService();

// Number of worker isolates to use (based on CPU cores)
const int _numWorkerIsolates = 4;

// Window size for windowing strategy (only compare files within this range)
const int _comparisonWindowSize = 100;

// Isolate entry point for parallel processing
void workerIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    if (message is IsolateMessage) {
      try {
        _abortRequested = false;
        final duplicateGroups = await _findFuzzyDuplicatesInIsolate(
          message.files,
          similarityThreshold: message.similarityThreshold,
          checkContent: message.checkContent,
          sizeTolerance: message.sizeTolerance,
          ignoreFileSize: message.ignoreFileSize,
          matchExtension: message.matchExtension,
          minFileCount: message.minFileCount,
          startIndex: message.startIndex,
          endIndex: message.endIndex,
          useWindowing: message.useWindowing,
          onProgress: (progress, fileName) {
            message.responsePort
                .send(ProgressMessage(progress: progress, fileName: fileName));
          },
        );

        if (!_abortRequested) {
          message.responsePort
              .send(ResultMessage(duplicateGroups: duplicateGroups));
        } else {
          message.responsePort
              .send(ResultMessage(duplicateGroups: [], error: 'Scan aborted'));
        }
      } catch (e) {
        message.responsePort
            .send(ResultMessage(duplicateGroups: [], error: e.toString()));
      }
    }
  });
}

// Isolate-based duplicate finder that uses core service logic
Future<List<Map<String, dynamic>>> _findFuzzyDuplicatesInIsolate(
  List<Map<String, dynamic>> files, {
  double similarityThreshold = 0.8,
  bool checkContent = false,
  double sizeTolerance = 0.5,
  bool ignoreFileSize = false,
  bool matchExtension = false,
  int minFileCount = 2,
  int startIndex = 0,
  int endIndex = -1,
  bool useWindowing = true,
  Function(double, String)? onProgress,
}) async {
  // Determine the range to process
  final actualEndIndex =
      endIndex < 0 ? files.length : endIndex.clamp(0, files.length);
  final actualStartIndex = startIndex.clamp(0, files.length);

  if (actualStartIndex >= actualEndIndex) {
    return [];
  }

  // Convert map data to FileInfo objects for core service processing
  final List<FileInfo> fileInfoList =
      files.map((fileMap) => FileInfo.fromMap(fileMap)).toList();

  // Sort files by basename for windowing strategy
  // This groups similar names together alphabetically
  final List<int> sortedIndices = List.generate(fileInfoList.length, (i) => i);
  sortedIndices.sort((a, b) {
    final nameA =
        path.basenameWithoutExtension(fileInfoList[a].fileName).toLowerCase();
    final nameB =
        path.basenameWithoutExtension(fileInfoList[b].fileName).toLowerCase();
    return nameA.compareTo(nameB);
  });

  // Create reverse mapping from original index to sorted position
  final Map<int, int> sortedPositionMap = {};
  for (int i = 0; i < sortedIndices.length; i++) {
    sortedPositionMap[sortedIndices[i]] = i;
  }

  // Use core service for hash computation (if needed)
  if (checkContent) {
    onProgress?.call(0.1, 'Computing file hashes...');
    for (int i = actualStartIndex; i < actualEndIndex; i++) {
      if (_abortRequested) break;

      final sortedIdx = sortedIndices[i];
      if (fileInfoList[sortedIdx].hash == null) {
        final hash = await _coreService
            .calculateFileHash(fileInfoList[sortedIdx].filePath);
        fileInfoList[sortedIdx] = FileInfo(
          filePath: fileInfoList[sortedIdx].filePath,
          fileName: fileInfoList[sortedIdx].fileName,
          fileSize: fileInfoList[sortedIdx].fileSize,
          hash: hash,
          modifiedDate: fileInfoList[sortedIdx].modifiedDate,
        );
      }

      // Update original maps with computed hashes
      files[sortedIdx]['hash'] = fileInfoList[sortedIdx].hash;

      // Update hash computation progress (10% to 30%)
      final progress = 0.1 +
          (i - actualStartIndex + 1) /
              (actualEndIndex - actualStartIndex) *
              0.2;
      onProgress?.call(progress.clamp(0.1, 0.3),
          'Hashed ${i - actualStartIndex + 1}/${actualEndIndex - actualStartIndex} files...');
    }
  }

  // Stage 3: Grouping and indexing (30-40%)
  onProgress?.call(0.3, 'Indexing files for comparison...');

  // Create lookup maps for faster comparison
  final Map<String, List<int>> sizeGroups = {};
  final Map<String, List<int>> extensionGroups = {};

  for (int i = actualStartIndex; i < actualEndIndex; i++) {
    final sortedIdx = sortedIndices[i];

    // Group by size buckets (within tolerance)
    if (!ignoreFileSize) {
      final sizeBucket = ((fileInfoList[sortedIdx].fileSize) / 1024).round();
      sizeGroups.putIfAbsent('$sizeBucket', () => []).add(sortedIdx);
    }

    // Group by extension if needed
    if (matchExtension) {
      final ext =
          path.extension(fileInfoList[sortedIdx].fileName).toLowerCase();
      extensionGroups.putIfAbsent(ext, () => []).add(sortedIdx);
    }
  }

  // Cache basename extraction and similarity calculations
  final Map<int, String> basenameCache = {};
  final Map<String, double> similarityCache = {};

  String getBasename(int idx) {
    return basenameCache.putIfAbsent(
      idx,
      () => path.basenameWithoutExtension(fileInfoList[idx].fileName),
    );
  }

  // Stage 4: Core comparison process (40-90%)
  onProgress?.call(0.4, 'Finding similar files...');
  final List<Map<String, dynamic>> duplicateGroups = [];
  final Set<int> processedFiles = {};

  for (int i = actualStartIndex; i < actualEndIndex; i++) {
    if (_abortRequested) break;

    final sortedIdx = sortedIndices[i];
    if (processedFiles.contains(sortedIdx)) continue;

    // Report current file being processed with stage progress (40% to 90%)
    // Throttle updates to avoid excessive UI rebuilds (every 50 files)
    if ((i - actualStartIndex) % 50 == 0 || i == actualEndIndex - 1) {
      final stageProgress = 0.4 +
          (i - actualStartIndex) / (actualEndIndex - actualStartIndex) * 0.5;
      onProgress?.call(stageProgress, fileInfoList[sortedIdx].fileName);
    }

    final List<Map<String, dynamic>> similarFiles = [files[sortedIdx]];
    final String baseName = getBasename(sortedIdx);

    // Determine comparison candidates based on constraints
    List<int> candidates;
    if (matchExtension) {
      final ext =
          path.extension(fileInfoList[sortedIdx].fileName).toLowerCase();
      candidates = extensionGroups[ext] ?? [];
    } else if (!ignoreFileSize) {
      final sizeBucket = ((fileInfoList[sortedIdx].fileSize) / 1024).round();
      candidates = [];
      // Check nearby size buckets
      for (int offset = -1; offset <= 1; offset++) {
        candidates.addAll(sizeGroups['${sizeBucket + offset}'] ?? []);
      }
    } else {
      // For windowing strategy, only consider files within window
      if (useWindowing) {
        candidates = [];
        final windowStart = (i + 1).clamp(actualStartIndex, actualEndIndex);
        final windowEnd =
            (i + _comparisonWindowSize).clamp(actualStartIndex, actualEndIndex);
        for (int j = windowStart; j < windowEnd; j++) {
          candidates.add(sortedIndices[j]);
        }
      } else {
        candidates = List.generate(files.length, (idx) => idx);
      }
    }

    // Apply windowing constraint to candidates
    if (useWindowing && !matchExtension && !ignoreFileSize) {
      // Filter candidates to only those within window
      final windowEnd =
          (i + _comparisonWindowSize).clamp(actualStartIndex, actualEndIndex);
      candidates = candidates.where((idx) {
        final pos = sortedPositionMap[idx] ?? -1;
        return pos > i && pos < windowEnd;
      }).toList();
    }

    for (final j in candidates) {
      if (j == sortedIdx || processedFiles.contains(j)) continue;

      // For windowing strategy, skip if j is before current position
      if (useWindowing) {
        final jPos = sortedPositionMap[j] ?? -1;
        if (jPos <= i) continue;
      }

      bool isSimilar = false;

      if (checkContent &&
          files[sortedIdx]['hash'] != null &&
          files[j]['hash'] != null) {
        isSimilar = files[sortedIdx]['hash'] == files[j]['hash'];
      } else {
        // Cache similarity calculation
        final cacheKey = '$sortedIdx-$j';
        final nameSimilarity = similarityCache.putIfAbsent(
          cacheKey,
          () => ratio(baseName, getBasename(j)) / 100.0,
        );

        // Early termination if name similarity is too low
        if (nameSimilarity < similarityThreshold) continue;

        final sizeDifference =
            ((fileInfoList[sortedIdx].fileSize) - (fileInfoList[j].fileSize))
                    .abs() /
                (fileInfoList[sortedIdx].fileSize).clamp(1, double.infinity);

        final nameMatch = nameSimilarity >= 0.99;
        final sizeMatch = ignoreFileSize ||
            (nameMatch && !ignoreFileSize) ||
            sizeDifference <= sizeTolerance;

        isSimilar = sizeMatch;

        if (isSimilar && matchExtension) {
          final ext1 =
              path.extension(fileInfoList[sortedIdx].fileName).toLowerCase();
          final ext2 = path.extension(fileInfoList[j].fileName).toLowerCase();
          isSimilar = ext1 == ext2;
        }
      }

      if (isSimilar) {
        similarFiles.add(files[j]);
        processedFiles.add(j);
      }
    }

    if (similarFiles.length >= minFileCount) {
      // Calculate average similarity for the group
      double avgSimilarity = 0.9;
      if (similarFiles.length == 2) {
        // For pairs, use the cached similarity between the two files
        final firstPath = similarFiles[0]['filePath'] as String;
        final secondPath = similarFiles[1]['filePath'] as String;

        // Find indices in fileInfoList
        int? firstIdx, secondIdx;
        for (int k = 0; k < fileInfoList.length; k++) {
          if (fileInfoList[k].filePath == firstPath) firstIdx = k;
          if (fileInfoList[k].filePath == secondPath) secondIdx = k;
          if (firstIdx != null && secondIdx != null) break;
        }

        if (firstIdx != null && secondIdx != null) {
          avgSimilarity = similarityCache['$firstIdx-$secondIdx'] ??
              similarityCache['$secondIdx-$firstIdx'] ??
              0.9;
        }
      }

      duplicateGroups.add({
        'files': similarFiles,
        'similarity': avgSimilarity,
      });
    }

    processedFiles.add(sortedIdx);
  }

  // Stage 5: Finalizing results (90-95%)
  onProgress?.call(0.9, 'Finalizing duplicate groups...');

  // Stage 6: Complete (95-100%)
  onProgress?.call(0.95, 'Preparing results for display...');

  return duplicateGroups;
}

class IsolateFuzzyDuplicateService {
  final List<Isolate> _isolates = [];
  final List<ReceivePort> _receivePorts = [];
  final List<SendPort> _sendPorts = [];
  bool _isInitialized = false;

  Future<void> _ensureIsolates() async {
    if (_isInitialized) return;

    // Create multiple worker isolates
    for (int i = 0; i < _numWorkerIsolates; i++) {
      final receivePort = ReceivePort();
      _receivePorts.add(receivePort);

      final isolate = await Isolate.spawn(
        workerIsolateEntry,
        receivePort.sendPort,
        debugName: 'WorkerIsolate-$i',
      );
      _isolates.add(isolate);

      final completer = Completer<SendPort>();
      receivePort.listen((message) {
        if (message is SendPort && !completer.isCompleted) {
          completer.complete(message);
        }
      });

      final sendPort = await completer.future;
      _sendPorts.add(sendPort);
    }

    _isInitialized = true;
  }

  Future<List<Map<String, dynamic>>> findFuzzyDuplicates(
    List<Map<String, dynamic>> files, {
    double similarityThreshold = 0.8,
    bool checkContent = false,
    double sizeTolerance = 0.5,
    bool ignoreFileSize = false,
    bool matchExtension = false,
    int minFileCount = 2,
    Function(double, String)? onProgress,
  }) async {
    await _ensureIsolates();

    // For small datasets, use single isolate to avoid overhead
    if (files.length < 500) {
      return await _processWithSingleIsolate(
        files,
        similarityThreshold: similarityThreshold,
        checkContent: checkContent,
        sizeTolerance: sizeTolerance,
        ignoreFileSize: ignoreFileSize,
        matchExtension: matchExtension,
        minFileCount: minFileCount,
        onProgress: onProgress,
      );
    }

    // Partition files across multiple isolates
    return await _processWithParallelIsolates(
      files,
      similarityThreshold: similarityThreshold,
      checkContent: checkContent,
      sizeTolerance: sizeTolerance,
      ignoreFileSize: ignoreFileSize,
      matchExtension: matchExtension,
      minFileCount: minFileCount,
      onProgress: onProgress,
    );
  }

  Future<List<Map<String, dynamic>>> _processWithSingleIsolate(
    List<Map<String, dynamic>> files, {
    required double similarityThreshold,
    required bool checkContent,
    required double sizeTolerance,
    required bool ignoreFileSize,
    required bool matchExtension,
    required int minFileCount,
    Function(double, String)? onProgress,
  }) async {
    final responsePort = ReceivePort();
    final completer = Completer<List<Map<String, dynamic>>>();

    late StreamSubscription subscription;
    subscription = responsePort.listen((message) {
      if (message is ProgressMessage) {
        onProgress?.call(message.progress, message.fileName);
      } else if (message is ResultMessage) {
        subscription.cancel();
        responsePort.close();
        if (message.error != null) {
          completer.completeError(Exception(message.error));
        } else {
          completer.complete(message.duplicateGroups);
        }
      }
    });

    final scanMessage = IsolateMessage(
      files: files,
      similarityThreshold: similarityThreshold,
      checkContent: checkContent,
      sizeTolerance: sizeTolerance,
      ignoreFileSize: ignoreFileSize,
      matchExtension: matchExtension,
      minFileCount: minFileCount,
      responsePort: responsePort.sendPort,
      startIndex: 0,
      endIndex: files.length,
      useWindowing: true,
    );

    _sendPorts[0].send(scanMessage);
    return await completer.future;
  }

  Future<List<Map<String, dynamic>>> _processWithParallelIsolates(
    List<Map<String, dynamic>> files, {
    required double similarityThreshold,
    required bool checkContent,
    required double sizeTolerance,
    required bool ignoreFileSize,
    required bool matchExtension,
    required int minFileCount,
    Function(double, String)? onProgress,
  }) async {
    final List<Future<PartitionResult>> partitionFutures = [];
    final partitionSize = (files.length / _numWorkerIsolates).ceil();

    // Create partitions and process in parallel
    for (int partitionId = 0; partitionId < _numWorkerIsolates; partitionId++) {
      final startIndex = partitionId * partitionSize;
      final endIndex =
          ((partitionId + 1) * partitionSize).clamp(0, files.length);

      if (startIndex >= files.length) break;

      final future = _processPartition(
        files: files,
        partitionId: partitionId,
        startIndex: startIndex,
        endIndex: endIndex,
        similarityThreshold: similarityThreshold,
        checkContent: checkContent,
        sizeTolerance: sizeTolerance,
        ignoreFileSize: ignoreFileSize,
        matchExtension: matchExtension,
        minFileCount: minFileCount,
        onProgress: (progress, fileName) {
          // Calculate overall progress across all partitions
          final baseProgress = partitionId / _numWorkerIsolates;
          final partitionProgress = progress / _numWorkerIsolates;
          onProgress?.call(baseProgress + partitionProgress, fileName);
        },
      );

      partitionFutures.add(future);
    }

    // Wait for all partitions to complete
    final results = await Future.wait(partitionFutures);

    // Merge results from all partitions
    final allGroups = <Map<String, dynamic>>[];
    for (final result in results) {
      allGroups.addAll(result.duplicateGroups);
    }

    // Deduplicate groups that might have been found in multiple partitions
    return _mergeDuplicateGroups(allGroups);
  }

  Future<PartitionResult> _processPartition({
    required List<Map<String, dynamic>> files,
    required int partitionId,
    required int startIndex,
    required int endIndex,
    required double similarityThreshold,
    required bool checkContent,
    required double sizeTolerance,
    required bool ignoreFileSize,
    required bool matchExtension,
    required int minFileCount,
    Function(double, String)? onProgress,
  }) async {
    final responsePort = ReceivePort();
    final completer = Completer<PartitionResult>();

    late StreamSubscription subscription;
    subscription = responsePort.listen((message) {
      if (message is ProgressMessage) {
        onProgress?.call(message.progress, message.fileName);
      } else if (message is ResultMessage) {
        subscription.cancel();
        responsePort.close();
        if (message.error != null) {
          completer.completeError(Exception(message.error));
        } else {
          completer.complete(PartitionResult(
            duplicateGroups: message.duplicateGroups,
            partitionId: partitionId,
          ));
        }
      }
    });

    final scanMessage = IsolateMessage(
      files: files,
      similarityThreshold: similarityThreshold,
      checkContent: checkContent,
      sizeTolerance: sizeTolerance,
      ignoreFileSize: ignoreFileSize,
      matchExtension: matchExtension,
      minFileCount: minFileCount,
      responsePort: responsePort.sendPort,
      startIndex: startIndex,
      endIndex: endIndex,
      useWindowing: true,
    );

    _sendPorts[partitionId % _sendPorts.length].send(scanMessage);
    return await completer.future;
  }

  List<Map<String, dynamic>> _mergeDuplicateGroups(
    List<Map<String, dynamic>> groups,
  ) {
    // Use file path as key to identify duplicate groups
    final Map<String, Map<String, dynamic>> uniqueGroups = {};

    for (final group in groups) {
      final files = group['files'] as List;
      if (files.isEmpty) continue;

      // Create a unique key from all file paths in the group
      final paths = files
          .map((f) => f is Map ? f['filePath'] as String : '')
          .where((p) => p.isNotEmpty)
          .toList()
        ..sort();
      final key = paths.join('|');

      if (!uniqueGroups.containsKey(key)) {
        uniqueGroups[key] = group;
      }
    }

    return uniqueGroups.values.toList();
  }

  void dispose() {
    for (final isolate in _isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    for (final port in _receivePorts) {
      port.close();
    }
    _isolates.clear();
    _receivePorts.clear();
    _sendPorts.clear();
    _isInitialized = false;
  }

  // Method to abort isolate operations
  void abort() {
    _abortRequested = true;
  }
}
