import 'package:flutter/foundation.dart';
import '../core/page_size.dart';
import 'mobile_export_service.dart';

class PdfService {
  static Future<void> generateAndDownload({
    required String title,
    required String content,
    required PageSize pageSize,
    required String textAlign,
    required bool isBold,
    required bool isItalic,
    required bool isUnderline,
  }) async {
    if (kIsWeb) return;
    await MobileExportService.exportPdf(
      title: title,
      content: content,
      pageSize: pageSize,
    );
  }
}
