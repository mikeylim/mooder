// history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../insights/insights_screen.dart';
import '../utils/app_copy.dart';
import '../utils/mood_emoji.dart';
import '../utils/state_tag_formatter.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Set<String> _selectedIds = {};
  bool get _selectionMode => _selectedIds.isNotEmpty;

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate().toLocal();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$mi';
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<bool> _confirmDeleteSelected(BuildContext context, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count check-in${count == 1 ? '' : 's'}?'),
        content: const Text('This can’t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _confirmDeleteOne(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this check-in?'),
        content: const Text('This can’t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteSelected(String uid) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    final ok = await _confirmDeleteSelected(context, ids.length);
    if (!ok) return;

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('checkins');

    // Firestore batch limit is 500 ops. Chunk if needed.
    const chunkSize = 400;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.skip(i).take(chunkSize);
      final batch = FirebaseFirestore.instance.batch();
      for (final id in chunk) {
        batch.delete(col.doc(id));
      }
      await batch.commit();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${ids.length} check-in(s).')),
    );
    _clearSelection();
  }

  Future<bool> _confirmDeleteAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all history?'),
        content: const Text('This deletes all check-ins permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteAllForUser(String uid) async {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('checkins');

    while (true) {
      final snap = await col.limit(200).get();
      if (snap.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(body: Center(child: Text(AppCopy.errGeneric)));
    }

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('checkins')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedIds.length} selected'
              : AppCopy.historyTitle,
        ),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel selection',
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete selected',
              onPressed: () => _deleteSelected(uid),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.insights),
              tooltip: AppCopy.insightsTitle,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                );
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) async {
                if (value == 'delete_all') {
                  final ok = await _confirmDeleteAll(context);
                  if (!ok) return;
                  await _deleteAllForUser(uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History deleted.')),
                    );
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete_all',
                  child: Text('Delete all history'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(AppCopy.errGeneric));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(AppCopy.noHistory, textAlign: TextAlign.center),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final moodRaw = (data['moodPrimary'] ?? 'unknown').toString();
              final moodTitle = moodRaw.isEmpty
                  ? AppCopy.unknown
                  : _titleCase(moodRaw);
              final emoji = emojiForMood(moodRaw);

              final tag = (data['stateTag'] ?? '').toString();
              final timestamp = data['createdAt'] as Timestamp?;

              final isSelected = _selectedIds.contains(doc.id);

              final tile = ListTile(
                leading: _selectionMode
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelected(doc.id),
                      )
                    : Text(emoji, style: const TextStyle(fontSize: 20)),
                title: Text(moodTitle),
                subtitle: Text(tag.isEmpty ? '' : formatStateTag(tag)),
                trailing: Text(
                  _formatDate(timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                selected: isSelected,
                onTap: () {
                  if (_selectionMode) {
                    _toggleSelected(doc.id);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HistoryDetailScreen(checkinId: doc.id),
                    ),
                  );
                },
                onLongPress: () {
                  // Start multi-select
                  _toggleSelected(doc.id);
                },
              );

              if (_selectionMode) return tile;

              return Slidable(
                key: ValueKey(doc.id),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) async {
                        final ok = await _confirmDeleteOne(context);
                        if (!ok) return;
                        await doc.reference.delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Deleted.')),
                          );
                        }
                      },
                      icon: Icons.delete,
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      label: 'Delete',
                    ),
                  ],
                ),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                HistoryDetailScreen(checkinId: doc.id),
                          ),
                        );
                      },
                      icon: Icons.edit,
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      label: 'Edit',
                    ),
                  ],
                ),
                child: tile,
              );
            },
          );
        },
      ),
    );
  }
}
