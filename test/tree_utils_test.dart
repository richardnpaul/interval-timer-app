import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/engine/tree_utils.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';

// ---------------------------------------------------------------------------
// Fixture
// ---------------------------------------------------------------------------
//
//  root (seq)
//  ├── inst-a  (2s)
//  ├── group-b (seq)
//  │   ├── inst-c  (3s)
//  │   └── inst-d  (1s)
//  └── inst-e  (4s)
//

GroupNode _makeTree() => GroupNode(
  id: 'root',
  name: 'Root',
  children: [
    TimerInstance(id: 'inst-a', name: 'A', duration: 2),
    GroupNode(
      id: 'group-b',
      name: 'B',
      children: [
        TimerInstance(id: 'inst-c', name: 'C', duration: 3),
        TimerInstance(id: 'inst-d', name: 'D', duration: 1),
      ],
    ),
    TimerInstance(id: 'inst-e', name: 'E', duration: 4),
  ],
);

void main() {
  // =========================================================================
  group('flattenTree', () {
    test('returns entries in DFS pre-order with correct depths', () {
      final entries = flattenTree(_makeTree());
      // Expected order: A(0), B(0), C(1), D(1), E(0)
      expect(entries.length, 5);
      expect(entries[0].node.id, 'inst-a');
      expect(entries[0].depth, 0);
      expect(entries[1].node.id, 'group-b');
      expect(entries[1].depth, 0);
      expect(entries[2].node.id, 'inst-c');
      expect(entries[2].depth, 1);
      expect(entries[3].node.id, 'inst-d');
      expect(entries[3].depth, 1);
      expect(entries[4].node.id, 'inst-e');
      expect(entries[4].depth, 0);
    });

    test('returns empty list for root with no children', () {
      final root = GroupNode(id: 'empty', name: 'Empty');
      expect(flattenTree(root), isEmpty);
    });

    test('parentId links each entry correctly', () {
      final entries = flattenTree(_makeTree());
      expect(entries[0].parentId, 'root'); // A → root
      expect(entries[1].parentId, 'root'); // B → root
      expect(entries[2].parentId, 'group-b'); // C → B
      expect(entries[3].parentId, 'group-b'); // D → B
      expect(entries[4].parentId, 'root'); // E → root
    });
  });

  // =========================================================================
  group('addChildToNode', () {
    test('adds child to root', () {
      final root = _makeTree();
      final newChild = TimerInstance(id: 'new', name: 'New', duration: 5);
      final result = addChildToNode(root, 'root', newChild);
      expect(result.children.last.id, 'new');
      expect(result.children.length, 4);
    });

    test('adds child to nested group', () {
      final root = _makeTree();
      final newChild = TimerInstance(id: 'new', name: 'New', duration: 5);
      final result = addChildToNode(root, 'group-b', newChild);
      final groupB = result.children[1] as GroupNode;
      expect(groupB.children.last.id, 'new');
      expect(groupB.children.length, 3);
    });

    test('root is unchanged for the unmodified branch', () {
      final root = _makeTree();
      final newChild = TimerInstance(id: 'new', name: 'New', duration: 5);
      final result = addChildToNode(root, 'group-b', newChild);
      // inst-a and inst-e are unchanged
      expect(result.children[0].id, 'inst-a');
      expect(result.children[2].id, 'inst-e');
    });

    test('throws when parentId is not found', () {
      final root = _makeTree();
      expect(
        () => addChildToNode(
          root,
          'nonexistent',
          TimerInstance(name: 'X', duration: 1),
        ),
        throwsArgumentError,
      );
    });
  });

  // =========================================================================
  group('removeNodeById', () {
    test('removes a root-level leaf node', () {
      final result = removeNodeById(_makeTree(), 'inst-a');
      expect(result.children.length, 2);
      expect(result.children.any((c) => c.id == 'inst-a'), isFalse);
    });

    test('removes a root-level group and its descendants', () {
      final result = removeNodeById(_makeTree(), 'group-b');
      expect(result.children.length, 2);
      expect(result.children.any((c) => c.id == 'group-b'), isFalse);
    });

    test('removes a deeply nested leaf node', () {
      final result = removeNodeById(_makeTree(), 'inst-c');
      final groupB = result.children[1] as GroupNode;
      expect(groupB.children.length, 1);
      expect(groupB.children[0].id, 'inst-d');
    });

    test('throws when nodeId is not found', () {
      expect(() => removeNodeById(_makeTree(), 'ghost'), throwsArgumentError);
    });

    test('throws when trying to remove the root itself', () {
      expect(() => removeNodeById(_makeTree(), 'root'), throwsArgumentError);
    });
  });

  // =========================================================================
  group('updateNodeById', () {
    test('updates a root-level leaf', () {
      final updated = TimerInstance(
        id: 'inst-a',
        name: 'A-updated',
        duration: 99,
      );
      final result = updateNodeById(_makeTree(), updated);
      expect(result.children[0].id, 'inst-a');
      expect((result.children[0] as TimerInstance).duration, 99);
      expect((result.children[0] as TimerInstance).name, 'A-updated');
    });

    test('updates a deeply nested node', () {
      final updated = TimerInstance(
        id: 'inst-c',
        name: 'C-updated',
        duration: 77,
      );
      final result = updateNodeById(_makeTree(), updated);
      final groupB = result.children[1] as GroupNode;
      expect((groupB.children[0] as TimerInstance).duration, 77);
    });

    test('updates a nested GroupNode itself', () {
      final updatedGroup = GroupNode(
        id: 'group-b',
        name: 'B-renamed',
        executionMode: ExecutionMode.parallel,
        repetitions: 3,
        children: [
          TimerInstance(id: 'inst-c', name: 'C', duration: 3),
          TimerInstance(id: 'inst-d', name: 'D', duration: 1),
        ],
      );
      final result = updateNodeById(_makeTree(), updatedGroup);
      final groupB = result.children[1] as GroupNode;
      expect(groupB.name, 'B-renamed');
      expect(groupB.executionMode, ExecutionMode.parallel);
      expect(groupB.repetitions, 3);
    });

    test('throws when nodeId is not found', () {
      final updated = TimerInstance(id: 'ghost', name: 'Ghost', duration: 1);
      expect(() => updateNodeById(_makeTree(), updated), throwsArgumentError);
    });
  });

  // =========================================================================
  group('moveChildBy', () {
    test('moves a root-level child down by 1', () {
      final result = moveChildBy(_makeTree(), 'inst-a', 1);
      // inst-a was at 0, now at 1
      expect(result.children[1].id, 'inst-a');
      expect(result.children[0].id, 'group-b');
    });

    test('moves a root-level child up by 1', () {
      final result = moveChildBy(_makeTree(), 'inst-e', -1);
      // inst-e was at 2, now at 1
      expect(result.children[1].id, 'inst-e');
      expect(result.children[2].id, 'group-b');
    });

    test('moves a nested child down', () {
      final result = moveChildBy(_makeTree(), 'inst-c', 1);
      final groupB = result.children[1] as GroupNode;
      expect(groupB.children[0].id, 'inst-d');
      expect(groupB.children[1].id, 'inst-c');
    });

    test('clamps at upper bound (no error, no change)', () {
      final result = moveChildBy(_makeTree(), 'inst-e', 5);
      // inst-e is already last
      expect(result.children[2].id, 'inst-e');
    });

    test('clamps at lower bound (no error, no change)', () {
      final result = moveChildBy(_makeTree(), 'inst-a', -5);
      // inst-a is already first
      expect(result.children[0].id, 'inst-a');
    });

    test('throws when nodeId is not found', () {
      expect(() => moveChildBy(_makeTree(), 'ghost', 1), throwsArgumentError);
    });
  });

  // =========================================================================
  group('wrapInGroup', () {
    test('wraps two siblings into a new sub-group', () {
      final result = wrapInGroup(_makeTree(), 'root', ['inst-a', 'group-b']);
      // root now has 2 children: the new wrapper group + inst-e
      expect(result.children.length, 2);
      expect(result.children[0], isA<GroupNode>());
      expect(result.children[1].id, 'inst-e');
    });

    test('new group contains the wrapped children in original order', () {
      final result = wrapInGroup(_makeTree(), 'root', ['inst-a', 'group-b']);
      final wrapper = result.children[0] as GroupNode;
      expect(wrapper.children.length, 2);
      expect(wrapper.children[0].id, 'inst-a');
      expect(wrapper.children[1].id, 'group-b');
    });

    test('new group is inserted at position of first selected child', () {
      // Wrapping group-b and inst-e (positions 1 and 2)
      final result = wrapInGroup(_makeTree(), 'root', ['group-b', 'inst-e']);
      expect(result.children.length, 2);
      expect(result.children[0].id, 'inst-a');
      expect(result.children[1], isA<GroupNode>());
      final wrapper = result.children[1] as GroupNode;
      expect(wrapper.children[0].id, 'group-b');
      expect(wrapper.children[1].id, 'inst-e');
    });

    test('unwrapped siblings remain in parent', () {
      final result = wrapInGroup(_makeTree(), 'root', ['inst-a']);
      // Wrapping a single item: root → [wrapper[A], B, E]
      expect(result.children.length, 3);
      expect(result.children[1].id, 'group-b');
      expect(result.children[2].id, 'inst-e');
    });

    test('supports a custom name for the new group', () {
      final result = wrapInGroup(_makeTree(), 'root', [
        'inst-a',
      ], newGroupName: 'My Wrapper');
      final wrapper = result.children[0] as GroupNode;
      expect(wrapper.name, 'My Wrapper');
    });

    test('wraps children inside a nested group', () {
      final result = wrapInGroup(_makeTree(), 'group-b', ['inst-c', 'inst-d']);
      final groupB = result.children[1] as GroupNode;
      expect(groupB.children.length, 1);
      final inner = groupB.children[0] as GroupNode;
      expect(inner.children[0].id, 'inst-c');
      expect(inner.children[1].id, 'inst-d');
    });

    test('throws when parentId not found', () {
      expect(
        () => wrapInGroup(_makeTree(), 'ghost', ['inst-a']),
        throwsArgumentError,
      );
    });

    test('throws when childIds list is empty', () {
      expect(() => wrapInGroup(_makeTree(), 'root', []), throwsArgumentError);
    });
  });
}
