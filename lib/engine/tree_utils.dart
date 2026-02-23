import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_node.dart';

/// One row in the flattened tree as rendered in a ListView.
class NodeEntry {
  final TimerNode node;

  /// Nesting depth — 0 means direct child of the root GroupNode.
  final int depth;

  /// ID of the [GroupNode] that directly contains this node.
  final String parentId;

  const NodeEntry({
    required this.node,
    required this.depth,
    required this.parentId,
  });
}

// ---------------------------------------------------------------------------
// flattenTree
// ---------------------------------------------------------------------------

/// Flattens [root]'s descendants into a DFS pre-order list with depth metadata.
/// The root itself is NOT included — only its descendants.
List<NodeEntry> flattenTree(GroupNode root) {
  final entries = <NodeEntry>[];
  _walkGroup(root, 0, entries);
  return entries;
}

void _walkGroup(GroupNode group, int depth, List<NodeEntry> out) {
  for (final child in group.children) {
    out.add(NodeEntry(node: child, depth: depth, parentId: group.id));
    if (child is GroupNode) {
      _walkGroup(child, depth + 1, out);
    }
  }
}

// ---------------------------------------------------------------------------
// addChildToNode
// ---------------------------------------------------------------------------

/// Returns a new root with [child] appended to the group identified by [parentId].
/// Throws [ArgumentError] if [parentId] is not found anywhere in the tree.
GroupNode addChildToNode(GroupNode root, String parentId, TimerNode child) {
  final (result, found) = _addInGroup(root, parentId, child);
  if (!found) throw ArgumentError('Parent node "$parentId" not found in tree');
  return result;
}

(GroupNode, bool) _addInGroup(
  GroupNode group,
  String parentId,
  TimerNode child,
) {
  if (group.id == parentId) {
    return (group.addChild(child), true);
  }
  bool found = false;
  final newChildren = <TimerNode>[];
  for (final c in group.children) {
    if (c is GroupNode && !found) {
      final (newChild, childFound) = _addInGroup(c, parentId, child);
      newChildren.add(newChild);
      if (childFound) found = true;
    } else {
      newChildren.add(c);
    }
  }
  return (group.copyWith(children: newChildren), found);
}

// ---------------------------------------------------------------------------
// removeNodeById
// ---------------------------------------------------------------------------

/// Returns a new root with the node identified by [nodeId] removed.
/// Throws [ArgumentError] if [nodeId] equals the root id or is not found.
GroupNode removeNodeById(GroupNode root, String nodeId) {
  if (root.id == nodeId) throw ArgumentError('Cannot remove the root node');
  final (result, found) = _removeFromGroup(root, nodeId);
  if (!found) throw ArgumentError('Node "$nodeId" not found in tree');
  return result;
}

(GroupNode, bool) _removeFromGroup(GroupNode group, String nodeId) {
  bool found = false;
  final newChildren = <TimerNode>[];
  for (final child in group.children) {
    if (child.id == nodeId) {
      found = true; // skip → removes it
    } else if (child is GroupNode) {
      final (newChild, childFound) = _removeFromGroup(child, nodeId);
      newChildren.add(newChild);
      if (childFound) found = true;
    } else {
      newChildren.add(child);
    }
  }
  return (group.copyWith(children: newChildren), found);
}

// ---------------------------------------------------------------------------
// updateNodeById
// ---------------------------------------------------------------------------

/// Returns a new root with the node whose id matches [updated.id] replaced.
/// Throws [ArgumentError] if the matching node is not found.
GroupNode updateNodeById(GroupNode root, TimerNode updated) {
  final (result, found) = _updateInGroup(root, updated);
  if (!found) throw ArgumentError('Node "${updated.id}" not found in tree');
  return result;
}

