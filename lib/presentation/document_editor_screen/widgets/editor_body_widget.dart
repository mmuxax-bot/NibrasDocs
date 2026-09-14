import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class EditorBodyWidget extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String alignment;
  final FocusNode focusNode;
  final ValueChanged<String> onTitleChanged;

  const EditorBodyWidget({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.alignment,
    required this.focusNode,
    required this.onTitleChanged,
    super.key,
  });

  TextAlign get _textAlign => switch (alignment) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    _ => TextAlign.left,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: titleCtrl,
            onChanged: onTitleChanged,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              hintText: 'Untitled Document',
              hintStyle: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w700,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: bodyCtrl,
            focusNode: focusNode,
            maxLines: null,
            minLines: 20,
            textAlign: _textAlign,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: isUnderline
                  ? TextDecoration.underline
                  : TextDecoration.none,
              color: theme.colorScheme.onSurface,
              height: 1.65,
              letterSpacing: 0.1,
            ),
            decoration: InputDecoration(
              hintText:
                  'Start typing your document here...\n\nYou can format text using the toolbar above.',
              hintStyle: TextStyle(
                fontSize: 15.5,
                color: theme.colorScheme.outline,
                height: 1.65,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }
}
