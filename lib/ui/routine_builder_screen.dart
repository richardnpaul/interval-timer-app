import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/engine/tree_utils.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/widgets/audio_picker_tile.dart';
import 'package:interval_timer_app/ui/widgets/color_swatch_picker.dart';

/// Tree-based routine editor.
///
/// [existing] is the [GroupNode] to edit. Pass null to create a brand-new
/// routine.
class RoutineBuilderScreen extends ConsumerStatefulWidget {
  final GroupNode? existing;
  const RoutineBuilderScreen({super.key, this.existing});

  @override
  ConsumerState<RoutineBuilderScreen> createState() =>
      _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  late GroupNode _root;
  late final TextEditingController _nameCtr;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _root = widget.existing ?? GroupNode(name: '');
    _nameCtr = TextEditingController(text: _root.name);
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  String? _parentOf(String nodeId) {
    final hit = flattenTree(_root).cast<NodeEntry?>().firstWhere(
      (e) => e!.node.id == nodeId,
      orElse: () => null,
    );
    return hit?.parentId;
  }

  // ── Top-level actions ──────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtr.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine name first.')),
      );
      return;
    }
    await ref
        .read(routinesProvider.notifier)
        .saveRoutine(_root.copyWith(name: name));
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
    });
  }

  void _wrapSelected() {
    if (_selectedIds.isEmpty) return;
    final parents = _selectedIds.map(_parentOf).toSet();
    if (parents.length != 1 || parents.first == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All selected items must have the same parent to wrap.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _root = wrapInGroup(_root, parents.first!, _selectedIds.toList());
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  // ── Add sheets ─────────────────────────────────────────────────────────────

  void _showAddSheet(String parentId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Add to Group',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.library_books_outlined),
              title: const Text('From Library'),
              onTap: () {
                Navigator.pop(ctx);
                _showLibrarySheet(parentId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Quick Timer'),
              onTap: () {
                Navigator.pop(ctx);
                _showQuickTimerSheet(parentId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('New Sub-Group'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _root = addChildToNode(
                    _root,
                    parentId,
                    GroupNode(name: 'Group'),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLibrarySheet(String parentId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Consumer(
          builder: (ctx, ref, _) {
            final presets = ref.watch(presetsProvider);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Choose a Preset',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (presets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No presets yet. Create some in the Library tab first.',
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    children: presets.map((preset) {
                      final color = preset.color != null
                          ? colorFromHex(preset.color!)
                          : Colors.grey;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          child: Text(
                            preset.name.isEmpty
                                ? '?'
                                : preset.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(preset.name),
                        subtitle: Text(_fmt(preset.defaultDuration)),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _root = addChildToNode(
                              _root,
                              parentId,
                              TimerInstance.fromPreset(preset),
                            );
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showQuickTimerSheet(String parentId) {
    final nameCtrl = TextEditingController();
    final durCtrl = TextEditingController(text: '60');
    String? selectedColor = kColorPalette.first;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, set) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Timer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Duration (seconds)',
                    border: OutlineInputBorder(),
                    suffixText: 's',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                ColorSwatchPicker(
                  selected: selectedColor,
                  onChanged: (hex) => set(() => selectedColor = hex),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final dur = int.tryParse(durCtrl.text.trim()) ?? 60;
                      Navigator.pop(ctx);
                      setState(() {
                        _root = addChildToNode(
                          _root,
                          parentId,
                          TimerInstance(
                            name: name,
                            duration: dur,
                            color: selectedColor,
                          ),
                        );
                      });
                    },
                    child: const Text('Add Timer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit sheets ────────────────────────────────────────────────────────────

  void _showEditInstanceSheet(NodeEntry entry) {
    final inst = entry.node as TimerInstance;
    final nameCtrl = TextEditingController(text: inst.name);
    final durCtrl = TextEditingController(text: '${inst.duration}');
    String? color = inst.color ?? kColorPalette.first;
    bool autoRestart = inst.autoRestart;
    String? soundPath = inst.soundPath;
    int soundOffset = inst.soundOffset;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, set) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Timer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Duration (seconds)',
                    border: OutlineInputBorder(),
                    suffixText: 's',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                ColorSwatchPicker(
                  selected: color,
                  onChanged: (hex) => set(() => color = hex),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto Restart'),
                  subtitle: const Text('Loop this timer without stopping'),
                  value: autoRestart,
                  onChanged: (v) => set(() => autoRestart = v),
                ),
                const SizedBox(height: 8),
                AudioPickerTile(
                  initialPath: soundPath,
                  soundOffset: soundOffset,
                  onPathChanged: (newPath) => set(() => soundPath = newPath),
                  onOffsetChanged: (newOffset) =>
                      set(() => soundOffset = newOffset),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final updated = inst.copyWith(
                        name: nameCtrl.text.trim(),
                        duration:
                            int.tryParse(durCtrl.text.trim()) ?? inst.duration,
                        color: color,
                        autoRestart: autoRestart,
                        soundPath: soundPath,
                        soundOffset: soundOffset,
                      );
                      Navigator.pop(ctx);
                      setState(() => _root = updateNodeById(_root, updated));
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditGroupSheet(GroupNode group) {
    final nameCtrl = TextEditingController(text: group.name);
    ExecutionMode mode = group.executionMode;
    final repsCtrl = TextEditingController(text: '${group.repetitions}');
    final isRoot = group.id == _root.id;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, set) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRoot ? 'Routine Settings' : 'Edit Group',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                Text(
                  'Execution Mode',
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<ExecutionMode>(
                  segments: const [
                    ButtonSegment(
                      value: ExecutionMode.sequential,
                      label: Text('Sequential'),
                      icon: Icon(Icons.format_list_numbered),
                    ),
                    ButtonSegment(
                      value: ExecutionMode.parallel,
                      label: Text('Parallel'),
                      icon: Icon(Icons.grid_view),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => set(() => mode = s.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: repsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Repetitions  (0 = infinite)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final newName = nameCtrl.text.trim();
                      final reps =
                          int.tryParse(repsCtrl.text.trim()) ??
                          group.repetitions;
                      final updated = group.copyWith(
                        name: newName.isEmpty ? group.name : newName,
                        executionMode: mode,
                        repetitions: reps,
                      );
                      Navigator.pop(ctx);
                      if (isRoot) {
                        setState(() {
                          _root = updated;
                          _nameCtr.text = updated.name;
                        });
                      } else {
                        setState(() => _root = updateNodeById(_root, updated));
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tile builders ──────────────────────────────────────────────────────────

  Widget _buildTile(NodeEntry entry) {
    final node = entry.node;
    final indent = entry.depth * 24.0;
    final selected = _selectedIds.contains(node.id);

    if (node is TimerInstance) {
      return _instanceTile(entry, node, indent, selected);
    } else if (node is GroupNode) {
      return _groupTile(entry, node, indent, selected);
    }
    return const SizedBox.shrink();
  }

  Widget _instanceTile(
    NodeEntry entry,
    TimerInstance inst,
    double indent,
    bool selected,
  ) {
    final dot = inst.color != null
        ? colorFromHex(inst.color!)
        : Theme.of(context).colorScheme.primary;

    return Padding(
      key: ValueKey(inst.id),
      padding: EdgeInsets.only(left: indent),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        child: ListTile(
          onTap: _selectionMode ? () => _toggleSelect(inst.id) : null,
          leading: _selectionMode
              ? Checkbox(
                  value: selected,
                  onChanged: (_) => _toggleSelect(inst.id),
                )
              : CircleAvatar(
                  radius: 14,
                  backgroundColor: dot,
                  foregroundColor: Colors.white,
                  child: Text(
                    inst.name.isEmpty ? '?' : inst.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
          title: Text(inst.name),
          subtitle: Row(
            children: [
              Text(_fmt(inst.duration)),
              if (inst.autoRestart) ...[
                const SizedBox(width: 6),
                const Icon(Icons.repeat, size: 13),
              ],
              if (inst.presetId != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.link, size: 13),
              ],
            ],
          ),
          trailing: _selectionMode ? null : _actionRow(entry),
        ),
      ),
    );
  }

  Widget _groupTile(
    NodeEntry entry,
    GroupNode group,
    double indent,
    bool selected,
  ) {
    return Padding(
      key: ValueKey(group.id),
      padding: EdgeInsets.only(left: indent),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListTile(
          onTap: _selectionMode ? () => _toggleSelect(group.id) : null,
          leading: _selectionMode
              ? Checkbox(
                  value: selected,
                  onChanged: (_) => _toggleSelect(group.id),
                )
              : Icon(
                  group.executionMode == ExecutionMode.parallel
                      ? Icons.grid_view
                      : Icons.format_list_numbered,
                  color: Theme.of(context).colorScheme.primary,
                ),
          title: Text(group.name),
          subtitle: Text(
            '${group.executionMode.name}  •  '
            '${group.repetitions == 0 ? '∞' : '×${group.repetitions}'}  •  '
            '${group.children.length} items',
          ),
          trailing: _selectionMode
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      tooltip: 'Add child',
                      onPressed: () => _showAddSheet(group.id),
                    ),
                    ..._actionButtons(entry),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _actionRow(NodeEntry entry) =>
      Row(mainAxisSize: MainAxisSize.min, children: _actionButtons(entry));

  List<Widget> _actionButtons(NodeEntry entry) {
    final id = entry.node.id;
    return [
      IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        tooltip: 'Edit',
        onPressed: () => entry.node is TimerInstance
            ? _showEditInstanceSheet(entry)
            : _showEditGroupSheet(entry.node as GroupNode),
      ),
      IconButton(
        icon: const Icon(Icons.arrow_upward, size: 18),
        tooltip: 'Move up',
        onPressed: () => setState(() => _root = moveChildBy(_root, id, -1)),
      ),
      IconButton(
        icon: const Icon(Icons.arrow_downward, size: 18),
        tooltip: 'Move down',
        onPressed: () => setState(() => _root = moveChildBy(_root, id, 1)),
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        tooltip: 'Delete',
        onPressed: () => setState(() {
          _root = removeNodeById(_root, id);
          _selectedIds.remove(id);
        }),
      ),
    ];
  }

  // ── Root header ────────────────────────────────────────────────────────────

  Widget _rootHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: () => _showEditGroupSheet(_root),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                _root.executionMode == ExecutionMode.parallel
                    ? Icons.grid_view
                    : Icons.format_list_numbered,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Root: ${_root.executionMode.name}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Reps: ${_root.repetitions == 0 ? '∞' : _root.repetitions}   •   '
                      '${_root.children.length} top-level items',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.settings_outlined,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final entries = flattenTree(_root);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _nameCtr,
          decoration: const InputDecoration(
            hintText: 'Routine name…',
            border: InputBorder.none,
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          if (_selectionMode && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.wrap_text),
              tooltip: 'Wrap selected in group',
              onPressed: _wrapSelected,
            ),
          IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
            tooltip: _selectionMode ? 'Cancel selection' : 'Multi-select',
            onPressed: _toggleSelectionMode,
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Column(
        children: [
          _rootHeader(),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 64,
                          color: scheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No timers yet',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to add timers or groups',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.4),
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: entries.map(_buildTile).toList(),
                  ),
          ),
          if (_selectionMode && _selectedIds.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton.icon(
                  icon: const Icon(Icons.wrap_text),
                  label: Text('Wrap ${_selectedIds.length} selected in Group'),
                  onPressed: _wrapSelected,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(_root.id),
        tooltip: 'Add to routine',
        child: const Icon(Icons.add),
      ),
    );
  }
}
