import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class EditorAppBarWidget extends StatelessWidget {
  final String title;
  final bool isSaved;
  final bool hasUnsavedChanges;
  final int wordCount;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback onUpgrade;
  final VoidCallback onToggleToolbar;
  final bool isToolbarVisible;

  const EditorAppBarWidget({
    required this.title,
    required this.isSaved,
    required this.hasUnsavedChanges,
    required this.wordCount,
    required this.onSave,
    required this.onBack,
    required this.onUpgrade,
    required this.onToggleToolbar,
    required this.isToolbarVisible,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: onBack,
            color: theme.colorScheme.onSurface,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: hasUnsavedChanges
                          ? Row(
                              key: const ValueKey('unsaved'),
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.warning,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Unsaved',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.warning,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('saved'),
                              children: [
                                Icon(
                                  isSaved
                                      ? Icons.cloud_done_rounded
                                      : Icons.cloud_outlined,
                                  size: 12,
                                  color: isSaved
                                      ? AppTheme.success
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSaved ? 'Saved' : 'Not saved',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isSaved
                                        ? AppTheme.success
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$wordCount words',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isToolbarVisible
                  ? Icons.format_paint_rounded
                  : Icons.format_paint_outlined,
              size: 20,
            ),
            onPressed: onToggleToolbar,
            color: isToolbarVisible
                ? AppTheme.primary
                : theme.colorScheme.onSurfaceVariant,
            tooltip: 'Toggle formatting toolbar',
          ),
          IconButton(
            icon: Icon(
              hasUnsavedChanges ? Icons.save_rounded : Icons.save_outlined,
              size: 20,
            ),
            onPressed: hasUnsavedChanges ? onSave : null,
            color: hasUnsavedChanges
                ? AppTheme.primary
                : theme.colorScheme.outline,
            tooltip: 'Save document',
          ),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.secondary, Color(0xFFFF8C5A)],
                ),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Pro',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
