import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Interactive table builder: change rows/cols, edit cells, insert markdown table.
class TableEditorDialog extends StatefulWidget {
  final int initialRows;
  final int initialCols;
  final List<List<String>>? initialData;

  const TableEditorDialog({
    super.key,
    this.initialRows = 3,
    this.initialCols = 3,
    this.initialData,
  });

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TableEditorDialog(),
    );
  }

  @override
  State<TableEditorDialog> createState() => _TableEditorDialogState();
}

class _TableEditorDialogState extends State<TableEditorDialog> {
  late int _rows;
  late int _cols;
  late List<List<TextEditingController>> _cells;
  int _selectedRow = 0;
  int _selectedCol = 0;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialRows.clamp(1, 12);
    _cols = widget.initialCols.clamp(1, 8);
    _initCells(widget.initialData);
  }

  void _initCells(List<List<String>>? data) {
    _cells = List.generate(_rows, (r) {
      return List.generate(_cols, (c) {
        final text = (data != null &&
                r < data.length &&
                c < data[r].length)
            ? data[r][c]
            : (r == 0 ? 'Header ${c + 1}' : '');
        return TextEditingController(text: text);
      });
    });
  }

  void _resize(int newRows, int newCols) {
    newRows = newRows.clamp(1, 12);
    newCols = newCols.clamp(1, 8);
    final old = _cells
        .map((row) => row.map((c) => c.text).toList())
        .toList();
    for (final row in _cells) {
      for (final c in row) {
        c.dispose();
      }
    }
    _rows = newRows;
    _cols = newCols;
    _initCells(old);
    _selectedRow = _selectedRow.clamp(0, _rows - 1);
    _selectedCol = _selectedCol.clamp(0, _cols - 1);
    setState(() {});
  }

  void _addRow() => _resize(_rows + 1, _cols);
  void _removeRow() {
    if (_rows <= 1) return;
    _resize(_rows - 1, _cols);
  }

  void _addCol() => _resize(_rows, _cols + 1);
  void _removeCol() {
    if (_cols <= 1) return;
    _resize(_rows, _cols - 1);
  }

  String _toMarkdown() {
    final buf = StringBuffer();
    buf.writeln();
    // header
    buf.write('|');
    for (var c = 0; c < _cols; c++) {
      buf.write(' ${_cells[0][c].text.trim().isEmpty ? ' ' : _cells[0][c].text.trim()} |');
    }
    buf.writeln();
    buf.write('|');
    for (var c = 0; c < _cols; c++) {
      buf.write(' --- |');
    }
    buf.writeln();
    for (var r = 1; r < _rows; r++) {
      buf.write('|');
      for (var c = 0; c < _cols; c++) {
        final t = _cells[r][c].text.trim();
        buf.write(' ${t.isEmpty ? ' ' : t} |');
      }
      buf.writeln();
    }
    buf.writeln();
    return buf.toString();
  }

  @override
  void dispose() {
    for (final row in _cells) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Table editor',
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
            // Size controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chip(Icons.add, 'Row', _addRow),
                  _chip(Icons.remove, 'Row', _removeRow),
                  _chip(Icons.add, 'Col', _addCol),
                  _chip(Icons.remove, 'Col', _removeCol),
                  Text(
                    '$_rows × $_cols',
                    style: GoogleFonts.dmSans(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Table(
                    border: TableBorder.all(color: Colors.white24),
                    defaultColumnWidth: const FixedColumnWidth(120),
                    children: List.generate(_rows, (r) {
                      return TableRow(
                        children: List.generate(_cols, (c) {
                          final selected =
                              r == _selectedRow && c == _selectedCol;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedRow = r;
                              _selectedCol = c;
                            }),
                            child: Container(
                              color: selected
                                  ? const Color(0xFF2B5CE6).withOpacity(0.25)
                                  : (r == 0
                                      ? Colors.white10
                                      : Colors.transparent),
                              padding: const EdgeInsets.all(4),
                              child: TextField(
                                controller: _cells[r][c],
                                maxLines: 3,
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: r == 0
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: r == 0 ? 'Header' : 'Cell',
                                  hintStyle: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () => setState(() {
                                  _selectedRow = r;
                                  _selectedCol = c;
                                }),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, _toMarkdown()),
                    icon: const Icon(Icons.check),
                    label: Text(
                      'Insert table',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                    ),
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
      ),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      onPressed: onTap,
      backgroundColor: const Color(0xFF2A2A2A),
      side: BorderSide.none,
    );
  }
}
