import 'dart:io';
import 'package:args/args.dart';
import 'core_service.dart';

Future<void> runCli(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'type',
      abbr: 't',
      mandatory: true,
      help:
          'File type (all, videos, documents, images, audio, archives, custom)',
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
      'extension',
      abbr: 'e',
      help: 'Custom extension(s), comma-separated (required when type=custom)',
    )
    ..addOption(
      'similarity',
      abbr: 'S',
      defaultsTo: '0.8',
      help: 'Similarity threshold (0.5-1.0)',
    )
    ..addOption(
      'exclude',
      abbr: 'x',
      help: 'Extensions to exclude, comma-separated (e.g., tmp,temp,bak)',
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
      'dry-run',
      abbr: 'n',
      defaultsTo: false,
      help: 'Show what would be done without actually doing it',
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
    final customExtension = results['extension'] as String?;
    final excludeExtensions = results['exclude'] as String?;
    final similarity = double.tryParse(results['similarity'] as String) ?? 0.8;
    final checkContent = results['content'] as bool;
    final deleteDuplicates = results['delete'] as bool;
    final dryRun = results['dry-run'] as bool;

    if (similarity < 0.5 || similarity > 1.0) {
      print('Error: Similarity must be between 0.5 and 1.0');
      exit(1);
    }

    if (!deleteDuplicates && targetPath == null && !dryRun) {
      print('Error: Must specify either --target or --delete');
      exit(1);
    }

    if (fileType.toLowerCase() == 'custom' && customExtension == null) {
      print('Error: --extension is required when type=custom');
      exit(1);
    }

    print('🔍 Starting fuzzy duplicate scan...');
    print('   File type: $fileType');
    print('   Source: $sourcePath');
    if (customExtension != null) {
      print('   Extensions: $customExtension');
    }
    if (excludeExtensions != null) {
      print('   Excluding: $excludeExtensions');
    }
    print('   Similarity: ${(similarity * 100).toStringAsFixed(0)}%');
    print('   Content check: ${checkContent ? "Yes" : "No"}');
    if (dryRun) {
      print('   Mode: Dry run (no changes will be made)');
    }
    print('');

    final service = FuzzyDuplicateService();

    print('📁 Scanning directory...');
    final files = await service.scanDirectory(
      sourcePath,
      fileType,
      customExtension,
      excludeExtensions,
    );
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

    if (dryRun) {
      print('   Action: Dry run - no changes made');
    } else if (deleteDuplicates) {
      print('   Action: Delete duplicates');
    } else {
      print('   Action: Move to: $targetPath');
    }
    print('');

    if (dryRun) {
      print('🏃 Dry run complete - no files were modified');
      return;
    }

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
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║     Fuzzy Duplicate Finder - CLI Mode                            ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
  print('');
  print('Usage:');
  print('  fuzzy_duplicate -t <type> -s <source> [-T <target> | -d] [options]');
  print('');
  print('${'='.padRight(70, '=')}');
  print('REQUIRED OPTIONS:');
  print('${'='.padRight(70, '=')}');
  print('  -t, --type <type>     File type to scan:');
  print('                        • all        - All files');
  print(
      '                        • videos     - Video files (mp4, avi, mkv, etc.)');
  print(
      '                        • documents  - Documents (pdf, doc, txt, etc.)');
  print('                        • images     - Images (jpg, png, gif, etc.)');
  print('                        • audio      - Audio files (mp3, wav, etc.)');
  print('                        • archives   - Archives (zip, rar, 7z, etc.)');
  print(
      '                        • custom     - Custom extensions (use with -e)');
  print('');
  print('  -s, --source <path>   Source directory to scan');
  print('');
  print('${'='.padRight(70, '=')}');
  print('ACTION OPTIONS (at least one required):');
  print('${'='.padRight(70, '=')}');
  print('  -T, --target <path>   Move duplicates to this directory');
  print('  -d, --delete          Delete duplicates instead of moving');
  print('  -n, --dry-run         Preview what would be done (no changes)');
  print('');
  print('${'='.padRight(70, '=')}');
  print('FILTER OPTIONS:');
  print('${'='.padRight(70, '=')}');
  print('  -e, --extension <ext> Custom extension(s), comma-separated');
  print('                        Required when type=custom');
  print('                        Example: -e "log,tmp" or -e "js,ts,jsx"');
  print('');
  print('  -x, --exclude <ext>   Exclude extensions, comma-separated');
  print('                        Example: -x "tmp,temp,bak"');
  print('');
  print('  -S, --similarity <n>  Similarity threshold (0.5-1.0, default: 0.8)');
  print('                        Higher = stricter matching');
  print('');
  print('${'='.padRight(70, '=')}');
  print('DETECTION OPTIONS:');
  print('${'='.padRight(70, '=')}');
  print('  -c, --content         Check file content using xxHash3');
  print(
      '                        More accurate but slower (good for media files)');
  print('');
  print('${'='.padRight(70, '=')}');
  print('OTHER OPTIONS:');
  print('${'='.padRight(70, '=')}');
  print('  -h, --help            Show this help message');
  print('');
  print('${'='.padRight(70, '=')}');
  print('EXAMPLES:');
  print('${'='.padRight(70, '=')}');
  print('');
  print('1. Move duplicate videos:');
  print(
      '   fuzzy_duplicate -t videos -s /home/user/videos -T /backup/duplicates');
  print('');
  print('2. Delete duplicate documents (95% match):');
  print('   fuzzy_duplicate -t documents -s ~/Documents -d -S 0.95');
  print('');
  print('3. Dry run - preview before moving:');
  print('   fuzzy_duplicate -t images -s ~/Pictures -T ~/Duplicates -n');
  print('');
  print('4. Find by content (slower but accurate):');
  print('   fuzzy_duplicate -t all -s ~/Downloads -T ~/Dups -c');
  print('');
  print('5. Custom extensions (log files):');
  print('   fuzzy_duplicate -t custom -e log -s /var/log -T /backup/logs');
  print('');
  print('6. Multiple custom extensions:');
  print('   fuzzy_duplicate -t custom -e "js,ts,jsx" -s ~/projects -T ~/dups');
  print('');
  print('7. Exclude temporary files:');
  print('   fuzzy_duplicate -t all -s ~/data -T ~/dups -x "tmp,temp,bak"');
  print('');
  print('8. Find similar audio files:');
  print('   fuzzy_duplicate -t audio -s ~/Music -T ~/Duplicates -S 0.85');
  print('');
  print('${'='.padRight(70, '=')}');
}
