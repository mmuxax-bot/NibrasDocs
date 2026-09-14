import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ImageInsertResult {
  final String path;
  final double widthFactor; // 0.25 - 1.0
  ImageInsertResult(this.path, this.widthFactor);
}

class ImageInsertDialog extends StatefulWidget {
  final String path;
  const ImageInsertDialog({super.key, required this.path});

  static Future<ImageInsertResult?> show(BuildContext context, String path) {
    return showModalBottomSheet<ImageInsertResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImageInsertDialog(path: path),
    );
  }

  @override
  State<ImageInsertDialog> createState() => _ImageInsertDialogState();
}

class _ImageInsertDialogState extends State<ImageInsertDialog> {
  double _width = 0.85;

  @override
  Widget build(BuildContext context) {
    final file = File(widget.path);
    return Container(
      height: MediaQuery.of(context).size.height * 0\$2\$5.75,
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
                  'Insert image',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: file.existsSync()
                  ? Image.file(
                      file,
                      width: MediaQuery.of(context).size.width * _width,
                      fit: BoxFit.contain,
                    )
                  : const Text('File not found',
                      style: TextStyle(color: Colors.white54)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Size',
                    style: GoogleFonts.dmSans(color: Colors.white70)),
                Expanded(
                  child: Slider(
                    value: _width,
                    min: 0.3,
                    max: 1.0,
                    divisions: 7,
                    label: '${(_width * 100).round()}%',
                    onChanged: (v) => setState(() => _width = v),
                  ),
                ),
                Text('${(_width * 100).round()}%',
                    style: GoogleFonts.dmSans(color: Colors.white)),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    ImageInsertResult(widget.path, _width),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text('Insert image',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5CE6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
