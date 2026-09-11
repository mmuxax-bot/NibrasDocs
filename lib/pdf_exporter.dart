import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfExporter {
  static bool _isRtl(String text) => RegExp(r'[\u0590-\u08FF]').hasMatch(text);

  static Future<pw.Font> _font(String family) async {
    final file = switch (family) {
      'Serif' => 'DejaVuSerif.ttf',
      'Mono' => 'DejaVuSansMono.ttf',
      _ => 'DejaVuSans.ttf',
    };
    return pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));
  }

  static Future<File> create({
    required String title,
    required String content,
    required String category,
    required String tags,
    required String family,
    required String pageSize,
    required bool landscape,
  }) async {
    final normal = await _font(family);
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    final rtl = _isRtl('$title$content');
    final baseFormat = switch(pageSize){'A3'=>PdfPageFormat.a3,'A5'=>PdfPageFormat.a5,'A6'=>PdfPageFormat.a6,'Letter'=>PdfPageFormat.letter,'Legal'=>PdfPageFormat.legal,_=>PdfPageFormat.a4};
    final selectedFormat = landscape ? baseFormat.landscape : baseFormat.portrait;
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: normal, bold: bold),
      title: title,
      author: 'Nibras Code',
    );
    pdf.addPage(pw.MultiPage(
      pageFormat: selectedFormat,
      margin: const pw.EdgeInsets.all(42),
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey300))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Nibras Docs', style: pw.TextStyle(font: bold, color: PdfColors.blue700)),
          pw.Text(category),
        ]),
      ),
      footer: (c) => pw.Align(alignment: pw.Alignment.center, child: pw.Text('${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
      build: (_) => [
        pw.SizedBox(height: 20),
        pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 24, color: PdfColors.blue900), textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr),
        if (tags.trim().isNotEmpty) ...[pw.SizedBox(height: 6), pw.Text(tags, style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600))],
        pw.SizedBox(height: 20),
        pw.Text(content.isEmpty ? ' ' : content, style: const pw.TextStyle(fontSize: 12, lineSpacing: 4), textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr),
      ],
    ));
    final dir = await getApplicationDocumentsDirectory();
    final exports = Directory('${dir.path}/NibrasDocs/Exports/PDF');
    if (!await exports.exists()) await exports.create(recursive: true);
    final safe = title.replaceAll(RegExp(r'[^\p{L}\p{N}_-]', unicode: true), '_');
    final file = File('${exports.path}/${safe.isEmpty ? 'document' : safe}.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }
}
