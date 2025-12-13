// mood_emoji.dart
/// Maps a mood string to an emoji.
/// Keep this as the single source of truth.
String emojiForMood(String mood) {
  switch (mood.toLowerCase()) {
    // Positive
    case 'happy':
      return '😊';
    case 'calm':
      return '😌';
    case 'content':
      return '🙂';

    // Neutral
    case 'neutral':
      return '😐';
    case 'okay':
      return '👌';
    case 'numb':
      return '😶';

    // Tough
    case 'sad':
      return '😢';
    case 'anxious':
      return '😟';
    case 'stressed':
      return '😣';

    default:
      return '😐';
  }
}
