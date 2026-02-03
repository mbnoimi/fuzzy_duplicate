import 'package:flutter/material.dart';
import 'dart:io';
import '../core_service.dart';
import 'async_service.dart';

class DuplicateProvider extends ChangeNotifier {
  final FuzzyDuplicateService _service = FuzzyDuplicateService();
  final IsolateFuzzyDuplicateService _isolateService =
      IsolateFuzzyDuplicateService();
  List<DuplicateGroup> _duplicateGroups = [];
  bool _isScanning = false;
  String _sourcePath = '';
  String _targetPath = '';
  String _selectedFileType = 'all';
  String _customExtension = '';
  double _similarityThreshold = 0.85;
  bool _checkContent = false;
  double _sizeTolerance = 0.05;
  bool _ignoreFileSize = false;
  bool _matchExtension = false;
  int _minFileCount = 2;
  final Set<String> _globalSelectedFiles = {};
  String _scanStatus = '';
  double _scanProgress = 0.0;
  bool _abortRequested = false;
  String _excludeExtensions = '';
  int _currentGroupIndex = 0;
  String _currentFileName = '';
  String _scanStage = '';
  String _themeMode = 'light';

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _customExtensionController =
      TextEditingController(text: '');
  final TextEditingController _excludeExtensionsController =
      TextEditingController(text: '');

  TextEditingController get sourceController => _sourceController;
  TextEditingController get targetController => _targetController;
  TextEditingController get customExtensionController =>
      _customExtensionController;
  TextEditingController get excludeExtensionsController =>
      _excludeExtensionsController;

  List<DuplicateGroup> get duplicateGroups => _duplicateGroups;
  bool get isScanning => _isScanning;
  bool get abortRequested => _abortRequested;
  String get excludeExtensions => _excludeExtensionsController.text;
  String get sourcePath => _sourcePath;
  String get targetPath => _targetPath;
  String get selectedFileType => _selectedFileType;
  String get customExtension => _customExtensionController.text;
  double get similarityThreshold => _similarityThreshold;
  bool get checkContent => _checkContent;
  double get sizeTolerance => _sizeTolerance;
  bool get ignoreFileSize => _ignoreFileSize;
  bool get matchExtension => _matchExtension;
  int get minFileCount => _minFileCount;
  Set<String> get globalSelectedFiles => _globalSelectedFiles;
  String get scanStatus => _scanStatus;
  double get scanProgress => _scanProgress;
  int get currentGroupIndex => _currentGroupIndex;
  String get currentFileName => _currentFileName;
  String get scanStage => _scanStage;
  String get themeMode => _themeMode;

  int get totalFileCount {
    return _duplicateGroups.fold<int>(
        0, (sum, group) => sum + group.files.length);
  }

  int get totalGroupCount => _duplicateGroups.length;

  void setCurrentGroupIndex(int index) {
    if (index >= 0 && index < _duplicateGroups.length) {
      _currentGroupIndex = index;
      notifyListeners();
    }
  }

  void setScanStage(String stage) {
    _scanStage = stage;
    notifyListeners();
  }

  void setThemeMode(String theme) {
    _themeMode = theme;
    notifyListeners();
  }

  void goToNextGroup() {
    if (_currentGroupIndex < _duplicateGroups.length - 1) {
      _currentGroupIndex++;
      notifyListeners();
    }
  }

