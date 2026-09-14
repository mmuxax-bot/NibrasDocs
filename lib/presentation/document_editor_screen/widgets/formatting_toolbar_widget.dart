import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class FormattingToolbarWidget extends StatelessWidget {
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String alignment;
  final ValueChanged<String> onFormatTap;

  const FormattingToolbarWidget({
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.alignment,
    required this.onFormatTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          _ToolbarButton(
            icon: Icons.format_bold_rounded,
            label: 'Bold',
            isActive: isBold,
            onTap: () => onFormatTap('bold'),
          ),
          _ToolbarButton(
            icon: Icons.format_italic_rounded,
            label: 'Italic',
            isActive: isItalic,
            onTap: () => onFormatTap('italic'),
          ),
          _ToolbarButton(
            icon: Icons.format_underline_rounded,
            label: 'Underline',
            isActive: isUnderline,
            onTap: () => onFormatTap('underline'),
          ),
          _ToolbarDivider(),
          _ToolbarButton(
            icon: Icons.title_rounded,
            label: 'H1',
            isActive: false,
            onTap: () {},
            customLabel: 'H1',
          ),
          _ToolbarButton(
            icon: Icons.title_rounded,
            label: 'H2',
            isActive: false,
            onTap: () {},
            customLabel: 'H2',
          ),
          _ToolbarDivider(),
          _ToolbarButton(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Bullet List',
            isActive: false,
            onTap: () {},
          ),
          _ToolbarButton(
            icon: Icons.format_list_numbered_rounded,
            label: 'Numbered List',
            isActive: false,
            onTap: () {},
          ),
          _ToolbarDivider(),
          _ToolbarButton(
            icon: Icons.format_align_left_rounded,
            label: 'Align Left',
            isActive: alignment == 'left',
            onTap: () => onFormatTap('align-left'),
          ),
          _ToolbarButton(
            icon: Icons.format_align_center_rounded,
            label: 'Align Center',
            isActive: alignment == 'center',
            onTap: () => onFormatTap('align-center'),
          ),
          _ToolbarButton(
            icon: Icons.format_align_right_rounded,
            label: 'Align Right',
            isActive: alignment == 'right',
            onTap: () => onFormatTap('align-right'),
          ),
          _ToolbarDivider(),
          _ToolbarButton(
            icon: Icons.link_rounded,
            label: 'Insert Link',
            isActive: false,
            onTap: () {},
            isPremium: true,
          ),
          _ToolbarButton(
            icon: Icons.image_outlined,
            label: 'Insert Image',
            isActive: false,
            onTap: () {},
            isPremium: true,
          ),
          _ToolbarButton(
            icon: Icons.table_chart_outlined,
            label: 'Insert Table',
            isActive: false,
            onTap: () {},
            isPremium: true,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? customLabel;
  final bool isPremium;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.customLabel,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          splashColor: AppTheme.primaryContainer,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                customLabel != null
                    ? Text(
                        customLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? AppTheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Icon(
                        icon,
                        size: 18,
                        color: isActive
                            ? AppTheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                if (isPremium)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
