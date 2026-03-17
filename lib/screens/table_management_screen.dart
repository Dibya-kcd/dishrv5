import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/app_ui_kit.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
class _C {
  static const bg2    = Color(0xFF18181B);
  static const bg3    = Color(0xFF27272A);
  static const border = Color(0xFF2E2E32);
  static const amber  = Color(0xFFF59E0B);
  static const red    = Color(0xFFEF4444);
  static const textPr = Color(0xFFFAFAFA);
  static const textSc = Color(0xFF71717A);
  static const textDm = Color(0xFF52525B);
}

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});
  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  String? _editingId;
  final _numC  = TextEditingController();
  final _capC  = TextEditingController();
  bool  _showAdd = false;
  final _addNumC = TextEditingController();
  final _addCapC = TextEditingController(text: '4');

  @override
  void dispose() {
    _numC.dispose(); _capC.dispose();
    _addNumC.dispose(); _addCapC.dispose();
    super.dispose();
  }

  void _startEdit(dynamic t) => setState(() {
    _editingId = t.id as String;
    _numC.text = '${t.number}';
    _capC.text = '${t.capacity}';
  });

  void _cancelEdit() => setState(() => _editingId = null);

  void _saveEdit(BuildContext ctx, dynamic t) {
    final n = int.tryParse(_numC.text.trim());
    final c = int.tryParse(_capC.text.trim());
    if (n != null && c != null && c > 0) {
      ctx.read<RestaurantProvider>().editTable(t.id, n, c);
    }
    setState(() => _editingId = null);
  }

  Future<void> _confirmDelete(BuildContext ctx, dynamic t) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _C.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Table ${t.number}?',
            style: const TextStyle(color: _C.textPr, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('Table ${t.number} will be permanently removed.',
            style: const TextStyle(color: _C.textSc, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _C.textSc))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _C.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && ctx.mounted) ctx.read<RestaurantProvider>().deleteTable(t.id);
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: _C.textDm, fontSize: 13),
    filled: true, fillColor: _C.bg3,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.amber, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final tables   = [...provider.tables]..sort((a, b) => a.number.compareTo(b.number));

    return AppPageScaffold(
      title: 'Table Setup',
      scrollable: false,
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(20)),
          child: Text('${tables.length} tables', style: const TextStyle(color: _C.textSc, fontSize: 12)),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => setState(() {
            _showAdd = !_showAdd;
            if (!_showAdd) { _addNumC.clear(); _addCapC.text = '4'; }
            if (_showAdd) _editingId = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _showAdd ? _C.bg3 : _C.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_showAdd ? Icons.close : Icons.add,
                  color: _showAdd ? _C.textSc : Colors.black, size: 16),
              const SizedBox(width: 4),
              Text(_showAdd ? 'Close' : 'Add Table',
                  style: TextStyle(color: _showAdd ? _C.textSc : Colors.black, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Add form ────────────────────────────────────────────────────
          if (_showAdd)
            _AddForm(
              numC: _addNumC,
              capC: _addCapC,
              dec: _dec,
              onSave: () {
                final n = int.tryParse(_addNumC.text.trim());
                final c = int.tryParse(_addCapC.text.trim());
                if (n != null && c != null && c > 0) {
                  context.read<RestaurantProvider>().addTable(n, c);
                  setState(() { _showAdd = false; _addNumC.clear(); _addCapC.text = '4'; });
                }
              },
            ),

          // ── Column headers ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(children: [
              const SizedBox(width: 44),
              const Expanded(child: Text('TABLE', style: TextStyle(color: _C.textDm, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))),
              const SizedBox(width: 100, child: Text('SEATS', style: TextStyle(color: _C.textDm, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))),
              const SizedBox(width: 80),
            ]),
          ),
          const Divider(height: 1, color: _C.border, indent: 16, endIndent: 16),

          // ── Rows ─────────────────────────────────────────────────────────
          Expanded(
            child: tables.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.table_restaurant_outlined, color: _C.textDm, size: 44),
                      const SizedBox(height: 12),
                      const Text('No tables yet', style: TextStyle(color: _C.textSc, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Tap + Add Table to configure your floor', style: TextStyle(color: _C.textDm, fontSize: 13)),
                    ]),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 60),
                    itemCount: tables.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: _C.border, indent: 16, endIndent: 16),
                    itemBuilder: (ctx, i) {
                      final t = tables[i];
                      return _editingId == t.id.toString()
                          ? _EditRow(table: t, numC: _numC, capC: _capC, dec: _dec,
                              onSave: () => _saveEdit(ctx, t), onCancel: _cancelEdit)
                          : _ViewRow(table: t,
                              onEdit: () => _startEdit(t),
                              onDelete: () => _confirmDelete(ctx, t));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Add Form ──────────────────────────────────────────────────────────────────
class _AddForm extends StatelessWidget {
  final TextEditingController numC;
  final TextEditingController capC;
  final InputDecoration Function(String) dec;
  final VoidCallback onSave;
  const _AddForm({required this.numC, required this.capC, required this.dec, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.amber.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('New Table', style: TextStyle(color: _C.textPr, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Number', style: TextStyle(color: _C.textSc, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 5),
            TextField(
              controller: numC, autofocus: true, keyboardType: TextInputType.number,
              style: const TextStyle(color: _C.textPr, fontSize: 14, fontWeight: FontWeight.w700),
              decoration: dec('e.g. 10'),
            ),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Seats', style: TextStyle(color: _C.textSc, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 5),
            _CapacityStepper(controller: capC),
          ])),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.amber, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
      ]),
    );
  }
}

