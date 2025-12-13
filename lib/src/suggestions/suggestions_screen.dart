// suggestions_screen.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../checkin/checkin_models.dart';
import '../utils/app_copy.dart';
import '../utils/state_tag_formatter.dart';

const String backendBaseUrl = 'http://192.168.45.252:8787';

class SuggestionsScreen extends StatefulWidget {
  final CheckInInput input;
  final String checkinId;

  /// ✅ If provided, screen auto-loads that category.
  final String? initialCategory;

  const SuggestionsScreen({
    super.key,
    required this.input,
    required this.checkinId,
    this.initialCategory,
  });

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  bool _loading = false;
  Map<String, dynamic>? _result;

  String? _status;
  String? _lastCategory;

  DocumentReference<Map<String, dynamic>> _checkinRef() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('checkins')
        .doc(widget.checkinId);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetch(initial);
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _labelForCategory(String c) {
    final s = c.replaceAll('_', ' ').trim();
    if (s.isEmpty) return c;
    return s[0].toUpperCase() + s.substring(1);
  }

  IconData _iconForCategory(String c) {
    switch (c) {
      case 'quick_actions':
        return Icons.bolt;
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

  Future<void> _fetch(String category) async {
    if (_loading) return;

    if (widget.input.selfHarmThoughts) {
      _snack(AppCopy.safetyDisabledSuggestions);
      setState(() {
        _status = 'Safety mode';
        _result = null;
        _lastCategory = category;
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _status = null;
      _lastCategory = category;
    });

    try {
      // 1) Try Firestore first
      final snap = await _checkinRef().get();
      final data = snap.data();
      final saved = (data?['suggestions'] as Map?)?[category];

      if (saved != null) {
        setState(() {
          _result = Map<String, dynamic>.from(saved as Map);
          _status = AppCopy.loadedFromSaved;
        });
        _snack(AppCopy.loadedFromSaved);
        return;
      }

      // 2) Otherwise call backend
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final token = await user.getIdToken();
      final url = Uri.parse('$backendBaseUrl/suggestions');

      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'category': category,
          'stateTag': widget.input.computeStateTag(),
          'primaryMood': widget.input.primaryMood.name,
          'intensity': widget.input.intensity,
          'energy': widget.input.energy,
          'tension': widget.input.tension,
          'drivers': widget.input.drivers,
          'selfHarmThoughts': widget.input.selfHarmThoughts,
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Server ${resp.statusCode}: ${resp.body}');
      }

      final result = jsonDecode(resp.body) as Map<String, dynamic>;

      // 3) Save to Firestore
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
        _result = result;
        _status = AppCopy.generatedNow;
      });
      _snack(AppCopy.generatedNow);
    } catch (e) {
      _snack(AppCopy.errGeneric);
      setState(() {
        _status = AppCopy.errGeneric;
        _result = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const categories = [
      'quick_actions',
      'activities',
      'meditation',
      'food',
      'books',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppCopy.suggestionsTitle),
        actions: [
          IconButton(
            tooltip: AppCopy.backToHome,
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatStateTag(widget.input.computeStateTag()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              AppCopy.suggestionsHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),

            if (_status != null)
              Text(_status!, style: Theme.of(context).textTheme.bodySmall),

            const SizedBox(height: 12),

            // ✅ OutlinedButton.icon style (matches HistoryDetail)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final label = _labelForCategory(c);
                final selected = _lastCategory == c;

                return OutlinedButton.icon(
                  icon: Icon(_iconForCategory(c), size: 18),
                  onPressed: _loading ? null : () => _fetch(c),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      if (_loading && selected) ...[
                        const SizedBox(width: 10),
                        const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            if (_result != null)
              Expanded(child: _SuggestionsList(data: _result!)),

            if (_result == null && !_loading)
              Expanded(
                child: Center(
                  child: Text(
                    'Pick a category to get ideas.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SuggestionsList({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? AppCopy.suggestionsTitle).toString();
    final items = (data['items'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = Map<String, dynamic>.from(items[i] as Map);
              final text = (m['text'] ?? '').toString();
              final time = (m['time'] ?? '').toString();
              final effort = (m['effort'] ?? '').toString();

              return ListTile(
                title: Text(text),
                subtitle: Text('$time • $effort'),
              );
            },
          ),
        ),
      ],
    );
  }
}
