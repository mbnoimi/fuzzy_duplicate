import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core_service.dart';
import 'duplicate_provider.dart';

class DuplicateList extends StatelessWidget {
  const DuplicateList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DuplicateProvider>(
      builder: (context, provider, child) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                provider.goToPreviousGroup(),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                provider.goToNextGroup(),
          },
          child: Focus(
            autofocus: true,
            child: _buildContent(context, provider),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, DuplicateProvider provider) {
    if (provider.isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              provider.scanStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (provider.scanStage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  provider.scanStage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            if (provider.scanProgress > 0.0 && provider.scanProgress <= 1.0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: 300,
                      child: LinearProgressIndicator(
                        value: provider.scanProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(provider.scanProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (provider.duplicateGroups.isEmpty) {
      return Center(
        child: Text(
          'No duplicates found. Configure settings and click "Scan for Duplicates".',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Column(
      children: [
        if (provider.duplicateGroups.isNotEmpty)
          _buildBulkActionsBar(context, provider),
        Expanded(
          child: Column(
            children: [
              if (provider.duplicateGroups.isNotEmpty)
                _buildNavigationPanel(context, provider),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: 1,
                  itemExtent: null,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final group =
                        provider.duplicateGroups[provider.currentGroupIndex];
                    return Consumer<DuplicateProvider>(
                      builder: (context, provider, child) {
                        return DuplicateGroupCard(
                          key: ValueKey('group_${provider.currentGroupIndex}'),
                          group: group,
                          groupIndex: provider.currentGroupIndex,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        _buildStatusBar(context, provider),
      ],
    );
  }

  Widget _buildNavigationPanel(
      BuildContext context, DuplicateProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: provider.currentGroupIndex > 0
                ? () => provider.goToPreviousGroup()
                : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Previous Group (←)',
          ),
          Expanded(
            child: Center(
              child: Text(
                'Group ${provider.currentGroupIndex + 1} of ${provider.totalGroupCount}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            onPressed: provider.currentGroupIndex < provider.totalGroupCount - 1
                ? () => provider.goToNextGroup()
                : null,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Next Group (→)',
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionsBar(
      BuildContext context, DuplicateProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.checklist),
                tooltip: 'Selection Options',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'select_all', child: Text('Select All')),
                  const PopupMenuItem(
                      value: 'deselect_all', child: Text('Deselect All')),
                  const PopupMenuItem(
                      value: 'select_biggest', child: Text('Select Biggest')),
                  const PopupMenuItem(
                      value: 'select_smallest', child: Text('Select Smallest')),
                  const PopupMenuItem(
                      value: 'select_oldest', child: Text('Select Oldest')),
                  const PopupMenuItem(
                      value: 'select_newest', child: Text('Select Newest')),
                  const PopupMenuItem(
                      value: 'all_except_biggest',
                      child: Text('Select All Except Biggest')),
                  const PopupMenuItem(
                      value: 'all_except_smallest',
                      child: Text('Select All Except Smallest')),
                  const PopupMenuItem(
                      value: 'all_except_oldest',
                      child: Text('Select All Except Oldest')),
                  const PopupMenuItem(
                      value: 'all_except_newest',
                      child: Text('Select All Except Newest')),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'select_all':
                      provider.selectAllFiles();
                      break;
                    case 'deselect_all':
                      provider.deselectAllFiles();
                      break;
                    case 'select_biggest':
                      provider.selectBiggestFiles();
                      break;
                    case 'select_smallest':
                      provider.selectSmallestFiles();
                      break;
                    case 'select_oldest':
                      provider.selectOldestFiles();
                      break;
                    case 'select_newest':
                      provider.selectNewestFiles();
                      break;
                    case 'all_except_biggest':
                      provider.selectAllExceptBiggest();
                      break;
                    case 'all_except_smallest':
                      provider.selectAllExceptSmallest();
                      break;
                    case 'all_except_oldest':
                      provider.selectAllExceptOldest();
                      break;
                    case 'all_except_newest':
                      provider.selectAllExceptNewest();
                      break;
                  }
                },
              ),
              const Spacer(),
              IconButton(
                onPressed: provider.globalSelectedFiles.isNotEmpty
                    ? () => _showBulkDeleteConfirmation(context, provider)
                    : null,
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Bulk Actions',
              ),
            ],
          ),
          if (provider.globalSelectedFiles.isNotEmpty)
            const SizedBox(height: 8),
          if (provider.globalSelectedFiles.isNotEmpty)
            Row(
              children: [
                Text(
                  '${provider.globalSelectedFiles.length} files selected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    if (provider.globalSelectedFiles.length ==
                        provider.duplicateGroups.fold<int>(
                            0, (sum, group) => sum + group.files.length)) {
                      provider.deselectAllFiles();
                    } else {
                      provider.selectAllFiles();
                    }
                  },
                  child: Text(
                    provider.globalSelectedFiles.length ==
                            provider.duplicateGroups.fold<int>(
                                0, (sum, group) => sum + group.files.length)
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'biggest':
                        provider.selectBiggestFiles();
                        break;
                      case 'oldest':
                        provider.selectOldestFiles();
                        break;
                      case 'newest':
                        provider.selectNewestFiles();
                        break;
                      case 'smallest':
                        provider.selectSmallestFiles();
                        break;
                      case 'all_except_biggest':
                        provider.selectAllExceptBiggest();
                        break;
                      case 'all_except_oldest':
                        provider.selectAllExceptOldest();
                        break;
                      case 'all_except_newest':
                        provider.selectAllExceptNewest();
                        break;
                      case 'all_except_smallest':
                        provider.selectAllExceptSmallest();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'biggest', child: Text('Select Biggest')),
                    const PopupMenuItem(
                        value: 'oldest', child: Text('Select Oldest')),
                    const PopupMenuItem(
                        value: 'newest', child: Text('Select Newest')),
                    const PopupMenuItem(
                        value: 'smallest', child: Text('Select Smallest')),
                    const PopupMenuItem(
                        value: 'all_except_biggest',
                        child: Text('Select All Except Biggest')),
                    const PopupMenuItem(
                        value: 'all_except_oldest',
                        child: Text('Select All Except Oldest')),
                    const PopupMenuItem(
                        value: 'all_except_newest',
                        child: Text('Select All Except Newest')),
                    const PopupMenuItem(
                        value: 'all_except_smallest',
                        child: Text('Select All Except Smallest')),
                  ],
                ),
              ],
            ),
          if (provider.globalSelectedFiles.isNotEmpty)
            const SizedBox(height: 8),
          if (provider.globalSelectedFiles.isNotEmpty)
            Row(
              children: [
                if (provider.targetPath.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showBulkMoveConfirmation(context, provider),
                    icon: const Icon(Icons.drive_file_move),
                    label: const Text('Move All Selected'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showBulkDeleteConfirmation(context, provider),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete All Selected'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, DuplicateProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Found ${provider.totalFileCount} files in ${provider.totalGroupCount} duplicate groups',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkMoveConfirmation(
      BuildContext context, DuplicateProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.drive_file_move, color: Colors.blue),
              SizedBox(width: 8),
              Text('Move All Selected Files'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Are you sure you want to move these ${provider.globalSelectedFiles.length} files?'),
              const SizedBox(height: 8),
              Text(
                'Files will be moved to: ${provider.targetPath}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Move', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await provider.moveAllSelectedFiles();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('All selected files moved successfully')),
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
  }

  Future<void> _showBulkDeleteConfirmation(
      BuildContext context, DuplicateProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete All Selected Files'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚠️ Are you sure you want to permanently delete these ${provider.globalSelectedFiles.length} files?',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone!',
                style:
                    TextStyle(fontStyle: FontStyle.italic, color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await provider.deleteAllSelectedFiles();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('All selected files deleted successfully')),
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
  }
}

class DuplicateGroupCard extends StatefulWidget {
  final DuplicateGroup group;
  final int? groupIndex;

  const DuplicateGroupCard({super.key, required this.group, this.groupIndex});

  @override
  State<DuplicateGroupCard> createState() => _DuplicateGroupCardState();
}

class _DuplicateGroupCardState extends State<DuplicateGroupCard> {
  void _showContextMenu(BuildContext context, Offset position, FileInfo file) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy_path',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 16),
              const SizedBox(width: 8),
              const Text('Copy Full Path'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'copy_path') {
        Clipboard.setData(ClipboardData(text: file.filePath));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File path copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DuplicateProvider>(
      builder: (context, provider, child) {
        final Set<int> selectedFiles = {};
        for (int i = 0; i < widget.group.files.length; i++) {
          if (provider.isFileGloballySelected(widget.group.files[i].filePath)) {
            selectedFiles.add(i);
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.copy, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Duplicate Group (${widget.group.files.length} files)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${(widget.group.similarity * 100).toStringAsFixed(0)}% similar',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (widget.groupIndex != null) ...[
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          if (selectedFiles.length ==
                              widget.group.files.length) {
                            provider.deselectGroupFiles(widget.groupIndex!);
                          } else {
                            provider.selectGroupFiles(widget.groupIndex!);
                          }
                        },
                        child: Text(
                          selectedFiles.length == widget.group.files.length
                              ? 'Deselect Group'
                              : 'Select Group',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              ...widget.group.files.asMap().entries.map((entry) {
                final file = entry.value;
                final isSelected =
                    provider.isFileGloballySelected(file.filePath);

                return GestureDetector(
                  onTap: () {
                    provider.toggleGlobalFileSelection(file.filePath);
                  },
                  onSecondaryTapDown: (details) {
                    _showContextMenu(context, details.globalPosition, file);
                  },
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      provider.toggleGlobalFileSelection(file.filePath);
                    },
                    title: Text(
                      file.fileName,
                      style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.filePath,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          file.modifiedDate != null
                              ? 'Modified: ${_formatDateTime(file.modifiedDate!)}'
                              : 'Modified: Unknown',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          file.formattedSize,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
