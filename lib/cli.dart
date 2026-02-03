import 'dart:io';
import 'package:args/args.dart';
import 'core_service.dart';

Future<void> runCli(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'type',
      abbr: 't',
      mandatory: true,
      help: 'File type (videos, documents, images, audio, archives)',
    )
    ..addOption(
      'source',
      abbr: 's',
      mandatory: true,
      help: 'Source directory path',
    )
    ..addOption(
      'target',
      abbr: 'T',
      help: 'Target directory path (for moving duplicates)',
    )
    ..addOption(
      'similarity',
      abbr: 'S',
      defaultsTo: '0.8',
      help: 'Similarity threshold (0.5-1.0)',
    )
    ..addFlag(
      'content',
      abbr: 'c',
      defaultsTo: false,
      help: 'Check file content for duplicates (slower)',
    )
    ..addFlag(
      'delete',
      abbr: 'd',
      defaultsTo: false,
      help: 'Delete duplicates instead of moving',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information',
    );

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _printUsage(parser);
      return;
    }

    final fileType = results['type'] as String;
    final sourcePath = results['source'] as String;
    final targetPath = results['target'] as String?;
    final similarity = double.tryParse(results['similarity'] as String) ?? 0.8;
    final checkContent = results['content'] as bool;
    final deleteDuplicates = results['delete'] as bool;

    if (similarity < 0.5 || similarity > 1.0) {
      print('Error: Similarity must be between 0.5 and 1.0');
      exit(1);
    }

    if (!deleteDuplicates && targetPath == null) {
      print('Error: Must specify either --target or --delete');
      exit(1);
    }

    print('🔍 Starting fuzzy duplicate scan...');
    print('   File type: $fileType');
    print('   Source: $sourcePath');
    print('   Similarity: ${(similarity * 100).toStringAsFixed(0)}%');
    print('   Content check: ${checkContent ? "Yes" : "No"}');
    print('');

    final service = FuzzyDuplicateService();

    print('📁 Scanning directory...');
    final files = await service.scanDirectory(sourcePath, fileType);
    print('   Found ${files.length} files');

    if (files.isEmpty) {
      print('No files found matching the specified type.');
      return;
    }

    print('🔍 Finding duplicates...');
    final duplicateGroups = await service.findFuzzyDuplicates(
      files,
      similarityThreshold: similarity,
      checkContent: checkContent,
    );

    if (duplicateGroups.isEmpty) {
      print('✅ No duplicates found!');
      return;
    }

    print('');
    print('📋 Found ${duplicateGroups.length} duplicate groups:');
    print('');

    int totalDuplicates = 0;
    final List<String> filesToAction = [];

    for (int i = 0; i < duplicateGroups.length; i++) {
      final group = duplicateGroups[i];
      print(
        '📂 Group ${i + 1} (${group.files.length} files, ${(group.similarity * 100).toStringAsFixed(0)}% similar):',
      );

      for (int j = 0; j < group.files.length; j++) {
        final file = group.files[j];
        final prefix = j == 0 ? '   ✅ Keep: ' : '   🗑️  ';
        print('$prefix${file.fileName} (${file.formattedSize})');
        print('      Path: ${file.filePath}');

        if (j > 0) {
          filesToAction.add(file.filePath);
        }
      }
      totalDuplicates += group.files.length - 1;
      print('');
    }

    print('📊 Summary:');
    print('   Total duplicate files: $totalDuplicates');

    if (deleteDuplicates) {
      print('   Action: Delete duplicates');
    } else {
      print('   Action: Move to: $targetPath');
    }
    print('');

    print('🚀 Processing duplicates...');

    try {
      if (deleteDuplicates) {
        await service.deleteFiles(filesToAction);
        print(
          '   ✅ Successfully deleted ${filesToAction.length} duplicate files',
        );
      } else {
        await service.moveFiles(filesToAction, targetPath!);
        print(
          '   ✅ Successfully moved ${filesToAction.length} duplicate files to $targetPath',
        );
      }
    } catch (e) {
      print('   ❌ Error: $e');
      exit(1);
    }

    print('');
    print('🎉 Operation completed successfully!');
  } catch (e) {
    print('❌ Error: $e');
    _printUsage(parser);
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  print('');
  print('Fuzzy Duplicate Finder - CLI Mode');
  print('');
  print('Usage: dart run bin/fuzzy_duplicate.dart [options]');
  print('');
  print('Required options:');
  print(
    '  -t, --type      File type (all, videos, documents, images, audio, archives, custom)',
  );
  print('  -s, --source    Source directory path');
  print('');
  print('Action options (one required):');
  print('  -T, --target    Target directory path (for moving duplicates)');
  print('  -d, --delete    Delete duplicates instead of moving');
  print('');
  print('Optional options:');
  print('  -e, --extension    Custom extension (required when type=custom)');
  print('  -S, --similarity    Similarity threshold (0.5-1.0, default: 0.8)');
  print('  -c, --content      Check file content for duplicates (slower)');
  print('  -h, --help         Show this help message');
  print('');
  print('Examples:');
  print('  # Move duplicate videos to another folder');
  print(
    '  dart run bin/fuzzy_duplicate.dart -t videos -s /home/user/videos -T /home/user/duplicates',
  );
  print('');
  print('  # Delete duplicate documents with 90% similarity');
  print(
    '  dart run bin/fuzzy_duplicate.dart -t documents -s /home/user/documents -d -S 0.9',
  );
  print('');
  print('  # Find duplicates by content (slower but more accurate)');
  print(
    '  dart run bin/fuzzy_duplicate.dart -t images -s /home/user/pictures -T /home/user/dups -c',
  );
  print('');
  print('  # Find all file duplicates');
  print(
    '  dart run bin/fuzzy_duplicate.dart -t all -s /home/user/downloads -T /home/user/duplicates',
  );
  print('');
  print('  # Find duplicates with custom extension');
  print(
    '  dart run bin/fuzzy_duplicate.dart -t custom -e log -s /home/user/logs -T /home/user/duplicate_logs',
  );
}
