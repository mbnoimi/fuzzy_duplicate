import 'dart:io';
import 'lib/core_service.dart';

void main() async {
  final service = FuzzyDuplicateService();

  // Test with your specific files
  final files = await service.scanDirectory(
      '/home/admino/Desktop/FuzzyDuplicate/test_files', 'all');

  print('Found ${files.length} files:');
  for (int i = 0; i < files.length; i++) {
    print('${i + 1}. ${files[i].fileName} (${files[i].formattedSize})');
  }

  // Test similarity between bash.sh files
  if (files.length >= 2) {
    final file1 = files.where((f) => f.fileName.contains('bash.sh')).first;
    final file2 =
        files.where((f) => f.fileName.contains('bash.sh') && f != file1).first;

    print('\nTesting similarity between:');
    print('File 1: ${file1.fileName}');
    print('File 2: ${file2.fileName}');

    final baseName1 = file1.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final baseName2 = file2.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    print('Base name 1: $baseName1');
    print('Base name 2: $baseName2');

    // Import fuzzywuzzy ratio directly to test
    final ratio = await _testRatio(baseName1, baseName2);
    print('Ratio: $ratio');

    final sizeDiff = (file1.fileSize - file2.fileSize).abs() / file1.fileSize;
    print('Size difference: ${(sizeDiff * 100).toStringAsFixed(1)}%');
  }

  print('\nRunning duplicate detection with low threshold (30%)...');
  final duplicates = await service.findFuzzyDuplicates(
    files,
    similarityThreshold: 0.3,
    sizeTolerance: 0.5,
    ignoreFileSize: false,
    matchExtension: false,
    minFileCount: 2,
  );
  print('Found ${duplicates.length} duplicate groups');

  for (int i = 0; i < duplicates.length; i++) {
    print('\nGroup ${i + 1}:');
    for (final file in duplicates[i].files) {
      print('  - ${file.fileName}');
    }
  }
}

Future<double> _testRatio(String s1, String s2) async {
  // Simple manual ratio test for debugging
  if (s1 == s2) return 100.0;

  int matches = 0;
  int total = s1.length > s2.length ? s1.length : s2.length;

  for (int i = 0; i < total; i++) {
    if (i < s1.length && i < s2.length && s1[i] == s2[i]) {
      matches++;
    }
  }

  return (matches / total) * 100;
}