  void goToPreviousGroup() {
    if (_currentGroupIndex > 0) {
      _currentGroupIndex--;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    _customExtensionController.dispose();
    _excludeExtensionsController.dispose();
    _isolateService.dispose();
    super.dispose();
  }

  void setSourcePath(String path) {
    _sourcePath = path;
    _sourceController.text = path;
    notifyListeners();
  }

  void setTargetPath(String path) {
    _targetPath = path;
    _targetController.text = path;
    notifyListeners();
  }

  void setFileType(String fileType) {
    _selectedFileType = fileType;
    notifyListeners();
  }

  void setCustomExtensions(String extensions) {
    _customExtension = extensions;
    notifyListeners();
  }

  void setExcludeExtensions(String extensions) {
    _excludeExtensions = extensions;
    notifyListeners();
  }

  void setSimilarityThreshold(double threshold) {
    _similarityThreshold = threshold;
    notifyListeners();
  }

  void setSizeTolerance(double tolerance) {
    _sizeTolerance = tolerance;
    notifyListeners();
  }

  void setIgnoreFileSize(bool ignore) {
    _ignoreFileSize = ignore;
    notifyListeners();
  }

  void setMatchExtension(bool match) {
    _matchExtension = match;
    notifyListeners();
  }

  void setMinFileCount(int count) {
    _minFileCount = count;
    notifyListeners();
  }

  void setCheckContent(bool check) {
    _checkContent = check;
    notifyListeners();
  }

  void toggleGlobalFileSelection(String filePath) {
    if (_globalSelectedFiles.contains(filePath)) {
      _globalSelectedFiles.remove(filePath);
    } else {
      _globalSelectedFiles.add(filePath);
    }
    notifyListeners();
  }

  void selectAllFiles() {
    _globalSelectedFiles.clear();
    for (final group in _duplicateGroups) {
      for (final file in group.files) {
        _globalSelectedFiles.add(file.filePath);
      }
    }
    notifyListeners();
  }

  void deselectAllFiles() {
    _globalSelectedFiles.clear();
    notifyListeners();
  }

  bool isFileGloballySelected(String filePath) {
    return _globalSelectedFiles.contains(filePath);
  }

  void selectGroupFiles(int groupIndex) {
    if (groupIndex >= 0 && groupIndex < _duplicateGroups.length) {
      final group = _duplicateGroups[groupIndex];
      for (final file in group.files) {
        _globalSelectedFiles.add(file.filePath);
      }
      notifyListeners();
    }
  }

  void selectBiggestFiles() {
    _globalSelectedFiles.clear();
    for (final group in _duplicateGroups) {
      if (group.files.isNotEmpty) {
        final biggestFile =
            group.files.reduce((a, b) => a.fileSize > b.fileSize ? a : b);
        _globalSelectedFiles.add(biggestFile.filePath);
      }
    }
    notifyListeners();
  }

  void selectSmallestFiles() {
    _globalSelectedFiles.clear();
    for (final group in _duplicateGroups) {
      if (group.files.isNotEmpty) {
        final smallestFile =
            group.files.reduce((a, b) => a.fileSize < b.fileSize ? a : b);
        _globalSelectedFiles.add(smallestFile.filePath);
      }
    }
    notifyListeners();
  }

  void selectOldestFiles() {
    _globalSelectedFiles.clear();
    for (final group in _duplicateGroups) {
      if (group.files.isNotEmpty) {
        final oldestFile = group.files.reduce((a, b) {
          final aStat = File(a.filePath).statSync();
          final bStat = File(b.filePath).statSync();
          return aStat.modified.isBefore(bStat.modified) ? a : b;
        });
        _globalSelectedFiles.add(oldestFile.filePath);
      }
    }
    notifyListeners();
  }

  void selectNewestFiles() {
    _globalSelectedFiles.clear();
    for (final group in _duplicateGroups) {
      if (group.files.isNotEmpty) {
        final newestFile = group.files.reduce((a, b) {
          final aStat = File(a.filePath).statSync();
          final bStat = File(b.filePath).statSync();
          return bStat.modified.isAfter(aStat.modified) ? b : a;
        });
        _globalSelectedFiles.add(newestFile.filePath);
      }
    }
    notifyListeners();
  }

  void selectAllExceptBiggest() {
    _globalSelectedFiles.clear();
    for (final group in _duplicateGroups) {
      if (group.files.isNotEmpty) {
        final biggestFile =
            group.files.reduce((a, b) => a.fileSize > b.fileSize ? a : b);
        for (final file in group.files) {
          if (file.filePath != biggestFile.filePath) {
            _globalSelectedFiles.add(file.filePath);
          }
        }
      }
    }
    notifyListeners();
  }

  void selectAllExceptSmallest() {
    _globalSelectedFiles.clear();
    for (final group in _duplicateGroups) {
      if (group.files.isNotEmpty) {
        final smallestFile =
            group.files.reduce((a, b) => a.fileSize < b.fileSize ? a : b);
        for (final file in group.files) {
          if (file.filePath != smallestFile.filePath) {
            _globalSelectedFiles.add(file.filePath);
          }
        }
      }
    }
    notifyListeners();
  }

  void selectAllExceptOldest() {
    _globalSelectedFiles.clear();
    for (final group in _duplicateGroups) {
      if (group.files.isNotEmpty) {
        final oldestFile = group.files.reduce((a, b) {
          final aStat = File(a.filePath).statSync();
          final bStat = File(b.filePath).statSync();
          return aStat.modified.isBefore(bStat.modified) ? a : b;
        });

        for (final file in group.files) {
          if (file.filePath != oldestFile.filePath) {
            _globalSelectedFiles.add(file.filePath);
          }
        }
      }
    }
    notifyListeners();
  }

  void selectAllExceptNewest() {
    _globalSelectedFiles.clear();
    for (final group in _duplicateGroups) {
      if (group.files.isNotEmpty) {
        final newestFile = group.files.reduce((a, b) {
          final aStat = File(a.filePath).statSync();
          final bStat = File(b.filePath).statSync();
          return bStat.modified.isAfter(aStat.modified) ? b : a;
        });

        for (final file in group.files) {
          if (file.filePath != newestFile.filePath) {
            _globalSelectedFiles.add(file.filePath);
          }
        }
      }
    }
    notifyListeners();
  }

  void deselectGroupFiles(int groupIndex) {
    if (groupIndex >= 0 && groupIndex < _duplicateGroups.length) {
      final group = _duplicateGroups[groupIndex];
      for (final file in group.files) {
        _globalSelectedFiles.remove(file.filePath);
      }
      notifyListeners();
    }
  }

  Future<void> scanForDuplicates() async {
    if (_sourcePath.isEmpty) {
      throw Exception('Please select a source directory');
    }

    _isScanning = true;
    _abortRequested = false;
    _currentGroupIndex = 0;
    _scanProgress = 0.0;
    _scanStatus = 'Starting scan...';
    _scanStage = 'Initializing...';
    // Use microtask to ensure UI update
    Future.microtask(() => notifyListeners());

    try {
      String? customExt = _selectedFileType == 'custom'
          ? _customExtensionController.text
          : null;
      final files = await _service.scanDirectory(
        _sourcePath,
        _selectedFileType,
        customExt,
        _excludeExtensionsController.text,
        (progress, fileName) {
          if (_abortRequested) return;
          _scanProgress = progress;
          _scanStage = fileName;
          Future.microtask(() => notifyListeners());
        },
      );

      // Check for abort during scanning
      if (_abortRequested) {
        return;
      }

      if (files.isEmpty) {
        _duplicateGroups = [];
        _scanProgress = 1.0;
        _scanStatus = 'No files found';
        _scanStage = '';
        notifyListeners();
        return;
      }

      _scanStatus = 'Finding duplicates';
      _currentFileName = '';
      notifyListeners();

      // Allow UI to update before starting heavy comparison
      await Future.delayed(const Duration(milliseconds: 300));

      // Check for abort before heavy comparison
      if (_abortRequested) {
        return;
      }

      // Convert files to maps for isolate communication
      final filesAsMaps = files
          .map((file) => {
                'filePath': file.filePath,
                'fileName': file.fileName,
                'fileSize': file.fileSize,
                'hash': file.hash,
                'modifiedDate': file.modifiedDate?.millisecondsSinceEpoch,
              })
          .toList();

      final duplicateGroupsAsMaps = await _isolateService.findFuzzyDuplicates(
        filesAsMaps,
        similarityThreshold: _similarityThreshold,
        checkContent: _checkContent,
        sizeTolerance: _sizeTolerance,
        ignoreFileSize: _ignoreFileSize,
        matchExtension: _matchExtension,
        minFileCount: _minFileCount,
        onProgress: (progress, fileName) {
          if (_abortRequested) {
            return;
          }
          _scanProgress = progress;
          _scanStage = fileName;
          if (progress >= 1.0) {
            _scanStatus = 'Displaying results on UI...';
            _scanStage = '';
          }
          // Use microtask to ensure UI update
          Future.microtask(() => notifyListeners());
        },
      );

      // Convert back from maps to DuplicateGroup objects
      _duplicateGroups = duplicateGroupsAsMaps.map((groupMap) {
        final files = (groupMap['files'] as List).map((fileMap) {
          return FileInfo(
            filePath: fileMap['filePath'],
            fileName: fileMap['fileName'],
            fileSize: fileMap['fileSize'],
            hash: fileMap['hash'],
            modifiedDate: fileMap['modifiedDate'] != null
                ? DateTime.fromMillisecondsSinceEpoch(fileMap['modifiedDate'])
                : null,
          );
        }).toList();

        return DuplicateGroup(
          files: files,
          similarity: groupMap['similarity'],
        );
      }).toList();
    } catch (e) {
      if (!_abortRequested) {
        throw Exception('Scan failed: $e');
      }
    } finally {
      _isScanning = false;
      _abortRequested = false;
      _scanStatus = '';
      _scanProgress = 0.0;
      _currentFileName = '';
      _scanStage = '';
      // Use microtask to ensure final UI update
      Future.microtask(() => notifyListeners());
    }
  }

  void abortScan() {
    _abortRequested = true;
    _scanStatus = 'Aborting scan...';
    _currentFileName = '';
    notifyListeners();

    // Dispose isolate to force termination
    _isolateService.dispose();

    // Reset state immediately
    _isScanning = false;
    _abortRequested = false;
    _scanStatus = '';
    _scanProgress = 0.0;
    _currentFileName = '';
    notifyListeners();
  }

  Future<void> moveSelectedFiles(List<String> filePaths) async {
    if (_targetPath.isEmpty) {
      throw Exception('Please select a target directory');
    }

    try {
      await _service.moveFiles(filePaths, _targetPath);
      _globalSelectedFiles.removeAll(filePaths);
      await scanForDuplicates();
    } catch (e) {
      throw Exception('Move failed: $e');
    }
  }

  Future<void> deleteSelectedFiles(List<String> filePaths) async {
    try {
      await _service.deleteFiles(filePaths);
      _globalSelectedFiles.removeAll(filePaths);
      await scanForDuplicates();
    } catch (e) {
      throw Exception('Delete failed: $e');
    }
  }

  Future<void> moveAllSelectedFiles() async {
    if (_globalSelectedFiles.isEmpty) {
      throw Exception('No files selected');
    }
    await moveSelectedFiles(_globalSelectedFiles.toList());
  }

  Future<void> deleteAllSelectedFiles() async {
    if (_globalSelectedFiles.isEmpty) {
      throw Exception('No files selected');
    }
    await deleteSelectedFiles(_globalSelectedFiles.toList());
  }
}
