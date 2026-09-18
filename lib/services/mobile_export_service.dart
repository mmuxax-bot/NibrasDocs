import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/page_size.dart';

/// Cross-platform export: saves PDF/DOCX and opens the system share sheet.
class MobileExportService {
  /// Clean editor markers for export (markdown + internal tags).
  static String _stripFormatTags(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'\[color=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/color]', '');
    s = s.replaceAll(RegExp(r'\[bg=#[0-9A-Fa-f]{6,8}\]'), '');
    s = s.replaceAll('[/bg]', '');
    s = s.replaceAll(RegExp(r'\\[size=\\d+\\]'), '');
    s = s.replaceAll('[/size]', '');
    s = s.replaceAll(RegExp(r'\\[align=(left|center|right|justify)\\]'), '');
    s = s.replaceAll(RegExp(r'\[img path="[^"]*" w=[0-9.]+\]'), '[Image]');
    s = s.replaceAll('[TABLE]', '');
    s = s.replaceAll('[/TABLE]', '');
    s = s.replaceAll('[DIAGRAM]', '');
    s = s.replaceAll('[/DIAGRAM]', '');
    s = s.replaceAll('--- Page Break ---', '\n');
    // Keep table pipes as readable lines; strip emphasis markers lightly
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m.group(1) ?? '');
    // italic single * careful - only paired
    s = s.replaceAllMapped(RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'), (m) => m.group(1) ?? '');
    return s;
  }

  static String _safeFileName(String title, String ext) {
    var base = title.trim().isEmpty ? 'Nibras_Document' : title.trim();
    base = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    base = base.replaceAll(RegExp(r'\s+'), '_');
    if (base.length > 60) base = base.substring(0, 60);
    return '$base.$ext';
  }


  static Future<void> exportPdf({
    required String title,
    required String content,
    required PageSize pageSize,
    bool showPageNumbers = true,
    String pageNumberPos = 'bottom-center',
    String headerText = '',
    String footerText = '',
  }) async {
    if (kIsWeb) return;

    final doc = pw.Document();
    final pageFormat = switch (pageSize) {
      PageSize.a3 => PdfPageFormat.a3,
      PageSize.a5 => PdfPageFormat.a5,
      PageSize.letter => PdfPageFormat.letter,
      PageSize.legal => PdfPageFormat.legal,
      _ => PdfPageFormat.a4,
    };

    final safeTitle = title.trim().isEmpty ? 'Untitled Document' : title.trim();
    final clean = _stripFormatTags(content);
    final paragraphs = clean.split('\n');

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(40),
        header: (context) {
          final h = headerText.trim().isNotEmpty ? headerText.trim() : safeTitle;
          final showNumTop = showPageNumbers && pageNumberPos.startsWith('top');
          pw.Alignment align = pw.Alignment.centerRight;
          if (pageNumberPos.endsWith('left')) align = pw.Alignment.centerLeft;
          if (pageNumberPos.endsWith('center')) align = pw.Alignment.center;
          return pw.Container(
            alignment: align,
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    h,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ),
                if (showNumTop)
                  pw.Text(
                    '${context.pageNumber} / ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
              ],
            ),
          );
        },
        footer: (context) {
          final showNumBottom = showPageNumbers && !pageNumberPos.startsWith('top');
          pw.Alignment align = pw.Alignment.center;
          if (pageNumberPos.endsWith('left')) align = pw.Alignment.centerLeft;
          if (pageNumberPos.endsWith('right')) align = pw.Alignment.centerRight;
          final f = footerText.trim();
          return pw.Container(
            alignment: align,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  f,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                if (showNumBottom)
                  pw.Text(
                    '${context.pageNumber} / ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
              ],
            ),
          );
        },
        build: (context) => [
          pw.Text(
            safeTitle,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          ...paragraphs.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                line.isEmpty ? ' ' : line,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.4),
                textDirection: _detectRtl(line)
                    ? pw.TextDirection.rtl
                    : pw.TextDirection.ltr,
              ),
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await _shareBytes(bytes, _safeFileName(safeTitle, 'pdf'), 'application/pdf');
  }

  static Future<void> exportDocx({
    required String title,
    required String content,
  }) async {
    if (kIsWeb) return;

    final safeTitle = title.trim().isEmpty ? 'Untitled_Document' : title.trim();
    final bytes = _buildDocx(title: safeTitle, content: _stripFormatTags(content));
    await _shareBytes(
      bytes,
      _safeFileName(safeTitle, 'docx'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }


  static Future<void> exportTxt({
    required String title,
    required String content,
  }) async {
    if (kIsWeb) return;
    final safeTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final bytes = Uint8List.fromList(utf8.encode(_stripFormatTags(content)));
    await _shareBytes(bytes, _safeFileName(safeTitle, 'txt'), 'text/plain');
  }


  static Future<void> exportEpub({
    required String title,
    required String content,
  }) async {
    if (kIsWeb) return;
    final safeTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final bytes = _buildEpub(title: safeTitle, content: _stripFormatTags(content));
    final name = safeTitle
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    await _shareBytes(bytes, _safeFileName(safeTitle, 'epub'), 'application/epub+zip');
  }

  static Uint8List _buildEpub({
    required String title,
    required String content,
  }) {
    final body = content.split('\n').map((l) {
      if (l.trim().isEmpty) return '<p><br/></p>';
      return '<p>${_xmlEscape(l)}</p>';
    }).join('\n');

    final mimetype = 'application/epub+zip';
    final container =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>';

    final id = 'nibras-${DateTime.now().millisecondsSinceEpoch}';
    final opf =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:title>${_xmlEscape(title)}</dc:title>'
        '<dc:language>en</dc:language>'
        '<dc:identifier id="BookId">$id</dc:identifier>'
        '</metadata>'
        '<manifest>'
        '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'
        '<item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>'
        '</manifest>'
        '<spine toc="ncx"><itemref idref="chapter1"/></spine>'
        '</package>';

    final ncx =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">'
        '<head><meta name="dtb:uid" content="$id"/></head>'
        '<docTitle><text>${_xmlEscape(title)}</text></docTitle>'
        '<navMap><navPoint id="nav1" playOrder="1">'
        '<navLabel><text>${_xmlEscape(title)}</text></navLabel>'
        '<content src="chapter1.xhtml"/></navPoint></navMap></ncx>';

    final xhtml =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml">'
        '<head><title>${_xmlEscape(title)}</title></head><body>'
        '<h1>${_xmlEscape(title)}</h1>$body</body></html>';

    final archive = Archive();
    void addFile(String name, String data, {bool store = false}) {
      final encoded = utf8.encode(data);
      final f = ArchiveFile(name, encoded.length, encoded);
      archive.addFile(f);
    }

    addFile('mimetype', mimetype, store: true);
    addFile('META-INF/container.xml', container);
    addFile('OEBPS/content.opf', opf);
    addFile('OEBPS/toc.ncx', ncx);
    addFile('OEBPS/chapter1.xhtml', xhtml);

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static bool _detectRtl(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(text);
  }

  static Future<String> _shareBytes(
    Uint8List bytes,
    String filename,
    String mime,
  ) async {
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    // Durable copy under app documents
    try {
      final docs = await getApplicationDocumentsDirectory();
      final durable = File('${docs.path}/exports/$filename');
      await durable.parent.create(recursive: true);
      await durable.writeAsBytes(bytes, flush: true);
    } catch (_) {}
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mime, name: filename)],
      subject: filename,
      text: 'Exported from Nibras Docs',
    );
    return file.path;
  }


  /// Minimal valid DOCX (Office Open XML)
  static Uint8List _buildDocx({
    required String title,
    required String content,
  }) {
    final paragraphs = content.split('\n');
    final bodyXml = StringBuffer();
    bodyXml.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    );
    bodyXml.writeln(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    );
    bodyXml.writeln('<w:body>');
    // Title
    bodyXml.writeln(
      '<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr>'
      '<w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr>'
      '<w:t>${_xmlEscape(title)}</w:t></w:r></w:p>',
    );
    for (final line in paragraphs) {
      final rtl = _detectRtl(line);
      final bidi = rtl ? '<w:bidi w:val="1"/>' : '';
      bodyXml.writeln(
        '<w:p><w:pPr>$bidi</w:pPr><w:r><w:t>${_xmlEscape(line)}</w:t></w:r></w:p>',
      );
    }
    bodyXml.writeln('<w:sectPr/></w:body></w:document>');

    final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    final rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final archive = Archive();
    void add(String name, String data) {
      final encoded = utf8.encode(data);
      archive.addFile(ArchiveFile(name, encoded.length, encoded));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', bodyXml.toString());

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
