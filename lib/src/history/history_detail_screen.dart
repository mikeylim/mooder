// history_detail_screen.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/app_copy.dart';
import '../utils/state_tag_formatter.dart';
import '../utils/mood_emoji.dart';
import '../suggestions/suggestions_from_history_screen.dart';
import '../../config/backend_config.dart';

class HistoryDetailScreen extends StatefulWidget {
  final String checkinId;

  const HistoryDetailScreen({super.key, required this.checkinId});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  final Map<String, bool> _expanded = {};
  final Map<String, bool> _loading = {};
  String? _error;

  DocumentReference<Map<String, dynamic>> _checkinRef() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('checkins')
        .doc(widget.checkinId);
  }

  String _formatSavedAt(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate().toLocal();
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$mm/$dd $hh:$mi';
    }
    return '—';
  }

  String _formatCreatedAt(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate().toLocal();
      final yy = dt.year.toString();
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$yy/$mm/$dd  $hh:$mi';
    }
    return '—';
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _labelForCategory(String c) {
    final s = c.replaceAll('_', ' ').trim();
    if (s.isEmpty) return c;
    return s[0].toUpperCase() + s.substring(1);
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'quick_actions':
        return Icons.flash_on;
      case 'activities':
        return Icons.directions_run;
      case 'meditation':
        return Icons.self_improvement;
      case 'food':
        return Icons.restaurant;
      case 'books':
        return Icons.menu_book;
      default:
        return Icons.lightbulb_outline;
    }
  }

  Future<void> _confirmRegenerate({
    required String category,
    required Map<String, dynamic> checkinData,
  }) async {
    final label = _labelForCategory(category);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate suggestions?'),
        content: Text('This will replace your saved suggestions for “$label”.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _regenerate(category: category, checkinData: checkinData);
    }
  }

  Future<void> _regenerate({
    required String category,
    required Map<String, dynamic> checkinData,
  }) async {
    setState(() {
      _error = null;
      _loading[category] = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final token = await user.getIdToken();

      final stateTag = (checkinData['stateTag'] ?? '').toString();
      final primaryMood = (checkinData['moodPrimary'] ?? '').toString();
      final intensity = (checkinData['intensity'] ?? 0) as int;
      final energy = (checkinData['energy'] ?? 0) as int;
      final tension = (checkinData['tension'] ?? 0) as int;
      final drivers = (checkinData['drivers'] as List?) ?? const [];
      final selfHarmThoughts = checkinData['selfHarmThoughts'] == true;

      final url = suggestionsUri();
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'category': category,
          'stateTag': stateTag,
          'primaryMood': primaryMood,
          'intensity': intensity,
          'energy': energy,
          'tension': tension,
          'drivers': drivers,
          'selfHarmThoughts': selfHarmThoughts,
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Server ${resp.statusCode}');
      }

      final result = jsonDecode(resp.body) as Map<String, dynamic>;

      await _checkinRef().set({
        'suggestions': {
          category: {
            ...result,
            'provider': (result['provider'] ?? 'gemini').toString(),
            'savedAt': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));

      setState(() {
        _expanded[category] = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Couldn’t regenerate that right now. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading[category] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(body: Center(child: Text(AppCopy.errGeneric)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppCopy.historyDetailsTitle)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _checkinRef().snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(AppCopy.errGeneric));
          }

          final data = snap.data?.data();
          if (data == null) {
            return const Center(
              child: Text('This check-in couldn’t be found.'),
            );
          }

          final moodRaw = (data['moodPrimary'] ?? 'unknown').toString();
          final mood = _titleCase(moodRaw);
          final emoji = emojiForMood(moodRaw);

          final rawTag = (data['stateTag'] ?? '').toString();
          final tagHuman = rawTag.isEmpty ? '' : formatStateTag(rawTag);

          final createdAt = _formatCreatedAt(data['createdAt']);

          final driversList = (data['drivers'] as List?) ?? const [];
          final drivers = driversList.map((e) => e.toString()).toList();

          final selfHarm = data['selfHarmThoughts'] == true;

          final suggestions = (data['suggestions'] as Map?) ?? {};
          final savedCategories = suggestions.keys
              .map((k) => k.toString())
              .toList();

          const allCategories = [
            'quick_actions',
            'activities',
            'meditation',
            'food',
            'books',
          ];

          final missingCategories = allCategories
              .where((c) => !savedCategories.contains(c))
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$emoji  $mood',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),

                if (tagHuman.isNotEmpty)
                  Text(tagHuman)
                else
                  Text(
                    'State: —',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),

                const SizedBox(height: 6),
                Text(
                  'Checked-in: $createdAt',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                const SizedBox(height: 12),

                Text(
                  drivers.isEmpty
                      ? 'Drivers: ${AppCopy.driversNone}'
                      : 'Drivers: ${drivers.join(", ")}',
                ),

                if (selfHarm) ...[
                  const SizedBox(height: 12),
                  Text(
                    AppCopy.safetyEnabled,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 16),

                Text(
                  savedCategories.isEmpty
                      ? '${AppCopy.savedSuggestions}: ${AppCopy.driversNone}'
                      : '${AppCopy.savedSuggestions}: ${savedCategories.map(_labelForCategory).join(", ")}',
                ),

                const SizedBox(height: 12),

                // ✅ Offer categories that haven't been generated/saved yet
                if (missingCategories.isNotEmpty) ...[
                  Text(
                    'More ideas',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: missingCategories.map((c) {
                      return _IdeasBtn(
                        label: _labelForCategory(c),
                        category: c,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'These will generate and save suggestions for this check-in.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text(
                    'All categories have saved ideas for this check-in.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],

                const Divider(height: 28),

                if (savedCategories.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'No saved ideas yet. Pick a category to generate suggestions.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],

                ...savedCategories.map((cat) {
                  final block = suggestions[cat] as Map?;
                  final title = (block?['title'] ?? _labelForCategory(cat))
                      .toString();
                  final items = (block?['items'] as List?) ?? const [];
                  final savedAt = _formatSavedAt(block?['savedAt']);

                  final isExpanded = _expanded[cat] ?? false;
                  final isLoading = _loading[cat] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(_iconForCategory(cat)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _labelForCategory(cat),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saved: $savedAt',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(
                                      () => _expanded[cat] = !isExpanded,
                                    );
                                  },
                                  child: Text(isExpanded ? 'Hide' : 'View'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => _confirmRegenerate(
                                          category: cat,
                                          checkinData: data,
                                        ),
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Regenerate'),
                                ),
                              ),
                            ],
                          ),

                          if (isExpanded) ...[
                            const SizedBox(height: 10),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            if (items.isEmpty)
                              const Text('(no items)')
                            else
                              ...items.take(10).map((it) {
                                final m = Map<String, dynamic>.from(it as Map);
                                final text = (m['text'] ?? '').toString();
                                final time = (m['time'] ?? '').toString();
                                final effort = (m['effort'] ?? '').toString();

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('• '),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(text),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$time • $effort',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IdeasBtn extends StatelessWidget {
  final String label;
  final String category;

  const _IdeasBtn({required this.label, required this.category});

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'quick_actions':
        return Icons.flash_on;
      case 'activities':
        return Icons.directions_run;
      case 'meditation':
        return Icons.self_improvement;
      case 'food':
        return Icons.restaurant;
      case 'books':
        return Icons.menu_book;
      default:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    // We need the checkinId from the page route; easiest is: read it from Navigator stack by pushing
    // SuggestionsFromHistoryScreen from HistoryDetailScreen directly. Since this widget is inside that screen,
    // we can just find it via ancestor state using context.findAncestorStateOfType.
    final state = context.findAncestorStateOfType<_HistoryDetailScreenState>();
    final checkinId = state?.widget.checkinId;

    return OutlinedButton.icon(
      icon: Icon(_iconForCategory(category)),
      label: Text(label),
      onPressed: checkinId == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SuggestionsFromHistoryScreen(
                    checkinId: checkinId,
                    initialCategory: category,
                  ),
                ),
              );
            },
    );
  }
}
