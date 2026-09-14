import '../../routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'widgets/table_editor_dialog.dart';
import 'widgets/image_insert_dialog.dart';
import 'widgets/link_insert_dialog.dart';
import '../../services/premium_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/pdf_service.dart';
import '../../services/word_service.dart';
import '../../services/mobile_export_service.dart';
import '../../services/local_docs_cache.dart';
import '../../services/template_service.dart';
import '../../l10n/app_localizations.dart';
import '../../core/page_size.dart';



enum ExportFormat { pdf, word, txt, epub }

class DocumentEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? documentData;
  const DocumentEditorScreen({this.documentData, super.key});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isStrikethrough = false;
  String _alignment = 'left';
  bool _isSaved = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String? _documentId;
  final FocusNode _bodyFocusNode = FocusNode();

  // Page size state
  PageSize _pageSize = PageSize.a4;
  PageMargin _pageMargin = PageMargin.normal;

  // Typography / color
  double _fontSize = 16;
  Color _textColor = const Color(0xFF1A1A1A);
  Color _bgColor = Colors.white;
  String _fontFamily = 'Roboto';

  // Header / footer
  String _headerText = '';
  String _footerText = '';
  bool _showPageNumbers = true;

  // Reading mode
  bool _readingMode = false;

  // Undo / Redo
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _applyingHistory = false;
  static const int _maxHistory = 50;

  /// Images shown in the document (path + width 0.3-1.0)
  final List<Map<String, dynamic>> _embeddedImages = [];

  @override
  void initState() {
    super.initState();
    final data = widget.documentData;
    _documentId = data?['id'] as String?;
    _titleCtrl = TextEditingController(
      text: data != null ? data['title'] as String? ?? '' : '',
    );
    // Combine title + content into single body field for editing
    final existingTitle = data != null ? data['title'] as String? ?? '' : '';
    final existingContent = data != null
        ? data['content'] as String? ?? ''
        : '';
    final combined = existingTitle.isNotEmpty && existingContent.isNotEmpty
        ? '$existingTitle\n$existingContent'
        : existingTitle.isNotEmpty
        ? existingTitle
        : existingContent;
    _bodyCtrl = TextEditingController(text: combined);
    _bodyCtrl.addListener(_onBodyChanged);
    _titleCtrl.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  void _onBodyChanged() {
    if (_applyingHistory) return;
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
    }
    _pushHistory();
    // Debounce-ish: check limits after edits
    _checkPageLimit();
  }

  void _pushHistory() {
    final text = _bodyCtrl.text;
    if (_undoStack.isNotEmpty && _undoStack.last == text) return;
    _undoStack.add(text);
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.length < 2) return;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final prev = _undoStack.last;
    _applyingHistory = true;
    _bodyCtrl.value = TextEditingValue(
      text: prev,
      selection: TextSelection.collapsed(offset: prev.length),
    );
    _applyingHistory = false;
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    _applyingHistory = true;
    _bodyCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _applyingHistory = false;
    setState(() {});
  }

  void _insertAtCursor(String snippet) {
    final text = _bodyCtrl.text;
    final sel = _bodyCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, snippet);
    final newOffset = start + snippet.length;
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  Future<void> _insertTable({int rows = 3, int cols = 3}) async {
    final md = await TableEditorDialog.show(context);
    if (md == null || md.isEmpty) return;
    _insertAtCursor(md);
  }

  /// Apply color / highlight only to the current selection (not whole document).
  void _applyColorToSelection(Color color, {required bool background}) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    if (!sel.isValid || sel.isCollapsed) {
      // No selection: set default typing style only
      setState(() {
        if (background) {
          _bgColor = color;
        } else {
          _textColor = color;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            background
                ? 'Page background updated. Select text to highlight words.'
                : 'Select a word or sentence first to color only that part.',
            style: GoogleFonts.dmSans(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final start = sel.start;
    final end = sel.end;
    final selected = text.substring(start, end);
    final hex =
        '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final wrapped = background
        ? '[bg=$hex]$selected[/bg]'
        : '[color=$hex]$selected[/color]';
    final newText = text.replaceRange(start, end, wrapped);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + wrapped.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _toggleReadingMode() {
    setState(() => _readingMode = !_readingMode);
  }

  /// All tools are free; only doc count & page length are limited.
  Future<bool> _ensurePremium(String feature) async => true;

  bool _pageLimitDialogOpen = false;

  Future<void> _checkPageLimit() async {
    // Estimate pages from text length vs page body (same idea as indicator)
    final text = _bodyCtrl.text.isEmpty ? ' ' : _bodyCtrl.text;
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32;
    final scale = availableWidth / _pageSize.widthPx;
    final pageDisplayHeight = _pageSize.heightPx * scale;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: _fontSize, height: 1.7),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: availableWidth - 64);
    final contentHeight = tp.height + 56;
    final pages = (contentHeight / pageDisplayHeight).ceil().clamp(1, 999999);

    final maxP = await PremiumService.maxPages();
    final near = await PremiumService.isNearPageLimit(pages);
    final over = pages > maxP;

    if (!mounted) return;
    if (over && !_pageLimitDialogOpen) {
      _pageLimitDialogOpen = true;
      final tier = await PremiumService.currentTier();
      final msg = tier == PlanTier.free
          ? 'This document is over ${PremiumService.maxPagesFree} pages (Free limit).

'
            'Pro ($2.75/mo): up to 150 pages.
Elite ($5.75/mo): unlimited length.

'
            'You can still read and export; upgrade to keep writing longer books.'
          : tier == PlanTier.pro
              ? 'Pro allows up to ${PremiumService.maxPagesPro} pages.\n\n'
                'Elite ($5.75/mo) removes the page limit for long books.'
              : 'Page limit reached.';
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Page limit'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.subscriptionPlanScreen);
              },
              child: const Text('View plans'),
            ),
          ],
        ),
      );
      _pageLimitDialogOpen = false;
    } else if (near && !over && mounted) {
      // Soft toast once in a while — use SnackBar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approaching page limit ($pages / $maxP). Consider Pro for longer books.',
            style: GoogleFonts.dmSans(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    if (!await _ensurePremium('Image')) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;

      // Copy into app documents so it persists
      final dir = await getApplicationDocumentsDirectory();
      final name =
          'img_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final saved = await File(file.path).copy('${dir.path}/$name');

      if (!mounted) return;
      final result = await ImageInsertDialog.show(context, saved.path);
      if (result == null) return;

      setState(() {
        _embeddedImages.add({
          'path': result.path,
          'width': result.widthFactor,
        });
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
      _insertAtCursor(
        '\n[img path="${result.path}" w=${result.widthFactor.toStringAsFixed(2)}]\n',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<void> _insertLink() async {
    if (!await _ensurePremium('Link')) return;
    final sel = _bodyCtrl.selection;
    var selected = '';
    if (sel.isValid && !sel.isCollapsed) {
      selected = _bodyCtrl.text.substring(sel.start, sel.end);
    }
    final md = await LinkInsertDialog.show(context, selected: selected);
    if (md == null) return;
    _insertAtCursor(md);
  }

  void _insertTableOfContents() {
    final lines = _bodyCtrl.text.split('\n');
    final headings = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('# ')) {
        headings.add(t.substring(2).trim());
      } else if (t.startsWith('## ')) {
        headings.add('  • ${t.substring(3).trim()}');
      } else if (RegExp(r'^Chapter\s+\d+', caseSensitive: false).hasMatch(t)) {
        headings.add(t);
      }
    }
    if (headings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No chapters/headings found. Use "# Title" or "Chapter 1"'),
        ),
      );
      return;
    }
    final toc = StringBuffer('Table of Contents\n');
    toc.writeln('─────────────────');
    for (var i = 0; i < headings.length; i++) {
      toc.writeln('${i + 1}. ${headings[i]}');
    }
    toc.writeln('─────────────────\n');
    final text = _bodyCtrl.text;
    if (text.startsWith('Table of Contents')) {
      // replace existing TOC block roughly
      final end = text.indexOf('\n\n', text.indexOf('────'));
      final rest = end > 0 ? text.substring(end + 2) : text;
      _bodyCtrl.text = toc.toString() + rest;
    } else {
      _bodyCtrl.text = toc.toString() + text;
    }
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _showHeaderFooterDialog() {
    final headerCtrl = TextEditingController(text: _headerText);
    final footerCtrl = TextEditingController(text: _footerText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Header & Footer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: headerCtrl,
              decoration: const InputDecoration(
                labelText: 'Header',
                hintText: 'Document title / author',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: footerCtrl,
              decoration: const InputDecoration(
                labelText: 'Footer',
                hintText: 'Confidential / date',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Page numbers'),
              value: _showPageNumbers,
              onChanged: (v) => setState(() => _showPageNumbers = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _headerText = headerCtrl.text;
                _footerText = footerCtrl.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMarginsPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Page margins')),
              ...PageMargin.values.map((m) {
                return ListTile(
                  title: Text(m.label),
                  trailing: _pageMargin == m
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() => _pageMargin = m);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }



  int get _wordCount {
    final text = _bodyCtrl.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  /// Extract title from first line of body text
  String _extractTitle() {
    final text = _bodyCtrl.text.trim();
    if (text.isEmpty) return AppLocalizations.of(context).untitledDocument;
    final firstLine = text.split('\n').first.trim();
    return firstLine.isEmpty
        ? AppLocalizations.of(context).untitledDocument
        : firstLine;
  }

  /// Extract body content (everything after first line)
  String _extractBody() {
    final text = _bodyCtrl.text;
    final newlineIndex = text.indexOf('\n');
    if (newlineIndex == -1) return '';
    return text.substring(newlineIndex + 1);
  }

  Future<void> _saveDocument() async {
    if (_isSaving) return;

    // Show format picker dialog
    final format = await _showFormatPicker();
    if (format == null) return; // user cancelled

    // If PDF selected, generate and download PDF, then also save to DB
    if (format == ExportFormat.pdf) {
      final title = _extractTitle();
      await PdfService.generateAndDownload(
        title: title,
        content: _bodyCtrl.text,
        pageSize: _pageSize,
        textAlign: _alignment,
        isBold: _isBold,
        isItalic: _isItalic,
        isUnderline: _isUnderline,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).t(
                az: 'PDF yüklənir... Çap dialoqunda "PDF kimi saxla" seçin',
                en: 'PDF opening... Select "Save as PDF" in the print dialog',
                ru: 'PDF открывается... Выберите "Сохранить как PDF" в диалоге печати',
                ar: 'جارٍ فتح PDF... اختر "حفظ كـ PDF" في مربع حوار الطباعة',
              ),
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: const Color(0xFFE53E3E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      // Also save to DB in background
      _saveToDatabase();
      return;
    }

    // If Word selected, generate and download .docx, then also save to DB
    if (format == ExportFormat.word) {
      final title = _extractTitle();
      await WordService.generateAndDownload(
        title: title,
        content: _bodyCtrl.text,
        pageSize: _pageSize,
        textAlign: _alignment,
        isBold: _isBold,
        isItalic: _isItalic,
        isUnderline: _isUnderline,
        isStrikethrough: _isStrikethrough,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).t(
                az: 'Word sənədi yükləndi (.docx)',
                en: 'Word document downloaded (.docx)',
                ru: 'Документ Word загружен (.docx)',
                ar: 'تم تنزيل مستند Word (.docx)',
              ),
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: const Color(0xFF2B5CE6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _saveToDatabase();
      return;
    }

    if (format == ExportFormat.txt) {
      final title = _extractTitle();
      await MobileExportService.exportTxt(
        title: title,
        content: _bodyCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('TXT exported', style: GoogleFonts.dmSans()),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _saveToDatabase();
      return;
    }

    if (format == ExportFormat.epub) {
      final title = _extractTitle();
      await MobileExportService.exportEpub(
        title: title,
        content: _bodyCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('EPUB exported', style: GoogleFonts.dmSans()),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _saveToDatabase();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final l10n = AppLocalizations.of(context);
      final title = _extractTitle();
      final content = _extractBody();

      if (_documentId != null) {
        await SupabaseService.instance.updateDocument(
          id: _documentId!,
          title: title,
          content: content,
        );
      } else {
        final doc = await SupabaseService.instance.createDocument(
          title: title,
          content: content,
        );
        if (doc != null) {
          _documentId = doc.id;
        }
      }

      if (mounted) {
        setState(() {
          _isSaved = true;
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
        final formatLabel = format == ExportFormat.pdf ? 'PDF' : 'Word';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).documentSaved} ($formatLabel)',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).saveFailed,
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveToDatabase() async {
    try {
      final l10n = AppLocalizations.of(context);
      final title = _extractTitle();
      final content = _extractBody();
      if (_documentId != null) {
        await SupabaseService.instance.updateDocument(
          id: _documentId!,
          title: title,
          content: content,
        );
      } else {
        final doc = await SupabaseService.instance.createDocument(
          title: title,
          content: content,
        );
        if (doc != null && mounted) {
          setState(() => _documentId = doc.id);
        }
      }
      final id = _documentId ?? DateTime.now().millisecondsSinceEpoch.toString();
      await LocalDocsCache.saveDoc(
        id: id,
        title: title,
        content: content,
      );
      if (mounted) {
        setState(() {
          _isSaved = true;
          _hasUnsavedChanges = false;
        });
      }
    } catch (_) {
      // Still try local offline save
      try {
        final id = _documentId ?? DateTime.now().millisecondsSinceEpoch.toString();
        await LocalDocsCache.saveDoc(
          id: id,
          title: _extractTitle(),
          content: _extractBody(),
        );
      } catch (_) {}
    }
  }

  Future<ExportFormat?> _showFormatPicker() async {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<ExportFormat>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t(
                  az: 'Fayl formatını seçin',
                  en: 'Choose file format',
                  ru: 'Выберите формат файла',
                  ar: 'اختر تنسيق الملف',
                ),
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _formatOption(
                      ctx,
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF',
                      subtitle: l10n.t(
                        az: 'Çap üçün ideal',
                        en: 'Ideal for printing',
                        ru: 'Идеально для печати',
                        ar: 'مثالي للطباعة',
                      ),
                      color: const Color(0xFFE53E3E),
                      onTap: () => Navigator.pop(ctx, ExportFormat.pdf),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _formatOption(
                      ctx,
                      icon: Icons.description_rounded,
                      label: 'Word',
                      subtitle: l10n.t(
                        az: 'Redaktə üçün ideal',
                        en: 'Ideal for editing',
                        ru: 'Идеально для редактирования',
                        ar: 'مثالي للتحرير',
                      ),
                      color: const Color(0xFF2B5CE6),
                      onTap: () => Navigator.pop(ctx, ExportFormat.word),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined),
                title: const Text('TXT'),
                subtitle: const Text('Plain text file'),
                onTap: () => Navigator.pop(ctx, ExportFormat.txt),
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('EPUB'),
                subtitle: const Text('E-book format'),
                onTap: () => Navigator.pop(ctx, ExportFormat.epub),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  l10n.cancel,
                  style: GoogleFonts.dmSans(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _formatOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(ctx);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPageSizePicker() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (context, setS) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.t(
                    az: 'Səhifə ölçüsü',
                    en: 'Page size',
                    ru: 'Размер страницы',
                    ar: 'حجم الصفحة',
                  ),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: PageSize.values.map((size) {
                    final isSelected = _pageSize == size;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _pageSize = size);
                          setS(() {});
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withAlpha(15)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Mini page preview
                              Container(
                                width: size == PageSize.a3
                                    ? 36
                                    : size == PageSize.a4
                                    ? 28
                                    : 22,
                                height: size == PageSize.a3
                                    ? 50
                                    : size == PageSize.a4
                                    ? 40
                                    : 30,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : theme.colorScheme.outline,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(20),
                                      blurRadius: 4,
                                      offset: const Offset(1, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                size.label,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                _pageSizeDimensions(size),
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 4),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.primary,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _pageSizeDimensions(PageSize size) {
    switch (size) {
      case PageSize.a3:
        return '297×420mm';
      case PageSize.a4:
        return '210×297mm';
      case PageSize.a5:
        return '148×210mm';
      case PageSize.letter:
        return '8.5×11in';
      case PageSize.legal:
        return '8.5×14in';
    }
  }

  void _onFormatTap(String format) {
    setState(() {
      switch (format) {
        case 'bold':
          _isBold = !_isBold;
          break;
        case 'italic':
          _isItalic = !_isItalic;
          break;
        case 'underline':
          _isUnderline = !_isUnderline;
          break;
        case 'strikethrough':
          _isStrikethrough = !_isStrikethrough;
          break;
        case 'align-left':
          _alignment = 'left';
          break;
        case 'align-center':
          _alignment = 'center';
          break;
        case 'align-right':
          _alignment = 'right';
          break;
        case 'align-justify':
          _alignment = 'justify';
          break;
      }
    });
  }

  TextAlign get _textAlign {
    switch (_alignment) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final l10n = AppLocalizations.of(context);
            return AlertDialog(
              title: Text(
                l10n.unsavedChanges,
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
              content: Text(l10n.saveBeforeExit, style: GoogleFonts.dmSans()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.cancel, style: GoogleFonts.dmSans()),
                ),
                FilledButton(
                  onPressed: () async {
                    await _saveDocument();
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: Text(l10n.saveAndExit, style: GoogleFonts.dmSans()),
                ),
              ],
            );
          },
        );
        if (shouldPop == true && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(theme),
              if (!_readingMode) _buildPageIndicator(theme),
              if (!_readingMode) _buildFormattingToolbar(theme),
              Expanded(child: _buildEditorBody(theme)),
              if (!_readingMode) _buildBottomToolbar(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final firstLine = _bodyCtrl.text.split('\n').first.trim();
    final title = firstLine.isEmpty ? l10n.untitledDocument : firstLine;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: theme.colorScheme.onSurface,
              size: 22,
            ),
            onPressed: () => context.pop(),
            padding: const EdgeInsets.all(8),
          ),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          IconButton(
            icon: Icon(
              _readingMode ? Icons.edit_rounded : Icons.menu_book_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: _toggleReadingMode,
            tooltip: 'Reading mode',
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: Icon(
              Icons.undo_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: _undo,
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: Icon(
              Icons.redo_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: _redo,
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: () => _showEditorOptions(context, theme),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    // Compute dynamic page count from current text
    final text = _bodyCtrl.text.isEmpty ? ' ' : _bodyCtrl.text;
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalMargin = 16.0;
    final availableWidth = screenWidth - horizontalMargin * 2;
    final scale = availableWidth / _pageSize.widthPx;
    final pageDisplayHeight = _pageSize.heightPx * scale;
    final pageDisplayWidth = availableWidth;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: _isBold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
          height: 1.7,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: _textAlign,
    )..layout(maxWidth: pageDisplayWidth - 64);
    final contentHeight = textPainter.height + 56;
    final containerHeight = contentHeight < pageDisplayHeight
        ? pageDisplayHeight
        : contentHeight;
    final totalPages = (containerHeight / pageDisplayHeight).ceil().clamp(
      1,
      9999,
    );
    // Current page: estimate from cursor position
    final cursorOffset = _bodyCtrl.selection.isValid
        ? _bodyCtrl.selection.baseOffset
        : 0;
    final cursorText = cursorOffset > 0 && cursorOffset <= text.length
        ? text.substring(0, cursorOffset)
        : '';
    final cursorPainter = TextPainter(
      text: TextSpan(
        text: cursorText.isEmpty ? ' ' : cursorText,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: _isBold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
          height: 1.7,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: _textAlign,
    )..layout(maxWidth: pageDisplayWidth - 64);
    final currentPage = ((cursorPainter.height + 56) / pageDisplayHeight)
        .ceil()
        .clamp(1, totalPages);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(80),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${l10n.page} $currentPage / $totalPages',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          // Page size selector button
          GestureDetector(
            onTap: _showPageSizePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _pageSize.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Row 1: B/I/U/S + alignment + lists
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _fmtBtn('B', 'bold', _isBold, theme, isBold: true),
                _fmtBtn('I', 'italic', _isItalic, theme, isItalic: true),
                _fmtBtn(
                  'U',
                  'underline',
                  _isUnderline,
                  theme,
                  isUnderline: true,
                ),
                _fmtBtn(
                  'S',
                  'strikethrough',
                  _isStrikethrough,
                  theme,
                  isStrikethrough: true,
                ),
                _divider(),
                _iconFmtBtn(
                  Icons.format_align_left_rounded,
                  'align-left',
                  _alignment == 'left',
                  theme,
                ),
                _iconFmtBtn(
                  Icons.format_align_center_rounded,
                  'align-center',
                  _alignment == 'center',
                  theme,
                ),
                _iconFmtBtn(
                  Icons.format_align_right_rounded,
                  'align-right',
                  _alignment == 'right',
                  theme,
                ),
                _iconFmtBtn(
                  Icons.format_align_justify_rounded,
                  'align-justify',
                  _alignment == 'justify',
                  theme,
                ),
                _divider(),
                _iconFmtBtn(
                  Icons.format_list_bulleted_rounded,
                  'bullet-list',
                  false,
                  theme,
                ),
                _iconFmtBtn(
                  Icons.format_list_numbered_rounded,
                  'numbered-list',
                  false,
                  theme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Row 2: Text / Color / Styles / More
          Row(
            children: [
              _toolbarAction(
                theme,
                Icons.text_fields_rounded,
                AppLocalizations.of(context).textStyle,
              ),
              _toolbarAction(
                theme,
                Icons.color_lens_outlined,
                AppLocalizations.of(context).color,
              ),
              _toolbarAction(
                theme,
                Icons.font_download_outlined,
                AppLocalizations.of(context).styles,
              ),
              _toolbarAction(
                theme,
                Icons.more_horiz_rounded,
                AppLocalizations.of(context).more,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fmtBtn(
    String label,
    String format,
    bool isActive,
    ThemeData theme, {
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    bool isStrikethrough = false,
  }) {
    return GestureDetector(
      onTap: () => _onFormatTap(format),
      child: Container(
        width: 34,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: AppTheme.primary.withAlpha(60))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: isUnderline
                  ? TextDecoration.underline
                  : isStrikethrough
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              color: isActive ? AppTheme.primary : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconFmtBtn(
    IconData icon,
    String format,
    bool isActive,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => _onFormatTap(format),
      child: Container(
        width: 34,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: AppTheme.primary.withAlpha(60))
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? AppTheme.primary : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppTheme.outlineLight,
    );
  }

  Widget _toolbarAction(ThemeData theme, IconData icon, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showToolbarSheet(context, theme, label),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurface),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorBody(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale the page to fit the screen width with margins
        final screenWidth = constraints.maxWidth;
        const horizontalMargin = 16.0;
        final availableWidth = screenWidth - horizontalMargin * 2;
        final scale = availableWidth / _pageSize.widthPx;
        final pageDisplayWidth = availableWidth;
        final pageDisplayHeight = _pageSize.heightPx * scale;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            children: [
              // Page container with shadow and boundary
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _bodyCtrl,
                builder: (context, value, child) {
                  return LayoutBuilder(
                    builder: (context, innerConstraints) {
                      // Estimate content height to determine number of pages
                      final textPainter =
                          TextPainter(
                            text: TextSpan(
                              text: value.text.isEmpty ? ' ' : value.text,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: _isBold
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                fontStyle: _isItalic
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                height: 1.7,
                              ),
                            ),
                            textDirection: TextDirection.ltr,
                            textAlign: _textAlign,
                          )..layout(
                            maxWidth:
                                pageDisplayWidth - 64, // 32px padding each side
                          );
                      final contentHeight =
                          textPainter.height + 56; // 28px top+bottom padding
                      final containerHeight = contentHeight < pageDisplayHeight
                          ? pageDisplayHeight
                          : contentHeight;
                      // How many page boundaries to draw
                      final pageCount = (containerHeight / pageDisplayHeight)
                          .ceil();

                      return Container(
                        width: pageDisplayWidth,
                        height: containerHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: Colors.black.withAlpha(15),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Page content
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  32,
                                  28,
                                  32,
                                  28,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _bodyCtrl,
                                      focusNode: _bodyFocusNode,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      style: GoogleFonts.dmSans(
                                        fontSize: _fontSize,
                                        fontWeight: _isBold
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        fontStyle: _isItalic
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                        decoration: _isUnderline
                                            ? TextDecoration.underline
                                            : _isStrikethrough
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        color: _textColor,
                                        height: 1.7,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.of(context).t(
                                          az: 'Başlığı özünüz yazın, sonra mətn əlavə edin...',
                                          en: 'Write your title, then add your content...',
                                          ru: 'Напишите заголовок, затем добавьте текст...',
                                          ar: 'اكتب العنوان ثم أضف المحتوى...',
                                        ),
                                        hintStyle: GoogleFonts.dmSans(
                                          fontSize: _fontSize,
                                          color: Colors.black38,
                                          height: 1.7,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      textAlign: _textAlign,
                                    ),
                                    // Embedded images (visible, resizable)
                                    ...List.generate(_embeddedImages.length, (idx) {
                                      final img = _embeddedImages[idx];
                                      final path = img['path'] as String;
                                      final w = (img['width'] as num?)?.toDouble() ?? 0.85;
                                      final f = File(path);
                                      if (!f.existsSync()) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Column(
                                          children: [
                                            GestureDetector(
                                              onLongPress: () async {
                                                final action = await showModalBottomSheet<String>(
                                                  context: context,
                                                  builder: (ctx) => SafeArea(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        ListTile(
                                                          leading: const Icon(Icons.photo_size_select_large),
                                                          title: const Text('Resize'),
                                                          onTap: () => Navigator.pop(ctx, 'resize'),
                                                        ),
                                                        ListTile(
                                                          leading: const Icon(Icons.delete_outline),
                                                          title: const Text('Remove'),
                                                          onTap: () => Navigator.pop(ctx, 'delete'),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                                if (action == 'delete') {
                                                  setState(() => _embeddedImages.removeAt(idx));
                                                } else if (action == 'resize') {
                                                  final r = await ImageInsertDialog.show(context, path);
                                                  if (r != null) {
                                                    setState(() {
                                                      _embeddedImages[idx]['width'] = r.widthFactor;
                                                    });
                                                  }
                                                }
                                              },
                                              child: Image.file(
                                                f,
                                                width: MediaQuery.of(context).size.width * w * 0.85,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            Text(
                                              'Long-press to resize or remove',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 11,
                                                color: Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            // Page boundary lines for each page break
                            for (int p = 1; p < pageCount; p++)
                              Positioned(
                                top: pageDisplayHeight * p,
                                left: 0,
                                right: 0,
                                child: _PageBoundaryLine(
                                  pageSize: _pageSize,
                                  pageNumber: p,
                                  totalPages: pageCount,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomToolbar(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$_wordCount ${l10n.wordCount}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _isSaving ? null : _saveDocument,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isSaved ? Icons.check_circle_rounded : Icons.save_outlined,
                    size: 16,
                    color: _isSaved ? AppTheme.success : AppTheme.primary,
                  ),
            label: Text(
              _isSaving ? l10n.saving : (_isSaved ? l10n.saved : l10n.save),
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isSaved ? AppTheme.success : AppTheme.primary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditorOptions(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _editorOption(
              ctx,
              Icons.picture_as_pdf_outlined,
              l10n.t(
                az: 'İxrac et (PDF/DOCX)',
                en: 'Export (PDF/DOCX)',
                ru: 'Экспорт (PDF/DOCX)',
                ar: 'تصدير (PDF/DOCX)',
              ),
              () {
                Navigator.pop(ctx);
                _saveDocument();
              },
            ),
            _editorOption(
              ctx,
              Icons.share_outlined,
              l10n.share,
              () => Navigator.pop(ctx),
            ),
            _editorOption(
              ctx,
              Icons.menu_book_outlined,
              l10n.t(
                az: 'Oxu rejimi',
                en: 'Reading mode',
                ru: 'Режим чтения',
                ar: 'وضع القراءة',
              ),
              () => Navigator.pop(ctx),
            ),
            _editorOption(
              ctx,
              Icons.article_outlined,
              l10n.t(
                az: 'Səhifə ölçüsü (${_pageSize.label})',
                en: 'Page size (${_pageSize.label})',
                ru: 'Размер страницы (${_pageSize.label})',
                ar: 'حجم الصفحة (${_pageSize.label})',
              ),
              () {
                Navigator.pop(ctx);
                _showPageSizePicker();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _editorOption(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary, size: 22),
      title: Text(
        label,
        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  void _showToolbarSheet(BuildContext context, ThemeData theme, String title) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (title == l10n.styles) return _buildFontStyleSheet(ctx, theme);
        if (title == l10n.color) return _buildColorSheet(ctx, theme);
        return _buildInsertSheet(ctx, theme);
      },
    );
  }

  Widget _buildFontStyleSheet(BuildContext ctx, ThemeData theme) {
    final l10n = AppLocalizations.of(ctx);
    final fonts = [
      'Roboto',
      'Times New Roman',
      'Arial',
      'Georgia',
      'Verdana',
      'Calibri',
      'Montserrat',
      'Lora',
    ];
    int selectedFont = fonts.indexOf(_fontFamily);
    if (selectedFont < 0) selectedFont = 0;
    double fontSize = _fontSize;
    int tab = 0; // 0 fonts, 1 size, 2 style
    bool bold = _isBold;
    bool italic = _isItalic;
    bool underline = _isUnderline;
    return StatefulBuilder(
      builder: (context, setS) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.t(
                      az: 'Yazı tərzi',
                      en: 'Font style',
                      ru: 'Стиль шрифта',
                      ar: 'نمط الخط',
                    ),
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => tab = 0),
                      child: _sheetTab(theme, l10n.fonts, tab == 0),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => tab = 1),
                      child: _sheetTab(theme, l10n.size, tab == 1),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => tab = 2),
                      child: _sheetTab(
                        theme,
                        l10n.t(
                          az: 'Stil',
                          en: 'Style',
                          ru: 'Стиль',
                          ar: 'النمط',
                        ),
                        tab == 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tab == 0
                  ? ListView.builder(
                      controller: scrollCtrl,
                      itemCount: fonts.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(
                          fonts[i],
                          style: GoogleFonts.dmSans(fontSize: 15),
                        ),
                        trailing: i == selectedFont
                            ? Icon(Icons.check_rounded,
                                color: AppTheme.primary)
                            : null,
                        onTap: () {
                          setS(() => selectedFont = i);
                          setState(() => _fontFamily = fonts[i]);
                        },
                      ),
                    )
                  : tab == 1
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                '${fontSize.round()} pt',
                                style: GoogleFonts.dmSans(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Slider(
                                value: fontSize,
                                min: 8,
                                max: 48,
                                divisions: 40,
                                activeColor: AppTheme.primary,
                                onChanged: (v) => setS(() => fontSize = v),
                                onChangeEnd: (v) {
                                  setState(() => _fontSize = v);
                                },
                              ),
                              Wrap(
                                spacing: 8,
                                children: [12, 14, 16, 18, 20, 24, 28, 32]
                                    .map(
                                      (s) => ActionChip(
                                        label: Text('$s'),
                                        onPressed: () {
                                          setS(() => fontSize = s.toDouble());
                                          setState(
                                              () => _fontSize = s.toDouble());
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollCtrl,
                          children: [
                            SwitchListTile(
                              title: const Text('Bold'),
                              value: bold,
                              onChanged: (v) {
                                setS(() => bold = v);
                                setState(() => _isBold = v);
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Italic'),
                              value: italic,
                              onChanged: (v) {
                                setS(() => italic = v);
                                setState(() => _isItalic = v);
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Underline'),
                              value: underline,
                              onChanged: (v) {
                                setS(() => underline = v);
                                setState(() => _isUnderline = v);
                              },
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSheet(BuildContext ctx, ThemeData theme) {
    final l10n = AppLocalizations.of(ctx);
    final colors = [
      Colors.black,
      Colors.grey.shade600,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.teal.shade700,
      Colors.blue.shade700,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.blue.shade300,
      Colors.purple.shade300,
      Colors.grey.shade400,
      Colors.white,
    ];
    int selectedColor = 0;
    bool isTextColor = true;
    return StatefulBuilder(
      builder: (context, setS) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.color,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _colorTab(
                      theme,
                      l10n.textColor,
                      isTextColor,
                      () => setS(() => isTextColor = true),
                    ),
                    const SizedBox(width: 8),
                    _colorTab(
                      theme,
                      l10n.background,
                      !isTextColor,
                      () => setS(() => isTextColor = false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(
                    colors.length,
                    (i) => GestureDetector(
                      onTap: () {
                        final c = colors[i];
                        final bg = !isTextColor;
                        Navigator.pop(ctx);
                        _applyColorToSelection(c, background: bg);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == selectedColor
                                ? AppTheme.primary
                                : Colors.grey.shade300,
                            width: i == selectedColor ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.t(
                    az: 'Xüsusi rəng',
                    en: 'Custom color',
                    ru: 'Произвольный цвет',
                    ar: 'لون مخصص',
                  ),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.black,
                        Color(0xFF1E3A8A),
                        Color(0xFF16A34A),
                        Colors.yellow,
                        Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#1E3A8A',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  Widget _buildInsertSheet(BuildContext ctx, ThemeData theme) {
    final l10n = AppLocalizations.of(ctx);
    final items = [
      {'icon': Icons.image_outlined, 'label': l10n.image, 'key': 'image'},
      {'icon': Icons.table_chart_outlined, 'label': l10n.table, 'key': 'table'},
      {'icon': Icons.link_rounded, 'label': l10n.link, 'key': 'link'},
      {'icon': Icons.emoji_symbols_rounded, 'label': l10n.symbol, 'key': 'symbol'},
      {'icon': Icons.bar_chart_rounded, 'label': l10n.diagram, 'key': 'diagram'},
      {'icon': Icons.insert_page_break_outlined, 'label': l10n.pageBreak, 'key': 'pageBreak'},
      {'icon': Icons.horizontal_rule_rounded, 'label': l10n.horizontalLine, 'key': 'hline'},
      {'icon': Icons.list_alt_rounded, 'label': 'Table of contents', 'key': 'toc'},
      {'icon': Icons.vertical_align_top_rounded, 'label': 'Header / Footer', 'key': 'header'},
      {'icon': Icons.padding_rounded, 'label': 'Margins', 'key': 'margins'},
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(ctx),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.insert,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: items.length,
              itemBuilder: (_, i) => ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    items[i]['icon'] as IconData,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  items[i]['label'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final label = items[i]['label'] as String;
                  final key = items[i]['key'] as String? ?? label;
                  switch (key) {
                    case 'image':
                      _pickImage();
                      break;
                    case 'table':
                      _insertTable();
                      break;
                    case 'link':
                      _insertLink();
                      break;
                    case 'symbol':
                      _insertAtCursor(' • ★ ✓ → ← © ® ™ § ¶ ');
                      break;
                    case 'diagram':
                      _ensurePremium('Diagram').then((ok) {
                        if (ok) {
                          _insertAtCursor(
                            '\n```\n  [Diagram]\n   A ---> B\n   B ---> C\n```\n',
                          );
                        }
                      });
                      break;
                    case 'pageBreak':
                      _ensurePremium('Page break').then((ok) {
                        if (ok) _insertAtCursor('\n\n--- Page Break ---\n\n');
                      });
                      break;
                    case 'hline':
                      _insertAtCursor('\n————————————————————\n');
                      break;
                    case 'toc':
                      _insertTableOfContents();
                      break;
                    case 'header':
                      _showHeaderFooterDialog();
                      break;
                    case 'margins':
                      _showMarginsPicker();
                      break;
                    default:
                      break;
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetTab(ThemeData theme, String label, bool isActive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? AppTheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _colorTab(
    ThemeData theme,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primary : theme.colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A dashed line widget that marks the end of a page
class _PageBoundaryLine extends StatelessWidget {
  final PageSize pageSize;
  final int pageNumber;
  final int totalPages;

  const _PageBoundaryLine({
    required this.pageSize,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(double.infinity, 1),
          painter: _DashedLinePainter(),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E).withAlpha(20),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFE53E3E).withAlpha(60),
                ),
              ),
              child: Text(
                '— ${pageSize.label} · $pageNumber / $totalPages —',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  color: const Color(0xFFE53E3E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53E3E).withAlpha(180)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}
