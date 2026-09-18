import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/page_size.dart';

class DocumentSettings {
  String language;
  PageSize pageSize;
  bool landscape;
  double marginMm; // 10 narrow, 20 normal, 30 wide
  String fontFamily;
  double fontSize;
  double lineHeight;
  bool showPageNumbers;
  String pageNumberPos; // top|bottom + left|center|right
  String headerText;
  String footerText;
  bool autoSave;

  DocumentSettings({
    this.language = 'en',
    this.pageSize = PageSize.a4,
    this.landscape = false,
    this.marginMm = 20,
    this.fontFamily = 'Roboto',
    this.fontSize = 16,
    this.lineHeight = 1.7,
    this.showPageNumbers = true,
    this.pageNumberPos = 'bottom-center',
    this.headerText = '',
    this.footerText = '',
    this.autoSave = true,
  });
}

Future<DocumentSettings?> showDocumentSettingsSheet(
  BuildContext context,
  DocumentSettings initial,
) {
  return showModalBottomSheet<DocumentSettings>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DocSettingsBody(initial: initial),
  );
}

class _DocSettingsBody extends StatefulWidget {
  final DocumentSettings initial;
  const _DocSettingsBody({required this.initial});
  @override
  State<_DocSettingsBody> createState() => _DocSettingsBodyState();
}

class _DocSettingsBodyState extends State<_DocSettingsBody> {
  late DocumentSettings s;
  late TextEditingController _header;
  late TextEditingController _footer;

  @override
  void initState() {
    super.initState();
    s = DocumentSettings(
      language: widget.initial.language,
      pageSize: widget.initial.pageSize,
      landscape: widget.initial.landscape,
      marginMm: widget.initial.marginMm,
      fontFamily: widget.initial.fontFamily,
      fontSize: widget.initial.fontSize,
      lineHeight: widget.initial.lineHeight,
      showPageNumbers: widget.initial.showPageNumbers,
      pageNumberPos: widget.initial.pageNumberPos,
      headerText: widget.initial.headerText,
      footerText: widget.initial.footerText,
      autoSave: widget.initial.autoSave,
    );
    _header = TextEditingController(text: s.headerText);
    _footer = TextEditingController(text: s.footerText);
  }

  @override
  void dispose() {
    _header.dispose();
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.88;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Document settings',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    s.headerText = _header.text;
                    s.footerText = _footer.text;
                    Navigator.pop(context, s);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                _label('Language'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in [
                      ('en', 'English'),
                      ('az', 'Azərbaycan'),
                      ('ru', 'Русский'),
                      ('ar', 'العربية'),
                    ])
                      ChoiceChip(
                        label: Text(e.$2),
                        selected: s.language == e.$1,
                        onSelected: (_) => setState(() => s.language = e.$1),
                      ),
                  ],
                ),
                _label('Page size'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in PageSize.values)
                      ChoiceChip(
                        label: Text(p.label),
                        selected: s.pageSize == p,
                        onSelected: (_) => setState(() => s.pageSize = p),
                      ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Landscape', style: TextStyle(color: Colors.white)),
                  value: s.landscape,
                  onChanged: (v) => setState(() => s.landscape = v),
                ),
                _label('Margins'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in [
                      (10.0, 'Narrow'),
                      (20.0, 'Normal'),
                      (30.0, 'Wide'),
                    ])
                      ChoiceChip(
                        label: Text(m.$2),
                        selected: s.marginMm == m.$1,
                        onSelected: (_) => setState(() => s.marginMm = m.$1),
                      ),
                  ],
                ),
                _label('Font'),
                DropdownButton<String>(
                  value: s.fontFamily,
                  dropdownColor: const Color(0xFF1E1E1E),
                  isExpanded: true,
                  items: [
                    for (final f in [
                      'Roboto',
                      'Times New Roman',
                      'Arial',
                      'Georgia',
                      'Lora',
                      'Montserrat',
                    ])
                      DropdownMenuItem(
                        value: f,
                        child: Text(f, style: const TextStyle(color: Colors.white)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => s.fontFamily = v);
                  },
                ),
                _label('Font size: ${s.fontSize.round()}'),
                Slider(
                  value: s.fontSize,
                  min: 10,
                  max: 36,
                  divisions: 26,
                  onChanged: (v) => setState(() => s.fontSize = v),
                ),
                _label('Line spacing: ${s.lineHeight.toStringAsFixed(1)}'),
                Slider(
                  value: s.lineHeight,
                  min: 1.0,
                  max: 2.5,
                  divisions: 15,
                  onChanged: (v) => setState(() => s.lineHeight = v),
                ),
                SwitchListTile(
                  title: const Text('Page numbers', style: TextStyle(color: Colors.white)),
                  value: s.showPageNumbers,
                  onChanged: (v) => setState(() => s.showPageNumbers = v),
                ),
                if (s.showPageNumbers) ...[
                  _label('Page number position'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in [
                        'bottom-center',
                        'bottom-left',
                        'bottom-right',
                        'top-center',
                      ])
                        ChoiceChip(
                          label: Text(p),
                          selected: s.pageNumberPos == p,
                          onSelected: (_) =>
                              setState(() => s.pageNumberPos = p),
                        ),
                    ],
                  ),
                ],
                _label('Header'),
                TextField(
                  controller: _header,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Book title / chapter',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                _label('Footer'),
                TextField(
                  controller: _footer,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Author / custom text',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Auto-save', style: TextStyle(color: Colors.white)),
                  value: s.autoSave,
                  onChanged: (v) => setState(() => s.autoSave = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          t,
          style: GoogleFonts.dmSans(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
