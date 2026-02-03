// tool/update_app_info.dart
import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  final name = _extractValue(pubspec, 'name:');
  final description = _extractValue(pubspec, 'description:');
  final version = _extractValue(pubspec, 'version:');
  final launcherName = _extractLauncherName(pubspec);

  final content = '''
// This file is generated automatically from pubspec.yaml
class AppInfo {
  static const String name = '$name';
  static const String description = '$description';
  static const String version = '$version';
  static const String launcherName = '$launcherName';
}
''';

  File('lib/app_info.dart').writeAsStringSync(content);
}

String _extractValue(String pubspec, String key) {
  final start = pubspec.indexOf(key) + key.length;
  final end = pubspec.indexOf('\n', start);
  return pubspec.substring(start, end).trim().replaceAll("'", "");
}

String _extractLauncherName(String pubspec) {
  final start = pubspec.indexOf('default:') + 'default:'.length;
  final end = pubspec.indexOf('\n', start);
  return pubspec
      .substring(start, end)
      .trim()
      .replaceAll('"', '')
      .replaceAll("'", "");
}
