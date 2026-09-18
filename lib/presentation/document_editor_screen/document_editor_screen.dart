import '../../routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'widgets/table_editor_dialog.dart';
import 'widgets/document_settings_sheet.dart';
import 'dart:async';
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
  DocumentSettings _docSettings = DocumentSettings();
  Timer? _autoSaveTimer;

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
    if (data != null && data['settings'] is Map) {
      _applySettingsMap(Map<String, dynamic>.from(data['settings'] as Map));
    }
    _recoverImagesFromContent(existingContent);
    _bodyCtrl = TextEditingController(text: combined);
    _bodyCtrl.addListener(_onBodyChanged);
    _titleCtrl.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
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
    _checkPageLimit();
    _scheduleAutoSave();
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



  Map<String, dynamic> _settingsToMap() {
    return {
      'language': _docSettings.language,
      'pageSize': _docSettings.pageSize.name,
      'landscape': _docSettings.landscape,
      'marginMm': _docSettings.marginMm,
      'fontFamily': _docSettings.fontFamily,
      'fontSize': _docSettings.fontSize,
      'lineHeight': _docSettings.lineHeight,
      'showPageNumbers': _docSettings.showPageNumbers,
      'pageNumberPos': _docSettings.pageNumberPos,
      'headerText': _docSettings.headerText,
      'footerText': _docSettings.footerText,
      'autoSave': _docSettings.autoSave,
      'alignment': _alignment,
    };
  }

  void _applySettingsMap(Map<String, dynamic>? m) {
    if (m == null) return;
    try {
      final sizeName = m['pageSize']?.toString() ?? 'a4';
      final size = PageSize.values.firstWhere(
        (e) => e.name == sizeName,
        orElse: () => PageSize.a4,
      );
      _docSettings = DocumentSettings(
        language: m['language']?.toString() ?? 'en',
        pageSize: size,
        landscape: m['landscape'] == true,
        marginMm: (m['marginMm'] is num) ? (m['marginMm'] as num).toDouble() : 20,
        fontFamily: m['fontFamily']?.toString() ?? 'Roboto',
        fontSize: (m['fontSize'] is num) ? (m['fontSize'] as num).toDouble() : 16,
        lineHeight: (m['lineHeight'] is num) ? (m['lineHeight'] as num).toDouble() : 1.7,
        showPageNumbers: m['showPageNumbers'] != false,
        pageNumberPos: m['pageNumberPos']?.toString() ?? 'bottom-center',
        headerText: m['headerText']?.toString() ?? '',
        footerText: m['footerText']?.toString() ?? '',
        autoSave: m['autoSave'] != false,
      );
      _pageSize = size;
      _fontSize = _docSettings.fontSize;
      _fontFamily = _docSettings.fontFamily;
      _showPageNumbers = _docSettings.showPageNumbers;
      _headerText = _docSettings.headerText;
      _footerText = _docSettings.footerText;
      if (m['alignment'] is String) _alignment = m['alignment'] as String;
    } catch (_) {}
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    if (!_docSettings.autoSave) return;
    _autoSaveTimer = Timer(const Duration(seconds: 8), () {
      if (_hasUnsavedChanges && mounted) {
        _saveDocument();
      }
    });
  }

  Future<void> _openDocumentSettings(() async {
    final result = await showDocumentSettingsSheet(context, _docSettings);
    if (result == null || !mounted) return;
    setState(() {
      _docSettings = result;
      _pageSize = result.pageSize;
      _fontSize = result.fontSize;
      _fontFamily = result.fontFamily;
      _showPageNumbers = result.showPageNumbers;
      _headerText = result.headerText;
      _footerText = result.footerText;
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    _scheduleAutoSave();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document settings updated'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  double get _marginPx {
    // ~3.8 px per mm at 96dpi scale for on-screen padding
    return _docSettings.marginMm * 2.2;
  }


  void _showFindReplace() {
    final findCtrl = TextEditingController();
    final replaceCtrl = TextEditingController();
    int lastIndex = 0;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            int countMatches() {
              final f = findCtrl.text;
              if (f.isEmpty) return 0;
              return RegExp(RegExp.escape(f), caseSensitive: false)
                  .allMatches(_bodyCtrl.text)
                  .length;
            }
            return AlertDialog(
              title: const Text('Find & Replace'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: findCtrl,
                    decoration: const InputDecoration(labelText: 'Find'),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  TextField(
                    controller: replaceCtrl,
                    decoration: const InputDecoration(labelText: 'Replace with'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      findCtrl.text.isEmpty
                          ? 'Enter text to search'
                          : '${countMatches()} match(es)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    final f = findCtrl.text;
                    if (f.isEmpty) return;
                    final text = _bodyCtrl.text;
                    final lower = text.toLowerCase();
                    final q = f.toLowerCase();
                    var i = lower.indexOf(q, lastIndex);
                    if (i < 0) i = lower.indexOf(q);
                    if (i < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Not found')),
                      );
                      return;
                    }
                    lastIndex = i + f.length;
                    _bodyCtrl.selection = TextSelection(
                      baseOffset: i,
                      extentOffset: i + f.length,
                    );
                    _bodyFocusNode.requestFocus();
                    setLocal(() {});
                  },
                  child: const Text('Find next'),
                ),
                TextButton(
                  onPressed: () {
                    final f = findCtrl.text;
                    if (f.isEmpty) return;
                    final sel = _bodyCtrl.selection;
                    if (!sel.isValid || sel.isCollapsed) return;
                    final selected = _bodyCtrl.text.substring(sel.start, sel.end);
                    if (selected.toLowerCase() != f.toLowerCase()) return;
                    final newText = _bodyCtrl.text.replaceRange(
                      sel.start,
                      sel.end,
                      replaceCtrl.text,
                    );
                    _bodyCtrl.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(
                        offset: sel.start + replaceCtrl.text.length,
                      ),
                    );
                    setState(() {
                      _hasUnsavedChanges = true;
                      _isSaved = false;
                    });
                    setLocal(() {});
                  },
                  child: const Text('Replace'),
                ),
                FilledButton(
                  onPressed: () {
                    final f = findCtrl.text;
                    if (f.isEmpty) return;
                    final re = RegExp(RegExp.escape(f), caseSensitive: false);
                    final newText = _bodyCtrl.text.replaceAll(re, replaceCtrl.text);
                    _bodyCtrl.text = newText;
                    setState(() {
                      _hasUnsavedChanges = true;
                      _isSaved = false;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Replaced all')),
                    );
                  },
                  child: const Text('Replace all'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Strip heading / quote / list prefixes from a paragraph line.
  String _stripStylePrefix(String line) {
    var s = line;
    s = s.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
    s = s.replaceFirst(RegExp(r'^>\s*(\*\*Note:\*\*\s*)?'), '');
    s = s.replaceFirst(RegExp(r'^[•\-\*]\s+'), '');
    s = s.replaceFirst(RegExp(r'^\d+\.\s+'), '');
    return s;
  }

  void _applyStyle(String style) {
    final text = _bodyCtrl.text;
    final sel = _bodyCtrl.selection;
    final pos = sel.isValid ? sel.start : text.length;
    // Work on whole paragraph
    var lineStart = text.lastIndexOf('\n', pos - 1) + 1;
    if (lineStart < 0) lineStart = 0;
    var lineEnd = text.indexOf('\n', pos);
    if (lineEnd < 0) lineEnd = text.length;
    var line = text.substring(lineStart, lineEnd);
    final body = _stripStylePrefix(line);

    String next;
    switch (style) {
      case 'h1':
      case 'chapter':
        next = '# ${body.isEmpty ? 'Chapter' : body}';
        break;
      case 'h2':
      case 'subchapter':
        next = '## ${body.isEmpty ? 'Section' : body}';
        break;
      case 'h3':
        next = '### ${body.isEmpty ? 'Subsection' : body}';
        break;
      case 'h4':
        next = '#### ${body.isEmpty ? 'Title' : body}';
        break;
      case 'quote':
        next = '> $body';
        break;
      case 'note':
        next = '> **Note:** $body';
        break;
      case 'bullet':
        next = '• $body';
        break;
      case 'number':
        next = '1. $body';
        break;
      case 'caption':
        next = '_${body.isEmpty ? 'Caption' : body}_';
        break;
      case 'normal':
        next = body;
        break;
      default:
        next = body;
    }

    final newText = text.replaceRange(lineStart, lineEnd, next);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lineStart + next.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    _bodyFocusNode.requestFocus();
  }

  void _showStylesSheet() {
    final items = <Map<String, String>>[
      {'id': 'h1', 'label': 'Heading 1', 'sample': '# Title'},
      {'id': 'h2', 'label': 'Heading 2', 'sample': '## Section'},
      {'id': 'h3', 'label': 'Heading 3', 'sample': '### Subsection'},
      {'id': 'h4', 'label': 'Heading 4', 'sample': '#### Minor'},
      {'id': 'normal', 'label': 'Normal text', 'sample': 'Paragraph'},
      {'id': 'quote', 'label': 'Quote', 'sample': '> Quoted text'},
      {'id': 'note', 'label': 'Note', 'sample': '> **Note:** …'},
      {'id': 'caption', 'label': 'Caption', 'sample': '_Figure caption_'},
      {'id': 'bullet', 'label': 'Bullet list', 'sample': '• Item'},
      {'id': 'number', 'label': 'Numbered list', 'sample': '1. Item'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Styles',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  return ListTile(
                    title: Text(
                      it['label']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      it['sample']!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _applyStyle(it['id']!);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }



  void _transformCase(String mode) {
    final sel = _bodyCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select text first')),
      );
      return;
    }
    var s = _bodyCtrl.text.substring(sel.start, sel.end);
    switch (mode) {
      case 'upper':
        s = s.toUpperCase();
        break;
      case 'lower':
        s = s.toLowerCase();
        break;
      case 'title':
        s = s.split(' ').map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
        }).join(' ');
        break;
    }
    final newText = _bodyCtrl.text.replaceRange(sel.start, sel.end, s);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: sel.start, extentOffset: sel.start + s.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _showChaptersPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final full = _bodyCtrl.text;
            final lines = full.split('\n');
            final chapters = <Map<String, dynamic>>[];
            var offset = 0;
            for (var li = 0; li < lines.length; li++) {
              final line = lines[li];
              int? level;
              String title = '';
              if (line.startsWith('#### ')) {
                level = 4;
                title = line.substring(5).trim();
              } else if (line.startsWith('### ')) {
                level = 3;
                title = line.substring(4).trim();
              } else if (line.startsWith('## ')) {
                level = 2;
                title = line.substring(3).trim();
              } else if (line.startsWith('# ')) {
                level = 1;
                title = line.substring(2).trim();
              }
              if (level != null) {
                chapters.add({
                  'title': title.isEmpty ? 'Untitled' : title,
                  'offset': offset,
                  'level': level,
                  'line': li,
                });
              }
              offset += line.length + 1;
            }
            // Word count per chapter: from this heading to next same-or-higher level
            for (var i = 0; i < chapters.length; i++) {
              final startOff = chapters[i]['offset'] as int;
              final myLevel = chapters[i]['level'] as int;
              int endOff = full.length;
              for (var j = i + 1; j < chapters.length; j++) {
                if ((chapters[j]['level'] as int) <= myLevel) {
                  endOff = chapters[j]['offset'] as int;
                  break;
                }
              }
              final body = full.substring(startOff, endOff);
              final words = body
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty)
                  .length;
              // rough pages: ~250 words/page
              final pages = (words / 250).clamp(0.1, 9999.0);
              chapters[i]['words'] = words;
              chapters[i]['pages'] = pages;
            }
            final totalWords = full
                .trim()
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length;
            final totalPages = (totalWords / 250).ceil().clamp(1, 999999);

            void applyLines(List<String> ls) {
              _bodyCtrl.text = ls.join('\n');
              setState(() {
                _hasUnsavedChanges = true;
                _isSaved = false;
              });
              setLocal(() {});
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chapters (${chapters.length})',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '$totalWords words · ~$totalPages pages · ~${(totalWords / 200).ceil()} min read',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            tooltip: 'Add chapter',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _applyStyle('chapter');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: chapters.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No chapters yet.\nUse + or Heading 1 (# ) for chapters.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.dmSans(color: Colors.white54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: chapters.length,
                              itemBuilder: (_, i) {
                                final c = chapters[i];
                                final level = c['level'] as int;
                                final pad = 8.0 + (level - 1) * 12.0;
                                return ListTile(
                                  contentPadding: EdgeInsets.only(
                                    left: pad,
                                    right: 8,
                                  ),
                                  leading: Icon(
                                    level == 1
                                        ? Icons.menu_book
                                        : level == 2
                                            ? Icons.subdirectory_arrow_right
                                            : Icons.circle,
                                    size: level >= 3 ? 10 : 22,
                                    color: const Color(0xFFD4A84B),
                                  ),
                                  title: Text(
                                    c['title'] as String,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontWeight: level == 1
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'H$level · ${c['words']} words · ~${(c['pages'] as double).toStringAsFixed(1)} p',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    final off = c['offset'] as int;
                                    _bodyCtrl.selection =
                                        TextSelection.collapsed(offset: off);
                                    _bodyFocusNode.requestFocus();
                                  },
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert,
                                        color: Colors.white54),
                                    color: const Color(0xFF1E1E1E),
                                    onSelected: (action) {
                                      final lineIdx = c['line'] as int;
                                      final ls = _bodyCtrl.text.split('\n');
                                      if (action == 'rename') {
                                        final ctrl = TextEditingController(
                                          text: c['title'] as String,
                                        );
                                        showDialog(
                                          context: context,
                                          builder: (dctx) => AlertDialog(
                                            title: const Text('Rename'),
                                            content: TextField(controller: ctrl),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dctx),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () {
                                                  final prefix = '#' * level + ' ';
                                                  ls[lineIdx] =
                                                      prefix + ctrl.text.trim();
                                                  Navigator.pop(dctx);
                                                  applyLines(ls);
                                                },
                                                child: const Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else if (action == 'delete') {
                                        ls.removeAt(lineIdx);
                                        applyLines(ls);
                                      } else if (action == 'up' &&
                                          lineIdx > 0) {
                                        final tmp = ls[lineIdx - 1];
                                        ls[lineIdx - 1] = ls[lineIdx];
                                        ls[lineIdx] = tmp;
                                        applyLines(ls);
                                      } else if (action == 'down' &&
                                          lineIdx < ls.length - 1) {
                                        final tmp = ls[lineIdx + 1];
                                        ls[lineIdx + 1] = ls[lineIdx];
                                        ls[lineIdx] = tmp;
                                        applyLines(ls);
                                      } else if (action == 'duplicate') {
                                        ls.insert(lineIdx + 1, ls[lineIdx]);
                                        applyLines(ls);
                                      } else if (action == 'sub') {
                                        // demote: add one #
                                        final raw = ls[lineIdx];
                                        if (!raw.startsWith('####')) {
                                          ls[lineIdx] = '#$raw';
                                          applyLines(ls);
                                        }
                                      } else if (action == 'promote') {
                                        final raw = ls[lineIdx];
                                        if (raw.startsWith('##')) {
                                          ls[lineIdx] = raw.substring(1);
                                          applyLines(ls);
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'rename',
                                          child: Text('Rename',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'duplicate',
                                          child: Text('Duplicate heading',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'promote',
                                          child: Text('Promote (H level -)',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'sub',
                                          child: Text('Demote (H level +)',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'up',
                                          child: Text('Move up',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'down',
                                          child: Text('Move down',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete heading',
                                              style: TextStyle(
                                                  color: Colors.redAccent))),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _insertTableOfContents();
                              },
                              icon: const Icon(Icons.list_alt),
                              label: const Text('TOC'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _applyStyle('chapter');
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Chapter'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2B5CE6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }




  void _recoverImagesFromContent(String content) {
    final re = RegExp(
      r'\[img path="([^"]+)" w=([0-9.]+)(?: align=(left|center|right))?(?: caption="([^"]*)")?\]',
    );
    for (final m in re.allMatches(content)) {
      final path = m.group(1)!;
      final w = double.tryParse(m.group(2) ?? '0.85') ?? 0.85;
      final align = m.group(3) ?? 'center';
      final caption = m.group(4) ?? '';
      if (_embeddedImages.any((e) => e['path'] == path)) continue;
      _embeddedImages.add({
        'path': path,
        'width': w,
        'align': align,
        'caption': caption,
      });
    }
  }

  String _imgMarkup(Map<String, dynamic> img) {
    final path = img['path'];
    final w = (img['width'] as num?)?.toDouble() ?? 0.85;
    final align = img['align']?.toString() ?? 'center';
    final caption = img['caption']?.toString() ?? '';
    var s = '[img path="$path" w=${w.toStringAsFixed(2)} align=$align';
    if (caption.isNotEmpty) {
      s += ' caption="${caption.replaceAll('"', "'")}"';
    }
    s += ']';
    return s;
  }

  Future<void> _editImageAt(int idx() async {
    if (idx < 0 || idx >= _embeddedImages.length) return;
    final img = _embeddedImages[idx];
    final path = img['path'] as String;
    final result = await ImageInsertDialog.show(
      context,
      path,
      width: (img['width'] as num?)?.toDouble() ?? 0.85,
      caption: img['caption']?.toString() ?? '',
      align: img['align']?.toString() ?? 'center',
      editing: true,
    );
    if (result == null) return;
    final oldMarkup = _imgMarkup(img);
    setState(() {
      _embeddedImages[idx] = {
        'path': result.path,
        'width': result.widthFactor,
        'align': result.align,
        'caption': result.caption,
      };
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    final newMarkup = _imgMarkup(_embeddedImages[idx]);
    if (_bodyCtrl.text.contains(oldMarkup)) {
      _bodyCtrl.text = _bodyCtrl.text.replaceFirst(oldMarkup, newMarkup);
    } else {
      // fuzzy: replace by path only
      final re = RegExp(r'\[img path="' + RegExp.escape(path) + r'"[^\]]*\]');
      _bodyCtrl.text = _bodyCtrl.text.replaceFirst(re, newMarkup);
    }
  }

  void _deleteImageAt(int idx) {
    if (idx < 0 || idx >= _embeddedImages.length) return;
    final img = _embeddedImages[idx];
    final path = img['path'] as String;
    final markup = _imgMarkup(img);
    var text = _bodyCtrl.text;
    if (text.contains(markup)) {
      text = text.replaceFirst(markup, '');
    } else {
      text = text.replaceFirst(
        RegExp(r'\[img path="' + RegExp.escape(path) + r'"[^\]]*\]'),
        '',
      );
    }
    _bodyCtrl.text = text;
    setState(() {
      _embeddedImages.removeAt(idx);
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
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

  /// Strip existing size/color/bg markers from a fragment (inner only).
  String _stripInlineMarkers(String s) {
    s = s.replaceAll(RegExp(r'\[color=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/color]', '');
    s = s.replaceAll(RegExp(r'\[bg=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/bg]', '');
    s = s.replaceAll(RegExp(r'\[size=\d+\]'), '');
    s = s.replaceAll('[/size]', '');
    return s;
  }

  /// Apply color / highlight only to the current selection (not whole document).
  void _applyColorToSelection(Color color, {required bool background}) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    if (!sel.isValid || sel.isCollapsed) {
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
                ? 'Default page background set. Select text to highlight words only.'
                : 'Select a word or sentence first — color applies only to selection.',
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
    var selected = _stripInlineMarkers(text.substring(start, end));
    final hex =
        '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final wrapped = background
        ? '[bg=$hex]$selected[/bg]'
        : '[color=$hex]$selected[/color]';
    final newText = text.replaceRange(start, end, wrapped);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + wrapped.length,
      ),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          background ? 'Highlight applied to selection' : 'Text color applied to selection',
          style: GoogleFonts.dmSans(),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Font size only on selection: [size=18]text[/size]
  void _applySizeToSelection(double size) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final sz = size.round().clamp(10, 48);
    if (!sel.isValid || sel.isCollapsed) {
      setState(() => _fontSize = size);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Editor default size: $sz. Select text to change only that part.',
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
    var selected = _stripInlineMarkers(text.substring(start, end));
    final wrapped = '[size=$sz]$selected[/size]';
    final newText = text.replaceRange(start, end, wrapped);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + wrapped.length,
      ),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Size $sz applied to selection', style: GoogleFonts.dmSans()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearSelectionFormat() {
    final sel = _bodyCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select text first to clear format')),
      );
      return;
    }
    final start = sel.start;
    final end = sel.end;
    final cleaned = _stripInlineMarkers(_bodyCtrl.text.substring(start, end));
    // also light markdown
    var s = cleaned;
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m.group(1)!);
    final newText = _bodyCtrl.text.replaceRange(start, end, s);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: start, extentOffset: start + s.length),
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

  Future<void> _checkPageLimit(() async {
    // Estimate pages from text length vs page body (same idea as indicator)
    final text = _bodyCtrl.text.isEmpty ? ' ' : _bodyCtrl.text;
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32;
    final scale = availableWidth / _pageSize.widthPx;
    final pageDisplayHeight = _pageSize.heightPx * scale;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: _fontSize, height: _docSettings.lineHeight),
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
          ? 'This document is over ${PremiumService.maxPagesFree} pages (Free limit). Pro (2.75 USD/mo): up to 150 pages. Elite (5.75 USD/mo): unlimited length. You can still read and export; upgrade to keep writing longer books.'
          : tier == PlanTier.pro
              ? 'Pro allows up to ${PremiumService.maxPagesPro} pages. Elite (5.75 USD/mo) removes the page limit for long books.'
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

  Future<void> _pickImage(() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (file == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final name =
          'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(file.path).copy('${dir.path}/$name');

      if (!mounted) return;
      final result = await ImageInsertDialog.show(context, saved.path);
      if (result == null) return;

      final entry = {
        'path': result.path,
        'width': result.widthFactor,
        'align': result.align,
        'caption': result.caption,
      };
      setState(() {
        _embeddedImages.removeWhere((e) => e['path'] == result.path);
        _embeddedImages.add(entry);
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
      _insertAtCursor('\n${_imgMarkup(entry)}\n');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image inserted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<void> _insertLink(() async {
    final sel = _bodyCtrl.selection;
    var selected = '';
    if (sel.isValid && !sel.isCollapsed) {
      selected = _bodyCtrl.text.substring(sel.start, sel.end);
    }
    final md = await LinkInsertDialog.show(context, selected: selected);
    if (md == null || md.isEmpty) return;
    _insertAtCursor(md);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link inserted'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _insertTable({int rows = 3, int cols = 3}() async {
    // If cursor is inside an existing [TABLE] block → edit it
    final cursor = _bodyCtrl.selection.isValid
        ? _bodyCtrl.selection.start
        : _bodyCtrl.text.length;
    final existing = TableBlock.findAt(_bodyCtrl.text, cursor);
    if (existing != null) {
      final md = await TableEditorDialog.show(
        context,
        data: existing.cells,
        widths: existing.colWidths,
        editing: true,
      );
      if (md == null || md.isEmpty) return;
      final newText = _bodyCtrl.text.replaceRange(existing.start, existing.end, md.trim());
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: existing.start + md.trim().length),
      );
      setState(() {
        _hasUnsavedChanges = true;
        _isSaved = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Table updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final md = await TableEditorDialog.show(context);
    if (md == null || md.isEmpty) return;
    _insertAtCursor(md);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Table inserted — put cursor inside to edit again'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
() async {
    final md = await TableEditorDialog.show(context);
    if (md == null || md.isEmpty) return;
    _insertAtCursor(md);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Table inserted'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }


  static final RegExp _tocBlockRe = RegExp(
    r'\[TOC\][\s\S]*?\[/TOC\]',
    multiLine: true,
  );

  /// Build TOC body from headings (excludes existing TOC titles).
  String _buildTocBody({int maxLevel = 3}) {
    final lines = _bodyCtrl.text.split('\n');
    final buf = StringBuffer();
    var n = 0;
    for (final line in lines) {
      final tline = line.trim();
      if (tline.toLowerCase().contains('table of contents')) continue;
      if (tline == '[TOC]' || tline == '[/TOC]') continue;
      if (tline.startsWith('# ') && !tline.startsWith('## ')) {
        if (maxLevel >= 1) {
          n++;
          buf.writeln('$n. ${tline.substring(2).trim()}');
        }
      } else if (tline.startsWith('## ') && !tline.startsWith('### ')) {
        if (maxLevel >= 2) {
          buf.writeln('   - ${tline.substring(3).trim()}');
        }
      } else if (tline.startsWith('### ') && !tline.startsWith('#### ')) {
        if (maxLevel >= 3) {
          buf.writeln('      · ${tline.substring(4).trim()}');
        }
      } else if (tline.startsWith('#### ') && maxLevel >= 4) {
        buf.writeln('         · ${tline.substring(5).trim()}');
      }
    }
    if (n == 0 && buf.isEmpty) {
      buf.writeln('_No headings yet. Add Heading 1 chapters first._');
    }
    return buf.toString().trimRight();
  }

  String _wrapToc(String body) {
    return '\n[TOC]\n# Table of Contents\n\n$body\n[/TOC]\n';
  }

  void _insertTableOfContents({int maxLevel = 3, bool ask = true}) {
    if (ask) {
      _showTocOptions();
      return;
    }
    final body = _buildTocBody(maxLevel: maxLevel);
    final toc = _wrapToc(body);
    var text = _bodyCtrl.text;
    final has = _tocBlockRe.hasMatch(text);
    // Also remove legacy "# Table of Contents" blocks without markers
    final legacy = RegExp(
      r'\n# Table of Contents\n(?:.*\n)*?(?=\n# |\n## |\Z)',
      multiLine: true,
    );
    text = text.replaceAll(_tocBlockRe, '');
    text = text.replaceFirst(legacy, '\n');
    final newText = toc + text.trimLeft();
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: toc.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(has ? 'Table of Contents updated' : 'Table of Contents inserted'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _refreshTableOfContents() {
    if (!_tocBlockRe.hasMatch(_bodyCtrl.text) &&
        !_bodyCtrl.text.contains('# Table of Contents')) {
      _insertTableOfContents(ask: false);
      return;
    }
    _insertTableOfContents(ask: false);
  }

  void _deleteTableOfContents() {
    var text = _bodyCtrl.text;
    text = text.replaceAll(_tocBlockRe, '');
    text = text.replaceFirst(
      RegExp(r'\n# Table of Contents\n(?:.*\n)*?(?=\n# |\n## |\Z)', multiLine: true),
      '\n',
    );
    _bodyCtrl.text = text;
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TOC removed'), duration: Duration(seconds: 1)),
    );
  }

  void _showTocOptions() {
    final has = _tocBlockRe.hasMatch(_bodyCtrl.text) ||
        _bodyCtrl.text.contains('# Table of Contents');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Table of Contents',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white70),
              title: Text(
                has ? 'Refresh TOC' : 'Insert TOC',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                has ? 'Update from current headings' : 'H1–H3 at top of document',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _insertTableOfContents(maxLevel: 3, ask: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_1, color: Colors.white70),
              title: const Text('TOC — chapters only (H1)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _insertTableOfContents(maxLevel: 1, ask: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_2, color: Colors.white70),
              title: const Text('TOC — H1 + H2',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _insertTableOfContents(maxLevel: 2, ask: false);
              },
            ),
            if (has)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete TOC',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteTableOfContents();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }




  void _showHeaderFooterDialog() {
    final headerCtrl = TextEditingController(text: _headerText);
    final footerCtrl = TextEditingController(text: _footerText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Header & Footer',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quick fill',
                      style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Book title'),
                          onPressed: () {
                            final title = _titleCtrl.text.trim().isNotEmpty
                                ? _titleCtrl.text.trim()
                                : _extractTitle();
                            headerCtrl.text = title;
                            setLocal(() {});
                          },
                        ),
                        ActionChip(
                          label: const Text('Chapter'),
                          onPressed: () {
                            // nearest H1 above cursor
                            final pos = _bodyCtrl.selection.isValid
                                ? _bodyCtrl.selection.start
                                : 0;
                            final before = _bodyCtrl.text.substring(0, pos);
                            final lines = before.split('\n').reversed;
                            String ch = 'Chapter';
                            for (final line in lines) {
                              if (line.startsWith('# ')) {
                                ch = line.substring(2).trim();
                                break;
                              }
                            }
                            headerCtrl.text = ch;
                            setLocal(() {});
                          },
                        ),
                        ActionChip(
                          label: const Text('Author'),
                          onPressed: () {
                            headerCtrl.text = 'Author Name';
                            setLocal(() {});
                          },
                        ),
                        ActionChip(
                          label: const Text('Date'),
                          onPressed: () {
                            final d = DateTime.now();
                            footerCtrl.text =
                                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                            setLocal(() {});
                          },
                        ),
                        ActionChip(
                          label: const Text('Title · Chapter'),
                          onPressed: () {
                            final title = _titleCtrl.text.trim().isNotEmpty
                                ? _titleCtrl.text.trim()
                                : 'Nibras Docs';
                            final pos = _bodyCtrl.selection.isValid
                                ? _bodyCtrl.selection.start
                                : 0;
                            final before = _bodyCtrl.text.substring(0, pos);
                            String ch = '';
                            for (final line in before.split('\n').reversed) {
                              if (line.startsWith('# ')) {
                                ch = line.substring(2).trim();
                                break;
                              }
                            }
                            headerCtrl.text =
                                ch.isEmpty ? title : '$title · $ch';
                            setLocal(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: headerCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Header (top of page)',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'Book title / chapter / author',
                        hintStyle: TextStyle(color: Colors.white30),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: footerCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Footer (bottom of page)',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'Author / date / custom',
                        hintStyle: TextStyle(color: Colors.white30),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Page numbers',
                          style: TextStyle(color: Colors.white)),
                      value: _showPageNumbers,
                      onChanged: (v) => setLocal(() {
                        _showPageNumbers = v;
                      }),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _headerText = headerCtrl.text.trim();
                            _footerText = footerCtrl.text.trim();
                            _docSettings.headerText = _headerText;
                            _docSettings.footerText = _footerText;
                            _docSettings.showPageNumbers = _showPageNumbers;
                            _hasUnsavedChanges = true;
                            _isSaved = false;
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Header & footer saved'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2B5CE6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Apply',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  Future<void> _saveDocument(() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final title = _titleCtrl.text.trim().isNotEmpty
          ? _titleCtrl.text.trim()
          : _extractTitle();
      final content = _bodyCtrl.text;
      // Ensure stable local id
      _documentId ??= 'local_${DateTime.now().millisecondsSinceEpoch}';
      await LocalDocsCache.saveDoc(
        id: _documentId!,
        title: title,
        content: content,
        settings: _settingsToMap(),
      );
      // Optional cloud
      try {
        if (SupabaseService.instance.isReady &&
            SupabaseService.instance.isAuthenticated) {
          await _saveToDatabase();
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isSaved = true;
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved',
              style: GoogleFonts.dmSans(),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _exportDocument(() async {
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
        showPageNumbers: _showPageNumbers,
        pageNumberPos: _docSettings.pageNumberPos,
        headerText: _headerText,
        footerText: _footerText,
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

  Future<void> _saveToDatabase(() async {
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

  Future<ExportFormat?> _showFormatPicker(() async {
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

  /// Part 2: format selection for real — wraps text in markers stored in document.
  void _wrapSelection(String left, String right) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    if (!sel.isValid) return;
    if (sel.isCollapsed) {
      // Insert markers and place cursor between them
      final i = sel.start;
      final snippet = '$left$right';
      final newText = text.replaceRange(i, i, snippet);
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: i + left.length),
      );
    } else {
      final selected = text.substring(sel.start, sel.end);
      // Toggle off if already wrapped
      String next;
      if (selected.startsWith(left) && selected.endsWith(right) && selected.length >= left.length + right.length) {
        next = selected.substring(left.length, selected.length - right.length);
      } else {
        next = '$left$selected$right';
      }
      final newText = text.replaceRange(sel.start, sel.end, next);
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start,
          extentOffset: sel.start + next.length,
        ),
      );
    }
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
    _pushHistory();
  }


  /// Current paragraph range containing the cursor.
  (int, int) _paragraphRange() {
    final text = _bodyCtrl.text;
    final pos = _bodyCtrl.selection.isValid
        ? _bodyCtrl.selection.start
        : text.length;
    var start = text.lastIndexOf('\n', pos - 1) + 1;
    if (start < 0) start = 0;
    var end = text.indexOf('\n', pos);
    if (end < 0) end = text.length;
    return (start, end);
  }

  void _indentParagraph(int delta) {
    final text = _bodyCtrl.text;
    final (start, end) = _paragraphRange();
    var para = text.substring(start, end);
    // Count leading spaces (2 per level)
    final leading = RegExp(r'^ *').firstMatch(para)?.group(0)?.length ?? 0;
    final level = (leading ~/ 2 + delta).clamp(0, 8);
    para = para.replaceFirst(RegExp(r'^ *'), '');
    para = ('  ' * level) + para;
    final newText = text.replaceRange(start, end, para);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + para.length),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _setParagraphAlign(String align) {
    setState(() => _alignment = align);
    final text = _bodyCtrl.text;
    final (start, end) = _paragraphRange();
    var para = text.substring(start, end);
    // strip old align marker at start
    para = para.replaceFirst(RegExp(r'^\[align=(left|center|right|justify)\]'), '');
    if (align != 'left') {
      para = '[align=$align]$para';
    }
    final newText = text.replaceRange(start, end, para);
    final cursor = start + para.length;
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
    setState(() {
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }



  void _showPageNumberOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Show page numbers'),
              value: _showPageNumbers,
              onChanged: (v) {
                setState(() {
                  _showPageNumbers = v;
                  _docSettings.showPageNumbers = v;
                  _hasUnsavedChanges = true;
                });
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            for (final pos in [
              'bottom-center',
              'bottom-left',
              'bottom-right',
              'top-center',
              'top-left',
              'top-right',
            ])
              ListTile(
                title: Text(pos),
                trailing: _docSettings.pageNumberPos == pos
                    ? const Icon(Icons.check, color: Color(0xFF2B5CE6))
                    : null,
                onTap: () {
                  setState(() {
                    _docSettings.pageNumberPos = pos;
                    _showPageNumbers = true;
                    _docSettings.showPageNumbers = true;
                    _hasUnsavedChanges = true;
                  });
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
  void _showLineSpacingPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Line spacing',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            ),
            for (final h in [1.0, 1.15, 1.5, 1.7, 2.0, 2.5])
              ListTile(
                title: Text(h.toStringAsFixed(2)),
                trailing: (_docSettings.lineHeight - h).abs() < 0.01
                    ? const Icon(Icons.check, color: Color(0xFF2B5CE6))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setLineHeight(h);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _setLineHeight(double h) {
    setState(() {
      _docSettings.lineHeight = h;
      _hasUnsavedChanges = true;
      _isSaved = false;
    });
  }

  void _onFormatTap(String format) {
    switch (format) {
      case 'bold':
        _wrapSelection('**', '**');
        setState(() => _isBold = !_isBold);
        break;
      case 'italic':
        _wrapSelection('*', '*');
        setState(() => _isItalic = !_isItalic);
        break;
      case 'underline':
        _wrapSelection('__', '__');
        setState(() => _isUnderline = !_isUnderline);
        break;
      case 'strikethrough':
        _wrapSelection('~~', '~~');
        setState(() => _isStrikethrough = !_isStrikethrough);
        break;
      case 'align-left':
        _setParagraphAlign('left');
        break;
      case 'align-center':
        _setParagraphAlign('center');
        break;
      case 'align-right':
        _setParagraphAlign('right');
        break;
      case 'align-justify':
        _setParagraphAlign('justify');
        break;
      case 'bullet':
        _applyStyle('bullet');
        break;
      case 'number':
        _applyStyle('number');
        break;
      case 'indent-more':
        _indentParagraph(1);
        break;
      case 'indent-less':
        _indentParagraph(-1);
        break;
    }
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
      onPopInvokedWithResult: (didPop, result() async {
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
                  onPressed: (() async {
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
          height: _docSettings.lineHeight,
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
          height: _docSettings.lineHeight,
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
                _iconFmtBtn(
                  Icons.format_indent_increase_rounded,
                  'indent-more',
                  false,
                  theme,
                ),
                _iconFmtBtn(
                  Icons.format_indent_decrease_rounded,
                  'indent-less',
                  false,
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
                                height: _docSettings.lineHeight,
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
                                        height: _docSettings.lineHeight,
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
                                          height: _docSettings.lineHeight,
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
                                      final align = img['align']?.toString() ?? 'center';
                                      final caption = img['caption']?.toString() ?? '';
                                      final f = File(path);
                                      if (!f.existsSync()) {
                                        return const SizedBox.shrink();
                                      }
                                      AlignmentGeometry al = Alignment.center;
                                      if (align == 'left') al = Alignment.centerLeft;
                                      if (align == 'right') al = Alignment.centerRight;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Column(
                                          children: [
                                            Align(
                                              alignment: al,
                                              child: GestureDetector(
                                                onLongPress: (() async {
                                                  final action = await showModalBottomSheet<String>(
                                                    context: context,
                                                    builder: (ctx) => SafeArea(
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          ListTile(
                                                            leading: const Icon(Icons.edit_outlined),
                                                            title: const Text('Edit size / caption / position'),
                                                            onTap: () => Navigator.pop(ctx, 'edit'),
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
                                                  if (action == 'edit') {
                                                    await _editImageAt(idx);
                                                  } else if (action == 'delete') {
                                                    _deleteImageAt(idx);
                                                  }
                                                },
                                                child: Image.file(
                                                  f,
                                                  width: MediaQuery.of(context).size.width * w * 0.9,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                            if (caption.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Text(
                                                  caption,
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.black54,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            Text(
                                              'Long-press to edit or remove',
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
                            // Header strip
                            if (_headerText.isNotEmpty ||
                                (_showPageNumbers &&
                                    _docSettings.pageNumberPos.startsWith('top')))
                              Positioned(
                                top: 8,
                                left: 16,
                                right: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _headerText.isNotEmpty
                                            ? _headerText
                                            : '',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 10,
                                          color: Colors.black45,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_showPageNumbers &&
                                        _docSettings.pageNumberPos.startsWith('top'))
                                      Text(
                                        '1 / $pageCount',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 10,
                                          color: Colors.black45,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            // Footer strip on first page bottom
                            if (_footerText.isNotEmpty ||
                                (_showPageNumbers &&
                                    !_docSettings.pageNumberPos.startsWith('top')))
                              Positioned(
                                bottom: 8,
                                left: 16,
                                right: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _footerText,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    if (_showPageNumbers &&
                                        !_docSettings.pageNumberPos.startsWith('top'))
                                      Text(
                                        '1 / $pageCount',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 10,
                                          color: Colors.black45,
                                        ),
                                      ),
                                  ],
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
                _exportDocument();
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
        if (title == l10n.styles) {
          Navigator.pop(ctx);
          Future.microtask(() => _showStylesSheet());
          return const SizedBox.shrink();
        }
        if (title == l10n.textStyle) return _buildFontStyleSheet(ctx, theme);
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
                                  Navigator.pop(context);
                                  _applySizeToSelection(v);
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
                                          Navigator.pop(context);
                                          _applySizeToSelection(s.toDouble());
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
                            ListTile(
                              leading: const Icon(Icons.format_clear),
                              title: const Text('Clear format on selection'),
                              onTap: () {
                                Navigator.pop(context);
                                _clearSelectionFormat();
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
      {'icon': Icons.settings_outlined, 'label': 'Document settings', 'key': 'settings'},
      {'icon': Icons.format_indent_increase, 'label': 'Indent +', 'key': 'indentMore'},
      {'icon': Icons.format_indent_decrease, 'label': 'Indent −', 'key': 'indentLess'},
      {'icon': Icons.format_line_spacing, 'label': 'Line spacing', 'key': 'lineSpacing'},
      {'icon': Icons.pin_outlined, 'label': 'Page numbers', 'key': 'pageNumbers'},
      {'icon': Icons.search_rounded, 'label': 'Find & Replace', 'key': 'find'},
      {'icon': Icons.menu_book_outlined, 'label': 'Chapters', 'key': 'chapters'},
      {'icon': Icons.title_rounded, 'label': 'Heading 1', 'key': 'h1'},
      {'icon': Icons.title_rounded, 'label': 'Heading 2', 'key': 'h2'},
      {'icon': Icons.title_rounded, 'label': 'Heading 3', 'key': 'h3'},
      {'icon': Icons.format_quote_rounded, 'label': 'Quote', 'key': 'quote'},
      {'icon': Icons.format_list_bulleted, 'label': 'Bullet list', 'key': 'bullet'},
      {'icon': Icons.format_list_numbered, 'label': 'Numbered list', 'key': 'number'},
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
      {'icon': Icons.text_fields_rounded, 'label': 'UPPERCASE', 'key': 'upper'},
      {'icon': Icons.text_fields_rounded, 'label': 'lowercase', 'key': 'lower'},
      {'icon': Icons.text_fields_rounded, 'label': 'Title Case', 'key': 'title'},
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
                      _insertAtCursor(' • * + - = > < ( ) [ ]');
                      break;
                    case 'diagram':
                      _insertAtCursor(
                        '\n[DIAGRAM]\n  A ---> B\n  B ---> C\n[/DIAGRAM]\n',
                      );
                      break;
                    case 'pageBreak':
                      _insertAtCursor('\n\n--- Page Break ---\n\n');
                      break;
                    case 'hline':
                      _insertAtCursor('\n--------------------\n');
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
                    case 'settings':
                      _openDocumentSettings();
                      break;
                    case 'indentMore':
                      _indentParagraph(1);
                      break;
                    case 'indentLess':
                      _indentParagraph(-1);
                      break;
                    case 'lineSpacing':
                      _showLineSpacingPicker();
                      break;
                    case 'pageNumbers':
                      _showPageNumberOptions();
                      break;
                    case 'find':
                      _showFindReplace();
                      break;
                    case 'chapters':
                      _showChaptersPanel();
                      break;
                    case 'h1':
                      _applyStyle('h1');
                      break;
                    case 'h2':
                      _applyStyle('h2');
                      break;
                    case 'h3':
                      _applyStyle('h3');
                      break;
                    case 'quote':
                      _applyStyle('quote');
                      break;
                    case 'bullet':
                      _applyStyle('bullet');
                      break;
                    case 'number':
                      _applyStyle('number');
                      break;
                    case 'upper':
                      _transformCase('upper');
                      break;
                    case 'lower':
                      _transformCase('lower');
                      break;
                    case 'title':
                      _transformCase('title');
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