// ── View Row (read-only) ──────────────────────────────────────────────────────
class _ViewRow extends StatelessWidget {
  final dynamic table;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ViewRow({required this.table, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      splashColor: _C.amber.withValues(alpha: 0.06),
      highlightColor: _C.amber.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          // Avatar
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text('T${table.number}',
                style: const TextStyle(color: _C.textPr, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text('Table ${table.number}',
                style: const TextStyle(color: _C.textPr, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          // Seats
          SizedBox(
            width: 100,
            child: Row(children: [
              const Icon(Icons.people_outline, size: 14, color: _C.textSc),
              const SizedBox(width: 5),
              Text('${table.capacity}',
                  style: const TextStyle(color: _C.textSc, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              const Text('seats', style: TextStyle(color: _C.textDm, fontSize: 12)),
            ]),
          ),
          // Buttons
          SizedBox(
            width: 80,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _btn(Icons.edit_outlined, _C.textSc, onEdit),
              const SizedBox(width: 2),
              _btn(Icons.delete_outline, _C.red.withValues(alpha: 0.65), onDelete),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _btn(IconData icon, Color color, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.all(7), child: Icon(icon, size: 18, color: color)),
    );
  }
}

// ── Edit Row (inline editing) ─────────────────────────────────────────────────
class _EditRow extends StatelessWidget {
  final dynamic table;
  final TextEditingController numC;
  final TextEditingController capC;
  final InputDecoration Function(String) dec;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  const _EditRow({required this.table, required this.numC, required this.capC, required this.dec, required this.onSave, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.amber.withValues(alpha: 0.04),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _C.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.amber.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: Text('T${table.number}',
              style: const TextStyle(color: _C.amber, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: numC, autofocus: true, keyboardType: TextInputType.number,
            style: const TextStyle(color: _C.textPr, fontSize: 14, fontWeight: FontWeight.w700),
            decoration: dec('Table #'),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 130, child: _CapacityStepper(controller: capC)),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSave,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: _C.amber, borderRadius: BorderRadius.circular(8)),
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onCancel,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.close, size: 16, color: _C.textSc),
          ),
        ),
      ]),
    );
  }
}

// ── Capacity Stepper ──────────────────────────────────────────────────────────
class _CapacityStepper extends StatefulWidget {
  final TextEditingController controller;
  const _CapacityStepper({required this.controller});
  @override
  State<_CapacityStepper> createState() => _CapacityStepperState();
}

class _CapacityStepperState extends State<_CapacityStepper> {
  int get _val => int.tryParse(widget.controller.text) ?? 4;

  void _step(int d) {
    final next = (_val + d).clamp(1, 50);
    setState(() => widget.controller.text = '$next');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        _stepBtn(Icons.remove, () => _step(-1)),
        Expanded(
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.textPr, fontSize: 14, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        _stepBtn(Icons.add, () => _step(1)),
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 40,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: _C.textSc),
      ),
    );
  }
}
