import 'dart:async';
import 'dart:isolate';
import 'dart:io';
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

  IsolateMessage({
    required this.files,
    required this.similarityThreshold,
    required this.checkContent,
    required this.sizeTolerance,
    required this.ignoreFileSize,
    required this.matchExtension,
    required this.minFileCount,
    required this.responsePort,
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

// Global abort flag for the isolate
bool _abortRequested = false;

// Core service instance for isolate operations
final FuzzyDuplicateService _coreService = FuzzyDuplicateService();

// Isolate entry point
void isolateEntry(SendPort mainSendPort) {
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
  Function(double, String)? onProgress,
}) async {
  // Convert map data to FileInfo objects for core service processing
  final List<FileInfo> fileInfoList =
      files.map((fileMap) => FileInfo.fromMap(fileMap)).toList();

  // Use core service for hash computation (if needed)
  if (checkContent) {
    onProgress?.call(0.1, 'Computing file hashes...');
    for (int i = 0; i < fileInfoList.length; i++) {
      // Check for abort request
      if (_abortRequested) break;

      if (fileInfoList[i].hash == null) {
        final hash = _coreService.calculateFileHash(fileInfoList[i].filePath);
        fileInfoList[i] = FileInfo(
          filePath: fileInfoList[i].filePath,
          fileName: fileInfoList[i].fileName,
          fileSize: fileInfoList[i].fileSize,
          hash: hash,
          modifiedDate: fileInfoList[i].modifiedDate,
        );
      }

      // Update hash computation progress (10% to 30%)
      final progress = 0.1 + (i + 1) / fileInfoList.length * 0.2;
      onProgress?.call(progress.clamp(0.1, 0.3),
          'Hashed ${i + 1}/${fileInfoList.length} files...');

      // Update original maps with computed hashes
      files[i]['hash'] = fileInfoList[i].hash;
    }
  }

  // Stage 3: Grouping and indexing (30-40%)
  onProgress?.call(0.3, 'Indexing files for comparison...');

  // Create lookup maps for faster comparison
  final Map<String, List<int>> sizeGroups = {};
  final Map<String, List<int>> extensionGroups = {};

  for (int i = 0; i < fileInfoList.length; i++) {
    // Group by size buckets (within tolerance)
    if (!ignoreFileSize) {
      final sizeBucket = ((fileInfoList[i].fileSize) / 1024).round();
      sizeGroups.putIfAbsent('$sizeBucket', () => []).add(i);
    }

    // Group by extension if needed
    if (matchExtension) {
      final ext = path.extension(fileInfoList[i].fileName).toLowerCase();
      extensionGroups.putIfAbsent(ext, () => []).add(i);
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

  for (int i = 0; i < fileInfoList.length; i++) {
    if (_abortRequested) break;

    // Report current file being processed with stage progress (40% to 90%)
    final stageProgress = 0.4 + (i / fileInfoList.length) * 0.5;
    onProgress?.call(stageProgress, fileInfoList[i].fileName);

    final List<Map<String, dynamic>> similarFiles = [files[i]];
    final String baseName = getBasename(i);

    // Determine comparison candidates based on constraints
    List<int> candidates;
    if (matchExtension) {
      final ext = path.extension(fileInfoList[i].fileName).toLowerCase();
      candidates = extensionGroups[ext] ?? [];
    } else if (!ignoreFileSize) {
      final sizeBucket = ((fileInfoList[i].fileSize) / 1024).round();
      candidates = [];
      // Check nearby size buckets
      for (int offset = -1; offset <= 1; offset++) {
        candidates.addAll(sizeGroups['${sizeBucket + offset}'] ?? []);
      }
    } else {
      candidates = List.generate(fileInfoList.length, (idx) => idx);
    }

    for (final j in candidates) {
      if (j <= i) continue;

      bool isSimilar = false;

      if (checkContent &&
          files[i]['hash'] != null &&
          files[j]['hash'] != null) {
        isSimilar = files[i]['hash'] == files[j]['hash'];
      } else {
        // Cache similarity calculation
        final cacheKey = '$i-$j';
        final nameSimilarity = similarityCache.putIfAbsent(
          cacheKey,
          () => ratio(baseName, getBasename(j)) / 100.0,
        );

        // Early termination if name similarity is too low
        if (nameSimilarity < similarityThreshold) continue;

        final sizeDifference =
            ((fileInfoList[i].fileSize) - (fileInfoList[j].fileSize)).abs() /
                (fileInfoList[i].fileSize).clamp(1, double.infinity);

        final nameMatch = nameSimilarity >= 0.99;
        final sizeMatch = ignoreFileSize ||
            (nameMatch && !ignoreFileSize) ||
            sizeDifference <= sizeTolerance;

        isSimilar = sizeMatch;

        if (isSimilar && matchExtension) {
          final ext1 = path.extension(fileInfoList[i].fileName).toLowerCase();
          final ext2 = path.extension(fileInfoList[j].fileName).toLowerCase();
          isSimilar = ext1 == ext2;
        }
      }

      if (isSimilar) {
        similarFiles.add(files[j]);
      }
    }

    if (similarFiles.length >= minFileCount) {
      final avgSimilarity = similarFiles.length > 2
          ? 0.9
          : similarityCache['$i-${similarFiles.indexOf(similarFiles[1])}'] ??
              0.9;

      duplicateGroups.add({
        'files': similarFiles,
        'similarity': avgSimilarity,
      });
    }
  }

  // Stage 5: Finalizing results (90-95%)
  onProgress?.call(0.9, 'Finalizing duplicate groups...');

  // Stage 6: Complete (95-100%)
  onProgress?.call(0.95, 'Preparing results for display...');

  // Allow time for UI to update
  await Future.delayed(const Duration(milliseconds: 500));

  onProgress?.call(1.0, 'Duplicate detection complete');

  return duplicateGroups;
}

class IsolateFuzzyDuplicateService {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  Future<void> _ensureIsolate() async {
    if (_isolate == null) {
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(isolateEntry, _receivePort!.sendPort);

      final completer = Completer<SendPort>();
      _receivePort!.listen((message) {
        if (message is SendPort && !completer.isCompleted) {
          completer.complete(message);
        }
      });

      _sendPort = await completer.future;
    }
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
    await _ensureIsolate();

    final responsePort = ReceivePort();
    final completer = Completer<List<Map<String, dynamic>>>();

    // Listen for messages from the isolate
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

    // Send the scan message to the isolate
    final scanMessage = IsolateMessage(
      files: files,
      similarityThreshold: similarityThreshold,
      checkContent: checkContent,
      sizeTolerance: sizeTolerance,
      ignoreFileSize: ignoreFileSize,
      matchExtension: matchExtension,
      minFileCount: minFileCount,
      responsePort: responsePort.sendPort,
    );

    _sendPort!.send(scanMessage);

    return await completer.future;
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _receivePort = null;
    _sendPort = null;
  }

  // Method to abort isolate operations
  void abort() {
    _abortRequested = true;
  }
}
