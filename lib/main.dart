import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'gui.dart';
import 'cli.dart';
import 'app_info.dart';

void main(List<String> arguments) async {
  if (arguments.isNotEmpty) {
    await runCli(arguments);
  } else {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: Size(1024, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: AppInfo.launcherName,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.maximize();
    });
    runApp(FuzzyDuplicateApp());
  }
}
