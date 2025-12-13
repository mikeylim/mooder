// home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../checkin/checkin_screen.dart';
import '../history/history_screen.dart';
import '../insights/insights_screen.dart';
import '../utils/app_copy.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Query<Map<String, dynamic>> _latestCheckInQuery(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('checkins')
        .orderBy('createdAt', descending: true)
        .limit(1);
  }

  String _lastCheckInText(Timestamp? ts) {
    if (ts == null) return AppCopy.lastCheckInNever;

    final now = DateTime.now();
    final dt = ts.toDate().toLocal();
    final diffDays = now.difference(dt).inDays;

    if (diffDays <= 0) return AppCopy.lastCheckInToday;
    if (diffDays == 1) return AppCopy.lastCheckInYesterday;
    return '$diffDays days ago';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '(unknown)';
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppCopy.appName),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: AppCopy.signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Signed in as $email'),
            const SizedBox(height: 10),

            // ✅ Last check-in line
            if (uid != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _latestCheckInQuery(uid).snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Text(
                      '${AppCopy.lastCheckInLabel}: …',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  final ts = docs.isEmpty
                      ? null
                      : (docs.first.data()['createdAt'] as Timestamp?);

                  return Text(
                    '${AppCopy.lastCheckInLabel}: ${_lastCheckInText(ts)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckInScreen()),
                );
              },
              child: const Text(AppCopy.startCheckIn),
            ),
            const SizedBox(height: 8),

            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
              child: const Text(AppCopy.viewHistory),
            ),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                );
              },
              icon: const Icon(Icons.insights),
              label: const Text(AppCopy.viewInsights),
            ),
          ],
        ),
      ),
    );
  }
}
