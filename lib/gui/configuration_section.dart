import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'duplicate_provider.dart';

class ConfigurationSection extends StatelessWidget {
  const ConfigurationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DuplicateProvider>(
      builder: (context, provider, child) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings,
                          size: 24, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        'Configuration',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Directories', context),
                  const SizedBox(height: 12),
                  _buildSourceDirectoryField(context, provider),
                  const SizedBox(height: 12),
                  _buildTargetDirectoryField(context, provider),
                  const SizedBox(height: 24),
                  _buildSectionHeader('File Filters', context),
                  const SizedBox(height: 12),
                  _buildFileTypeDropdown(context, provider),
                  const SizedBox(height: 12),
                  if (provider.selectedFileType == 'custom')
                    _buildCustomExtensionField(context, provider),
                  if (provider.selectedFileType != 'custom')
                    _buildExcludeExtensionsField(context, provider),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Matching Options', context),
                  const SizedBox(height: 16),
                  Tooltip(
                    message:
                        'Minimum filename similarity required to consider files as duplicates (0-100%)',
                    child: _buildSliderSetting(
                      context,
                      'Similarity (File name): ${(provider.similarityThreshold * 100).toStringAsFixed(0)}%',
                      provider.similarityThreshold,
                      0.01,
                      1.0,
                      99,
                      provider.setSimilarityThreshold,
                      enabled: !provider.checkContent,
                    ),
                  ),
                  Tooltip(
                    message:
                        'Allowed size difference when matching files (0% = exact size match)',
                    child: _buildSliderSetting(
                      context,
                      'Size Tolerance: ${(provider.sizeTolerance * 100).toStringAsFixed(0)}%',
                      provider.sizeTolerance,
                      0.0,
                      1.0,
                      20,
                      provider.setSizeTolerance,
                      enabled:
                          !provider.checkContent && !provider.ignoreFileSize,
                    ),
                  ),
                  Tooltip(
                    message:
                        'Minimum number of similar files required to form a duplicate group',
                    child: _buildSliderSetting(
                      context,
                      'Group Min. Files: ${provider.minFileCount}',
                      provider.minFileCount.toDouble(),
                      2,
                      10,
                      8,
                      (value) => provider.setMinFileCount(value.round()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Tooltip(
                    message:
                        'Compare file contents byte by byte for accurate duplicates',
                    child: _buildCheckboxSetting(
                      'Check Content',
                      provider.checkContent,
                      provider.setCheckContent,
                      context,
                    ),
                  ),
                  Tooltip(
                    message:
                        'Ignore file sizes when comparing (use with Check Content)',
                    child: _buildCheckboxSetting(
                      'Ignore Size',
                      provider.ignoreFileSize,
                      provider.setIgnoreFileSize,
                      context,
                    ),
                  ),
                  Tooltip(
                    message: 'Only match files with the same extension',
                    child: _buildCheckboxSetting(
                      'Same Extension',
                      provider.matchExtension,
                      provider.setMatchExtension,
                      context,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildFileTypeDropdown(
      BuildContext context, DuplicateProvider provider) {
    return DropdownButtonFormField<String>(
      initialValue: provider.selectedFileType,
      decoration: InputDecoration(
        labelText: 'File Type',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down),
      iconSize: 28,
      elevation: 8,
      style: Theme.of(context).textTheme.bodyLarge,
      items: [
        'all',
        'videos',
        'documents',
        'images',
        'audio',
        'archives',
        'custom'
      ]
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(
                type == 'all'
                    ? 'All Files'
                    : type == 'custom'
                        ? 'Custom Extensions'
                        : "${type[0].toUpperCase()}${type.substring(1)}",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) provider.setFileType(value);
      },
    );
  }

  Widget _buildCustomExtensionField(
      BuildContext context, DuplicateProvider provider) {
    return TextFormField(
      controller: provider.customExtensionController,
      maxLength: 1000,
      decoration: InputDecoration(
        labelText: 'Custom Extensions (comma separated)',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        helperText:
            'e.g. jpg, png, pdf (include files with these extensions only)',
        helperStyle: const TextStyle(fontSize: 12),
        counterText: '',
      ),
      style: Theme.of(context).textTheme.bodyMedium,
      enabled: provider.selectedFileType == 'custom',
    );
  }

  Widget _buildSourceDirectoryField(
      BuildContext context, DuplicateProvider provider) {
    return TextFormField(
      controller: provider.sourceController,
      decoration: InputDecoration(
        labelText: 'Source Directory',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: const Icon(Icons.folder_open, size: 22),
        suffixIcon: Tooltip(
          message: 'Browse for source directory',
          child: IconButton(
            icon: const Icon(Icons.folder_open, size: 22),
            onPressed: () async {
              String? path = await FilePicker.platform.getDirectoryPath();
              if (path != null) {
                provider.setSourcePath(path);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ),
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'Monospace',
            fontSize: 13,
          ),
      onChanged: (value) {
        provider.setSourcePath(value);
      },
    );
  }

  Widget _buildTargetDirectoryField(
      BuildContext context, DuplicateProvider provider) {
    return TextFormField(
      controller: provider.targetController,
      decoration: InputDecoration(
        labelText: 'Target Directory',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: const Icon(Icons.folder_open, size: 22),
        suffixIcon: Tooltip(
          message: 'Browse for target directory',
          child: IconButton(
            icon: const Icon(Icons.folder_open, size: 22),
            onPressed: () async {
              String? path = await FilePicker.platform.getDirectoryPath();
              if (path != null) {
                provider.setTargetPath(path);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ),
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'Monospace',
            fontSize: 13,
          ),
      onChanged: (value) {
        provider.setTargetPath(value);
      },
    );
  }

  Widget _buildSliderSetting(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    int divisions,
    Function(double) onChanged, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: enabled ? null : Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: enabled
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${((value - min) / (max - min) * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            inactiveTrackColor:
                enabled ? Colors.grey.shade300 : Colors.grey.shade200,
            activeTrackColor:
                enabled ? Theme.of(context).primaryColor : Colors.grey.shade400,
            thumbColor:
                enabled ? Theme.of(context).primaryColor : Colors.grey.shade500,
            overlayColor: enabled
                ? Theme.of(context).primaryColor.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
            valueIndicatorTextStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
            label: '${(value * 100).toStringAsFixed(0)}%',
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxSetting(
    String title,
    bool value,
    Function(bool) onChanged,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: value
              ? Theme.of(context).primaryColor.withOpacity(0.05)
              : Colors.transparent,
          border: Border.all(
            color: value
                ? Theme.of(context).primaryColor.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(context).primaryColor,
          activeTrackColor: Theme.of(context).primaryColor.withOpacity(0.4),
          inactiveThumbColor: Colors.grey.shade600,
          inactiveTrackColor: Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildExcludeExtensionsField(
      BuildContext context, DuplicateProvider provider) {
    return TextFormField(
      controller: provider.excludeExtensionsController,
      maxLength: 1000,
      decoration: InputDecoration(
        labelText: 'Exclude Extensions',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        helperText:
            'e.g. tmp, log, bak (files with these extensions will be skipped)',
        helperStyle: const TextStyle(fontSize: 12),
        prefixIcon: const Icon(Icons.block, size: 22),
        counterText: '',
      ),
      style: Theme.of(context).textTheme.bodyMedium,
      enabled: provider.selectedFileType != 'custom',
    );
  }
}