(GroupNode, bool) _updateInGroup(GroupNode group, TimerNode updated) {
  bool found = false;
  final newChildren = <TimerNode>[];
  for (final child in group.children) {
    if (child.id == updated.id) {
      newChildren.add(updated);
      found = true;
    } else if (child is GroupNode) {
      final (newChild, childFound) = _updateInGroup(child, updated);
      newChildren.add(newChild);
      if (childFound) found = true;
    } else {
      newChildren.add(child);
    }
  }
  return (group.copyWith(children: newChildren), found);
}

// ---------------------------------------------------------------------------
// moveChildBy
// ---------------------------------------------------------------------------

/// Moves the child identified by [nodeId] within its parent by [delta] positions.
/// Clamps at list bounds without throwing. Throws [ArgumentError] if not found.
GroupNode moveChildBy(GroupNode root, String nodeId, int delta) {
  final (result, found) = _moveInTree(root, nodeId, delta);
  if (!found) throw ArgumentError('Node "$nodeId" not found in tree');
  return result;
}

(GroupNode, bool) _moveInTree(GroupNode group, String nodeId, int delta) {
  final idx = group.children.indexWhere((c) => c.id == nodeId);
  if (idx != -1) {
    final newIdx = (idx + delta).clamp(0, group.children.length - 1);
    if (newIdx == idx) return (group, true); // no-op, but found
    final list = List<TimerNode>.of(group.children);
    final item = list.removeAt(idx);
    list.insert(newIdx, item);
    return (group.copyWith(children: list), true);
  }
  bool found = false;
  final newChildren = <TimerNode>[];
  for (final child in group.children) {
    if (child is GroupNode && !found) {
      final (newChild, childFound) = _moveInTree(child, nodeId, delta);
      newChildren.add(newChild);
      if (childFound) found = true;
    } else {
      newChildren.add(child);
    }
  }
  return (group.copyWith(children: newChildren), found);
}

// ---------------------------------------------------------------------------
// wrapInGroup
// ---------------------------------------------------------------------------

/// Wraps the children listed in [childIds] (all direct children of [parentId])
/// in a new [GroupNode] inserted at the first selected child's position.
/// Throws [ArgumentError] if [parentId] is not found or [childIds] is empty.
GroupNode wrapInGroup(
  GroupNode root,
  String parentId,
  List<String> childIds, {
  String? newGroupName,
}) {
  if (childIds.isEmpty) throw ArgumentError('childIds must not be empty');
  final (result, found) = _wrapInTree(
    root,
    parentId,
    childIds,
    newGroupName ?? 'Group',
  );
  if (!found) throw ArgumentError('Parent "$parentId" not found in tree');
  return result;
}

(GroupNode, bool) _wrapInTree(
  GroupNode group,
  String parentId,
  List<String> childIds,
  String newGroupName,
) {
  if (group.id == parentId) {
    // Collect children to wrap (preserving their original order).
    final toWrap = group.children
        .where((c) => childIds.contains(c.id))
        .toList();
    final wrapper = GroupNode(name: newGroupName, children: toWrap);

    // Build new children: replace first occurrence of any selected child with
    // the wrapper; skip subsequent selected children.
    final newChildren = <TimerNode>[];
    bool inserted = false;
    for (final child in group.children) {
      if (childIds.contains(child.id)) {
        if (!inserted) {
          newChildren.add(wrapper);
          inserted = true;
        }
        // else: skip — it is now inside the wrapper
      } else {
        newChildren.add(child);
      }
    }
    return (group.copyWith(children: newChildren), true);
  }

  // Recurse into sub-groups.
  bool found = false;
  final newChildren = <TimerNode>[];
  for (final child in group.children) {
    if (child is GroupNode && !found) {
      final (newChild, childFound) = _wrapInTree(
        child,
        parentId,
        childIds,
        newGroupName,
      );
      newChildren.add(newChild);
      if (childFound) found = true;
    } else {
      newChildren.add(child);
    }
  }
  return (group.copyWith(children: newChildren), found);
}
