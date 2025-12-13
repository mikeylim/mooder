// state_tag_formatter.dart
String formatStateTag(String raw) {
  // Example raw: "down_low_energy_mid_tension"
  final parts = raw.split('_');

  String mood = '';
  String energy = '';
  String tension = '';

  for (var i = 0; i < parts.length; i++) {
    final p = parts[i];

    // mood
    if ([
      'down',
      'sad',
      'anxious',
      'stressed',
      'calm',
      'happy',
      'neutral',
      'content',
      'okay',
      'numb',
    ].contains(p)) {
      mood = _capitalize(p);
    }

    // energy
    if (p == 'low' && i + 1 < parts.length && parts[i + 1] == 'energy') {
      energy = 'Low energy';
    }
    if (p == 'mid' && i + 1 < parts.length && parts[i + 1] == 'energy') {
      energy = 'Moderate energy';
    }
    if (p == 'high' && i + 1 < parts.length && parts[i + 1] == 'energy') {
      energy = 'High energy';
    }

    // tension
    if (p == 'low' && i + 1 < parts.length && parts[i + 1] == 'tension') {
      tension = 'Low tension';
    }
    if (p == 'mid' && i + 1 < parts.length && parts[i + 1] == 'tension') {
      tension = 'Moderate tension';
    }
    if (p == 'high' && i + 1 < parts.length && parts[i + 1] == 'tension') {
      tension = 'High tension';
    }
  }

  final pieces = <String>[
    if (mood.isNotEmpty) 'Feeling $mood',
    if (energy.isNotEmpty) energy,
    if (tension.isNotEmpty) tension,
  ];

  return pieces.isEmpty ? '—' : pieces.join(' · ');
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
