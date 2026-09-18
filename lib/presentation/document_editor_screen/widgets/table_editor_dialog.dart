import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Parses [TABLE]...[/TABLE] blocks from document text.
class TableBlock {
  final int start;
  final int end;
  final List<List<String>> cells;
  final List<double> colWidths; // relative 0.5–2.0

  TableBlock({
    required this.start,
    required this.end,
    required this.cells,
    required this.colWidths,
  });

  static final RegExp blockRe = RegExp(
    r'\[TABLE\]([\s\S]*?)\[/TABLE\]',
    multiLine: true,
  );

  static TableBlock? findAt(String text, int cursor) {
    for (final m in blockRe.allMatches(text)) {
      if (cursor >= m.start && cursor <= m.end) {
        return _fromMatch(m);
      }
    }
    return null;
  }

  static List<TableBlock> allIn(String text) {
    return blockRe.allMatches(text).map(_fromMatch).toList();
  }

  static TableBlock _fromMatch(RegExpMatch m) {
    final body = m.group(1) ?? '';
    final lines = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('|') && !l.contains('---'))
        .toList();
    final cells = <List<String>>[];
    for (final line in lines) {
      var parts = line.split('|');
      // remove empty edges from leading/trailing |
      if (parts.isNotEmpty && parts.first.trim().isEmpty) {
        parts = parts.sublist(1);
      }
      if (parts.isNotEmpty && parts.last.trim().isEmpty) {
        parts = parts.sublist(0, parts.length - 1);
      }
      cells.add(parts.map((p) => p.trim()).toList());
    }
    if (cells.isEmpty) {
      cells.add(['', '', '']);
      cells.add(['', '', '']);
    }
    final cols = cells.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);
    for (final r in cells) {
      while (r.length < cols) {
        r.add('');
      }
    }
    final widths = List<double>.filled(cols, 1.0);
    // optional width line: [W] 1.0 1.2 0.8
    final wLine = RegExp(r'\[W\]\s*([0-9. ]+)').firstMatch(body);
    if (wLine != null) {
      final nums = wLine.group(1)!.trim().split(RegExp(r'\s+'));
      for (var i = 0; i < cols && i < nums.length; i++) {
        widths[i] = double.tryParse(nums[i]) ?? 1.0;
      }
    }
    return TableBlock(
      start: m.start,
      end: m.end,
      cells: cells,
      colWidths: widths,
    );
  }

  String toMarkup() {
    final buf = StringBuffer();
    buf.writeln('[TABLE]');
    if (colWidths.any((w) => (w - 1.0).abs() > 0.01)) {
      buf.writeln('[W] ${colWidths.map((w) => w.toStringAsFixed(2)).join(' ')}');
    }
    for (var r = 0; r < cells.length; r++) {
      buf.writeln('| ${cells[r].map((c) => c.replaceAll('|', '/')).join(' | ')} |');
      if (r == 0) {
        buf.writeln('| ${List.filled(cells[0].length, '---').join(' | ')} |');
      }
    }
    buf.writeln('[/TABLE]');
    return buf.toString();
  }
}

class TableEditorDialog extends StatefulWidget {
  final int initialRows;
  final int initialCols;
  final List<List<String>>? initialData;
  final List<double>? initialWidths;
  final bool editing;

  const TableEditorDialog({
    super.key,
    this.initialRows = 3,
    this.initialCols = 3,
    this.initialData,
    this.initialWidths,
    this.editing = false,
  });

  static Future<String?> show(
    BuildContext context, {
    List<List<String>>? data,
    List<double>? widths,
    bool editing = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TableEditorDialog(
        initialRows: data?.length ?? 3,
        initialCols: data?.isNotEmpty == true ? data!.first.length : 3,
        initialData: data,
        initialWidths: widths,
        editing: editing,
      ),
    );
  }

  @override
  State<TableEditorDialog> createState() => _TableEditorDialogState();
}

class _TableEditorDialogState extends State<TableEditorDialog> {
  late int _rows;
  late int _cols;
  late List<List<TextEditingController>> _cells;
  late List<double> _widths;
  int _selectedRow = 0;
  int _selectedCol = 0;

  @override
  void initState() {
    super.initState();
    _rows = (widget.initialData?.length ?? widget.initialRows).clamp(1, 20);
    _cols = (widget.initialData?.isNotEmpty == true
            ? widget.initialData!.first.length
            : widget.initialCols)
        .clamp(1, 10);
    _widths = List<double>.generate(
      _cols,
      (i) => (widget.initialWidths != null && i < widget.initialWidths!.length)
          ? widget.initialWidths![i].clamp(0.5, 2.5)
          : 1.0,
    );
    _initCells(widget.initialData);
  }

  void _initCells(List<List<String>>? data) {
    _cells = List.generate(_rows, (r) {
      return List.generate(_cols, (c) {
        final text = (data != null && r < data.length && c < data[r].length)
            ? data[r][c]
            : (r == 0 ? 'Header ${c + 1}' : '');
        return TextEditingController(text: text);
      });
    });
  }

  void _disposeCells() {
    for (final row in _cells) {
      for (final c in row) {
        c.dispose();
      }
    }
  }

