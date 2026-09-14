import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class DocFilterChipsWidget extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  const DocFilterChipsWidget({
    required this.activeFilter,
    required this.onFilterChanged,
    super.key,
  });

  static const _filters = ['All', 'Recent', 'Starred', 'Folders'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isActive = filter == activeFilter;

          return GestureDetector(
            onTap: () => onFilterChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isActive
                      ? AppTheme.primary
                      : theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Text(
                filter,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isActive
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
