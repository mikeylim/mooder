// checkin_models.dart
import 'package:flutter/foundation.dart';

enum PrimaryMood {
  // Positive
  happy('Happy'),
  calm('Calm'),
  content('Content'),

  // Neutral
  neutral('Neutral'),
  okay('Okay'),
  numb('Numb'),

  // Tough
  sad('Sad'),
  anxious('Anxious'),
  stressed('Stressed');

  final String label;
  const PrimaryMood(this.label);
}

class CheckInInput {
  final PrimaryMood primaryMood;

  /// Scale: 0..10
  final int intensity;
  final int energy;
  final int focus;
  final int connection;
  final int tension;

  final List<String> drivers;
  final bool selfHarmThoughts;

  const CheckInInput({
    required this.primaryMood,
    required this.intensity,
    required this.energy,
    required this.focus,
    required this.connection,
    required this.tension,
    required this.drivers,
    required this.selfHarmThoughts,
  });

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.round();
    return fallback;
  }

  static int clamp010(dynamic v, {int fallback = 0}) {
    final n = _asInt(v, fallback: fallback);
    return n.clamp(0, 10);
  }

  String computeStateTag() {
    final moodKey = primaryMood.name;
    final energyKey = _bucketKey(energy);
    final tensionKey = _bucketKey(tension);
    return '${moodKey}_${energyKey}_energy_${tensionKey}_tension';
  }

  static String _bucketKey(int v) {
    final x = v.clamp(0, 10);
    if (x <= 3) return 'low';
    if (x <= 6) return 'mid';
    return 'high';
  }

  Map<String, dynamic> toMap() {
    return {
      'moodPrimary': primaryMood.name,
      'intensity': intensity.clamp(0, 10),
      'energy': energy.clamp(0, 10),
      'focus': focus.clamp(0, 10),
      'connection': connection.clamp(0, 10),
      'tension': tension.clamp(0, 10),
      'drivers': drivers,
      'selfHarmThoughts': selfHarmThoughts,
      'stateTag': computeStateTag(),
      'scaleVersion': 2, // optional, harmless now
    };
  }

  static CheckInInput fromMap(Map<String, dynamic> data) {
    final moodName = (data['moodPrimary'] ?? 'neutral').toString();
    final mood = PrimaryMood.values.firstWhere(
      (m) => m.name == moodName,
      orElse: () => PrimaryMood.neutral,
    );

    final driversRaw = data['drivers'];
    final drivers = (driversRaw is List)
        ? driversRaw.map((e) => e.toString()).toList()
        : <String>[];

    return CheckInInput(
      primaryMood: mood,
      intensity: clamp010(data['intensity']),
      energy: clamp010(data['energy']),
      focus: clamp010(data['focus']),
      connection: clamp010(data['connection']),
      tension: clamp010(data['tension']),
      drivers: drivers,
      selfHarmThoughts: data['selfHarmThoughts'] == true,
    );
  }

  @override
  String toString() {
    return 'CheckInInput(mood=${primaryMood.name}, intensity=$intensity, energy=$energy, tension=$tension)';
  }
}
