import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'duplicate_provider.dart';
import 'about_dialog.dart';

class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DuplicateProvider>(
      builder: (context, provider, child) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.fromLTRB(16, 1, 16, 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildScanButton(context, provider),
                ),
                const SizedBox(width: 12),
                _buildThemeButton(context),
                const SizedBox(width: 8),
                _buildAboutButton(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanButton(BuildContext context, DuplicateProvider provider) {
    final isScanning = provider.isScanning;
    final primaryColor = Theme.of(context).primaryColor;
    final primaryColorDark =
        Color.lerp(primaryColor, Colors.black, 0.2) ?? primaryColor;
    final scanColor = isScanning ? Colors.red : primaryColor;
    final scanColorDark = Color.lerp(scanColor, Colors.black, 0.2) ?? scanColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isScanning
              ? [
                  scanColor,
                  scanColorDark,
                ]
              : [
                  primaryColor,
                  primaryColorDark,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: scanColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isScanning
            ? () => _abortScan(context, provider)
            : () => _startScan(context, provider),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isScanning ? Icons.stop_circle_outlined : Icons.search,
            key: ValueKey(isScanning),
            size: 22,
          ),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            isScanning ? 'Cancel Scan' : 'Scan',
            key: ValueKey(isScanning),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          shadowColor: Colors.transparent,
          maximumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }

  Widget _buildThemeButton(BuildContext context) {
    return Consumer<DuplicateProvider>(
      builder: (context, provider, child) {
        IconData icon;
        Color iconColor;
        switch (provider.themeMode) {
          case 'dark':
            icon = Icons.dark_mode;
            iconColor = Colors.amber.shade300;
            break;
          case 'light':
            icon = Icons.light_mode;
            iconColor = Colors.amber.shade600;
            break;
          default:
            icon = Icons.brightness_auto;
            iconColor = Theme.of(context).primaryColor;
        }

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _switchTheme(context),
            child: Tooltip(
              message: 'Switch theme (System → Light → Dark)',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => AboutDialogWidget.show(context),
        child: Tooltip(
          message: 'About this application',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.help_outline,
              size: 22,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  void _switchTheme(BuildContext context) {
    if (!context.mounted) return;

    final provider = Provider.of<DuplicateProvider>(context, listen: false);

    // Cycle through themes: system -> light -> dark -> system
    String nextTheme;
    switch (provider.themeMode) {
      case 'system':
        nextTheme = 'light';
        break;
      case 'light':
        nextTheme = 'dark';
        break;
      case 'dark':
      default:
        nextTheme = 'system';
        break;
    }

    provider.setThemeMode(nextTheme);

    String themeName;
    Color color;
    switch (nextTheme) {
      case 'dark':
        themeName = 'Dark';
        color = Colors.amber.shade300;
        break;
      case 'light':
        themeName = 'Light';
        color = Colors.amber.shade600;
        break;
      default:
        themeName = 'System';
        color = Theme.of(context).primaryColor;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.palette, color: color),
            const SizedBox(width: 12),
            Text('Theme changed to $themeName'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _startScan(
      BuildContext context, DuplicateProvider provider) async {
    try {
      await provider.scanForDuplicates();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan completed successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _abortScan(
      BuildContext context, DuplicateProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
              ),
              const SizedBox(width: 16),
              const Text('Abort Scan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to abort the current scan?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All progress will be lost and you will need to start over.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text('Continue Scan'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Abort Scan'),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        );
      },
    );

    if (confirmed == true) {
      provider.abortScan();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cancel, color: Colors.white),
                SizedBox(width: 12),
                Text('Scan cancelled'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
