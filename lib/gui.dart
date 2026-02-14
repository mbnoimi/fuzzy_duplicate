import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'gui/duplicate_provider.dart';
import 'gui/resizable_sidebar.dart';
import 'gui/configuration_section.dart';
import 'gui/action_buttons.dart';
import 'gui/duplicate_list.dart';
import 'gui/splash_screen.dart';

class FuzzyDuplicateApp extends StatelessWidget {
  const FuzzyDuplicateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DuplicateProvider(),
      child: Consumer<DuplicateProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'Fuzzy Duplicates Finder',
            themeMode: _getThemeMode(provider.themeMode),
            theme: _getThemeData(provider.themeMode),
            home: const AppEntryPoint(),
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(String themeString) {
    switch (themeString) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  ThemeData _getThemeData(String themeString) {
    // Use beautiful Material 3 themes with custom seeds
    if (themeString == 'dark') {
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Deep indigo
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
    } else {
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3), // Nice blue
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );
    }
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _showSplash = true;

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _showSplash
          ? SplashScreen(
              key: const ValueKey('splash'),
              onAnimationComplete: _onSplashComplete,
            )
          : const MainScreen(key: ValueKey('main')),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 800;
            final sidebarWidth = isSmallScreen
                ? constraints.maxWidth * 0.4
                : constraints.maxWidth * 0.3;
            final limitedSidebarWidth = sidebarWidth.clamp(250.0, 400.0);

            return Row(
              children: [
                ResizableSidebar(
                  initialWidth: limitedSidebarWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: ConfigurationSection(),
                        ),
                        const SizedBox(height: 3),
                        const ActionButtons(),
                      ],
                    ),
                  ),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: DuplicateList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
