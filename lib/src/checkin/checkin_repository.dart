// checkin_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'checkin_models.dart';

class CheckInRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CheckInRepository({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  Future<String> saveCheckIn(CheckInInput input) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('User is not logged in.');
    }

    final ref = _db.collection('users').doc(uid).collection('checkins').doc();

    await ref.set({
      ...input.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }
}
