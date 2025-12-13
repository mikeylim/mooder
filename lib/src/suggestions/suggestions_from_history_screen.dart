// suggestions_from_history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../checkin/checkin_models.dart';
import 'suggestions_screen.dart';

class SuggestionsFromHistoryScreen extends StatefulWidget {
  final String checkinId;
  final String initialCategory;

  const SuggestionsFromHistoryScreen({
    super.key,
    required this.checkinId,
    required this.initialCategory,
  });

  @override
  State<SuggestionsFromHistoryScreen> createState() =>
      _SuggestionsFromHistoryScreenState();
}

class _SuggestionsFromHistoryScreenState
    extends State<SuggestionsFromHistoryScreen> {
  DocumentReference<Map<String, dynamic>> _checkinRef() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('checkins')
        .doc(widget.checkinId);
  }

  Future<CheckInInput> _loadInput() async {
    final snap = await _checkinRef().get();
    final data = snap.data();
    if (data == null) throw Exception('Check-in not found');
    return CheckInInput.fromMap(data);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('You’re not signed in.')));
    }

    return FutureBuilder<CheckInInput>(
      future: _loadInput(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Suggestions')),
            body: const Center(child: Text('Couldn’t load this check-in.')),
          );
        }

        return SuggestionsScreen(
          input: snap.data!,
          checkinId: widget.checkinId,
          initialCategory: widget.initialCategory,
        );
      },
    );
  }
}
