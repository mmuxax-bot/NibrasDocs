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
  static String _stripFormatTags(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'\[color=#[0-9A-Fa-f]{6}\]'), '');
    s = s.replaceAll('[/color]', '');
    s = s.replaceAll(RegExp(r'\[bg=#[0-9A-Fa-f]{6}\]'), '');
    s = s.replaceAll('[/bg]', '');
    return s;
  }

  static Future<void> exportPdf({
    required String title,
    required String content,
    required PageSize pageSize,
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
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            safeTitle,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
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
    await _shareBytes(bytes, '$safeTitle.pdf', 'application/pdf');
  }

  static Future<void> exportDocx({
    required String title,
    required String content,
  }) async {
    if (kIsWeb) return;

    final safeTitle = title.trim().isEmpty ? 'Untitled_Document' : title.trim();
    final bytes = _buildDocx(title: safeTitle, content: content);
    await _shareBytes(
      bytes,
      '${safeTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')}.docx',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }


  static Future<void> exportTxt({
    required String title,
    required String content,
  }) async {
    if (kIsWeb) return;
    final safeTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final bytes = Uint8List.fromList(utf8.encode(content));
    await _shareBytes(bytes, '$safeTitle.txt', 'text/plain');
  }


  static Future<void> exportEpub({
    required String title,
    required String content,
  }) async {
    if (kIsWeb) return;
    final safeTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final bytes = _buildEpub(title: safeTitle, content: content);
    final name = safeTitle
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    await _shareBytes(bytes, '$name.epub', 'application/epub+zip');
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

  static Future<void> _shareBytes(
    Uint8List bytes,
    String filename,
    String mime,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mime, name: filename)],
      subject: filename,
    );
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