  List<List<String>> _snapshot() =>
      _cells.map((row) => row.map((c) => c.text).toList()).toList();

  void _resize(int newRows, int newCols) {
    newRows = newRows.clamp(1, 20);
    newCols = newCols.clamp(1, 10);
    final old = _snapshot();
    _disposeCells();
    final oldW = List<double>.from(_widths);
    _rows = newRows;
    _cols = newCols;
    _widths = List.generate(
      _cols,
      (i) => i < oldW.length ? oldW[i] : 1.0,
    );
    _initCells(old);
    _selectedRow = _selectedRow.clamp(0, _rows - 1);
    _selectedCol = _selectedCol.clamp(0, _cols - 1);
    setState(() {});
  }

  void _insertRow(int at) {
    final data = _snapshot();
    data.insert(at.clamp(0, data.length), List.filled(_cols, ''));
    _disposeCells();
    _rows = data.length;
    _initCells(data);
    setState(() => _selectedRow = at.clamp(0, _rows - 1));
  }

  void _deleteRow(int at) {
    if (_rows <= 1) return;
    final data = _snapshot();
    data.removeAt(at.clamp(0, data.length - 1));
    _disposeCells();
    _rows = data.length;
    _initCells(data);
    setState(() => _selectedRow = _selectedRow.clamp(0, _rows - 1));
  }

  void _insertCol(int at) {
    final data = _snapshot();
    for (final row in data) {
      row.insert(at.clamp(0, row.length), '');
    }
    _widths.insert(at.clamp(0, _widths.length), 1.0);
    _disposeCells();
    _cols = data.first.length;
    _initCells(data);
    setState(() => _selectedCol = at.clamp(0, _cols - 1));
  }

  void _deleteCol(int at) {
    if (_cols <= 1) return;
    final data = _snapshot();
    for (final row in data) {
      if (row.isNotEmpty) row.removeAt(at.clamp(0, row.length - 1));
    }
    if (_widths.isNotEmpty) {
      _widths.removeAt(at.clamp(0, _widths.length - 1));
    }
    _disposeCells();
    _cols = data.first.length;
    _initCells(data);
    setState(() => _selectedCol = _selectedCol.clamp(0, _cols - 1));
  }

  void _clearSelected() {
    _cells[_selectedRow][_selectedCol].text = '';
    setState(() {});
  }

  String _toMarkup() {
    final block = TableBlock(
      start: 0,
      end: 0,
      cells: _snapshot(),
      colWidths: List<double>.from(_widths),
    );
    return '\n${block.toMarkup()}\n';
  }

  @override
  void dispose() {
    _disposeCells();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.92;
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
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(
                  widget.editing ? 'Edit table' : 'Insert table',
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
          // Structure toolbar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _chip(Icons.add, 'Row+', () => _insertRow(_selectedRow + 1)),
                _chip(Icons.remove, 'Row−', () => _deleteRow(_selectedRow)),
                _chip(Icons.view_column, 'Col+', () => _insertCol(_selectedCol + 1)),
                _chip(Icons.view_column_outlined, 'Col−', () => _deleteCol(_selectedCol)),
                _chip(Icons.clear, 'Clear cell', _clearSelected),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Cell R${_selectedRow + 1} C${_selectedCol + 1} · Tap cell to edit · Slider = column width',
              style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white54),
            ),
          ),
          // Column width for selected col
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Col width',
                  style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _widths[_selectedCol.clamp(0, _widths.length - 1)],
                    min: 0.5,
                    max: 2.5,
                    divisions: 20,
                    label: _widths[_selectedCol.clamp(0, _widths.length - 1)]
                        .toStringAsFixed(1),
                    onChanged: (v) {
                      setState(() {
                        _widths[_selectedCol.clamp(0, _widths.length - 1)] = v;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: Colors.white24, width: 1),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: {
                    for (var c = 0; c < _cols; c++)
                      c: FixedColumnWidth(100.0 * _widths[c]),
                  },
                  children: List.generate(_rows, (r) {
                    return TableRow(
                      decoration: BoxDecoration(
                        color: r == 0
                            ? const Color(0xFF1A2A4A)
                            : (r == _selectedRow
                                ? const Color(0xFF1E1E28)
                                : const Color(0xFF181818)),
                      ),
                      children: List.generate(_cols, (c) {
                        final selected =
                            r == _selectedRow && c == _selectedCol;
                        return Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.all(4),
                          decoration: selected
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF2B5CE6),
                                    width: 2,
                                  ),
                                )
                              : null,
                          child: TextField(
                            controller: _cells[r][c],
                            maxLines: 4,
                            minLines: 1,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight:
                                  r == 0 ? FontWeight.w700 : FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: r == 0 ? 'Header' : 'Type…',
                              hintStyle: const TextStyle(
                                color: Colors.white30,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => setState(() {
                              _selectedRow = r;
                              _selectedCol = c;
                            }),
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
                  onPressed: () => Navigator.pop(context, _toMarkup()),
                  icon: const Icon(Icons.check),
                  label: Text(
                    widget.editing ? 'Update table' : 'Insert table',
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
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        onPressed: onTap,
        backgroundColor: const Color(0xFF2A2A2A),
        side: BorderSide.none,
      ),
    );
  }
}
