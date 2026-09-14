import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class DocumentModel {
  final String id;
  final String title;
  final String status;
  final String iconEmoji;
  final String folder;
  final DateTime lastEdited;
  final int wordCount;
  final bool isStarred;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.status,
    required this.iconEmoji,
    required this.folder,
    required this.lastEdited,
    required this.wordCount,
    this.isStarred = false,
  });
}

class DocumentListItemWidget extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isGridMode;

  const DocumentListItemWidget({
    required this.doc,
    required this.onTap,
    required this.onDelete,
    this.isGridMode = false,
    super.key,
  });

  Color _statusColor(String status) => switch (status) {
    'draft' => const Color(0xFF6B6B80),
    'inProgress' => AppTheme.secondary,
    'saved' => AppTheme.success,
    'exported' => AppTheme.primary,
    _ => const Color(0xFF6B6B80),
  };

  String _statusLabel(String status) => switch (status) {
    'draft' => 'Draft',
    'inProgress' => 'In Progress',
    'saved' => 'Saved',
    'exported' => 'Exported',
    _ => status,
  };

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatWordCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(doc.status);

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppTheme.error,
          size: 22,
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Document'),
            content: Text(
              'Are you sure you want to delete "${doc.title}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppTheme.primaryContainer,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline, width: 1),
          ),
          child: isGridMode
              ? _buildGridContent(theme, statusColor)
              : _buildListContent(theme, statusColor),
        ),
      ),
    );
  }

  Widget _buildListContent(ThemeData theme, Color statusColor) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(doc.iconEmoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (doc.isStarred)
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFFFFB800),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      doc.folder,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.primary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatWordCount(doc.wordCount)} words',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _relativeTime(doc.lastEdited),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _statusLabel(doc.status),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: theme.colorScheme.outline,
        ),
      ],
    );
  }

  Widget _buildGridContent(ThemeData theme, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(doc.iconEmoji, style: const TextStyle(fontSize: 22)),
            const Spacer(),
            if (doc.isStarred)
              const Icon(
                Icons.star_rounded,
                size: 14,
                color: Color(0xFFFFB800),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                doc.folder,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.primary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          doc.title,
          style: theme.textTheme.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const Spacer(),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _statusLabel(doc.status),
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              _relativeTime(doc.lastEdited),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}