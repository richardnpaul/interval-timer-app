import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/models/timer_group.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:uuid/uuid.dart';

class EditGroupScreen extends ConsumerStatefulWidget {
  final TimerGroup? group;

  const EditGroupScreen({super.key, this.group});

  @override
  ConsumerState<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends ConsumerState<EditGroupScreen> {
  final _controller = TextEditingController();
  final Set<String> _selectedTimerIds = {};
  GroupExecutionMode _executionMode = GroupExecutionMode.parallel;

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _controller.text = widget.group!.label;
      _selectedTimerIds.addAll(widget.group!.timerIds);
      _executionMode = widget.group!.executionMode;
    }
  }

  void _save() {
    if (_controller.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a label')));
      return;
    }

    if (_selectedTimerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one timer')),
      );
      return;
    }

    final newGroup = TimerGroup(
      id: widget.group?.id ?? Uuid().v4(),
      label: _controller.text,
      timerIds: _selectedTimerIds.toList(),
      executionMode: _executionMode,
    );

    ref.read(groupsProvider.notifier).saveGroup(newGroup);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(presetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group == null ? 'New Group' : 'Edit Group'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Group Label',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Execution Mode',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          RadioGroup<GroupExecutionMode>(
            groupValue: _executionMode,
            onChanged: (value) {
              if (value != null) setState(() => _executionMode = value);
            },
            child: Column(
              children: [
                RadioListTile<GroupExecutionMode>(
                  title: const Text('Parallel'),
                  subtitle: const Text('All timers start at once'),
                  value: GroupExecutionMode.parallel,
                ),
                RadioListTile<GroupExecutionMode>(
                  title: const Text('Sequential'),
                  subtitle: const Text('Timers run one after another'),
                  value: GroupExecutionMode.sequence,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select Timers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (presets.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Text('No saved presets found'),
              ),
            )
          else
            ...presets.map((preset) {
              final isSelected = _selectedTimerIds.contains(preset.id);
              return CheckboxListTile(
                key: Key('preset_${preset.id}'),
                title: Text(preset.label),
                subtitle: Text('${preset.durationSeconds}s'),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedTimerIds.add(preset.id);
                    } else {
                      _selectedTimerIds.remove(preset.id);
                    }
                  });
                },
              );
            }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
