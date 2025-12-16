// insights_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../checkin/checkin_models.dart';
import '../utils/app_copy.dart';

enum InsightsRange { days7, days30 }

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  InsightsRange _range = InsightsRange.days7;

  DateTime _cutoffDate() {
    final now = DateTime.now();
    return _range == InsightsRange.days7
        ? now.subtract(const Duration(days: 7))
        : now.subtract(const Duration(days: 30));
  }

  Query<Map<String, dynamic>> _query(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('checkins')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_cutoffDate()),
        )
        .orderBy('createdAt', descending: true);
  }

  String get _rangeLabel => _range == InsightsRange.days7
      ? AppCopy.insightsLast7
      : AppCopy.insightsLast30;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(body: Center(child: Text(AppCopy.errGeneric)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppCopy.insightsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<InsightsRange>(
              segments: const [
                ButtonSegment(
                  value: InsightsRange.days7,
                  label: Text(AppCopy.insightsRange7),
                ),
                ButtonSegment(
                  value: InsightsRange.days30,
                  label: Text(AppCopy.insightsRange30),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (set) => setState(() => _range = set.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query(uid).snapshots(),
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
                    child: Text(
                      _range == InsightsRange.days7
                          ? AppCopy.noInsights7
                          : AppCopy.noInsights30,
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // ✅ Parse using CheckInInput.fromMap()
                final inputs = <CheckInInput>[];
                final timestamps = <DateTime>[];

                for (final d in docs) {
                  final data = d.data();
                  inputs.add(CheckInInput.fromMap(data));

                  final ts = data['createdAt'];
                  final when = ts is Timestamp ? ts.toDate().toLocal() : null;
                  timestamps.add(when ?? DateTime.now());
                }

                final stats = _computeStats(inputs);
                final trends = _buildTrendRows(inputs, timestamps);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StatCard(
                      title: AppCopy.insightsSummaryTitle,
                      children: [
                        Text(
                          _rangeLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${AppCopy.insightsCheckinsLabel}: ${stats.total}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${AppCopy.insightsAvgEnergyLabel}: ${stats.avgEnergy.toStringAsFixed(1)} / 10',
                        ),
                        Text(
                          '${AppCopy.insightsAvgTensionLabel}: ${stats.avgTension.toStringAsFixed(1)} / 10',
                        ),
                        Text(
                          '${AppCopy.insightsAvgFocusLabel}: ${stats.avgFocus.toStringAsFixed(1)} / 10',
                        ),
                        Text(
                          '${AppCopy.insightsAvgConnectionLabel}: ${stats.avgConnection.toStringAsFixed(1)} / 10',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ✅ Most common moods (top 5, % of check-ins)
                    _StatCard(
                      title: AppCopy.insightsCommonMoodsTitle,
                      children: stats.moodCounts.isEmpty
                          ? [const Text('No moods recorded yet.')]
                          : stats.moodCounts.entries.take(5).map((e) {
                              final pct = stats.total == 0
                                  ? 0
                                  : (e.value / stats.total) * 100;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(_titleCase(e.key))),
                                    Text(
                                      '${e.value} (${pct.toStringAsFixed(0)}%)',
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Most common drivers (top 5, % of all driver mentions)
                    _StatCard(
                      title: AppCopy.insightsCommonDriversTitle,
                      children: stats.driverCounts.isEmpty
                          ? [const Text(AppCopy.insightsNoDriversYet)]
                          : stats.driverCounts.entries.take(5).map((e) {
                              final pct = stats.totalDriverMentions == 0
                                  ? 0
                                  : (e.value / stats.totalDriverMentions) * 100;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(_titleCase(e.key))),
                                    Text(
                                      '${e.value} (${pct.toStringAsFixed(0)}%)',
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                    ),

                    const SizedBox(height: 12),
                    _TrendCard(trends: trends),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

class _TrendRow {
  final DateTime when;
  final double score;

  _TrendRow({required this.when, required this.score});
}

double _baseMoodScore(String moodName) {
  switch (moodName.toLowerCase()) {
    // Positive
    case 'happy':
      return 8.5;
    case 'good':
      return 8.0;
    case 'calm':
      return 7.5;
    case 'content':
      return 7.0;

    // Neutral / mixed
    case 'okay':
      return 5.5;
    case 'neutral':
      return 5.0;
    case 'numb':
      return 4.5;

    // Tough
    case 'tired':
      return 4.0;
    case 'stressed':
      return 3.5;
    case 'anxious':
      return 3.5;
    case 'angry':
      return 3.0;
    case 'sad':
      return 3.0;
    case 'down':
      return 2.5;

    default:
      return 5.0;
  }
}

String _scoreExplanationText() {
  return '''
Overall score is a simple 0–10 summary used to show trends over time.

It combines:
• your selected mood (base)
• energy, focus, connection (slightly increase/decrease)
• tension (slightly decreases)

Approx equation:

score =
  baseMood
  + 0.18 × (energy − 5)
  + 0.14 × (focus − 5)
  + 0.14 × (connection − 5)
  − 0.18 × (tension − 5)

Then clamped to 0–10.

How to read it:
• Look for direction (up/down) and stability, not “perfect numbers”.
• Big jumps usually mean a different mood choice or big shifts in sliders.
''';
}

double _overallScore(CheckInInput input) {
  // Score is on a 0–10 scale. Mood provides a base value.
  // We then nudge it based on energy/focus/connection (up) and tension (down).
  final base = _baseMoodScore(input.primaryMood.name);

  final energy = input.energy.clamp(0, 10).toDouble();
  final focus = input.focus.clamp(0, 10).toDouble();
  final connection = input.connection.clamp(0, 10).toDouble();
  final tension = input.tension.clamp(0, 10).toDouble();

  // Center around 5 so adjustments are symmetric.
  final e = (energy - 5) * 0.30;
  final f = (focus - 5) * 0.20;
  final c = (connection - 5) * 0.20;
  final t = (tension - 5) * 0.30;

  final score = base + e + f + c - t;
  return score.clamp(0.0, 10.0);
}

List<_TrendRow> _buildTrendRows(
  List<CheckInInput> inputs,
  List<DateTime> timestamps,
) {
  final out = <_TrendRow>[];

  for (var i = 0; i < inputs.length; i++) {
    final input = inputs[i];
    final when = i < timestamps.length ? timestamps[i] : DateTime.now();

    out.add(_TrendRow(when: when, score: _overallScore(input)));
  }
  return out;
}

class _InsightsStats {
  final int total;
  final double avgEnergy;
  final double avgTension;
  final double avgFocus;
  final double avgConnection;

  final Map<String, int> moodCounts;
  final Map<String, int> driverCounts;
  final int totalDriverMentions;

  _InsightsStats({
    required this.total,
    required this.avgEnergy,
    required this.avgTension,
    required this.avgFocus,
    required this.avgConnection,
    required this.moodCounts,
    required this.driverCounts,
    required this.totalDriverMentions,
  });
}

_InsightsStats _computeStats(List<CheckInInput> inputs) {
  int total = 0;

  int sumEnergy = 0;
  int sumTension = 0;
  int sumFocus = 0;
  int sumConnection = 0;

  final moodCounts = <String, int>{};
  final driverCounts = <String, int>{};

  for (final input in inputs) {
    total += 1;

    final moodKey = input.primaryMood.name.toLowerCase();
    moodCounts[moodKey] = (moodCounts[moodKey] ?? 0) + 1;

    sumEnergy += input.energy.clamp(0, 10);
    sumTension += input.tension.clamp(0, 10);
    sumFocus += input.focus.clamp(0, 10);
    sumConnection += input.connection.clamp(0, 10);

    for (final d in input.drivers) {
      final key = d.toString().toLowerCase();
      driverCounts[key] = (driverCounts[key] ?? 0) + 1;
    }
  }

  Map<String, int> sortDesc(Map<String, int> m) {
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in entries) e.key: e.value};
  }

  final sortedMoods = sortDesc(moodCounts);
  final sortedDrivers = sortDesc(driverCounts);
  final totalDriverMentions = sortedDrivers.values.fold<int>(
    0,
    (a, b) => a + b,
  );

  return _InsightsStats(
    total: total,
    avgEnergy: total == 0 ? 0 : sumEnergy / total,
    avgTension: total == 0 ? 0 : sumTension / total,
    avgFocus: total == 0 ? 0 : sumFocus / total,
    avgConnection: total == 0 ? 0 : sumConnection / total,
    moodCounts: sortedMoods,
    driverCounts: sortedDrivers,
    totalDriverMentions: totalDriverMentions,
  );
}

class _StatCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StatCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<_TrendRow> trends;

  const _TrendCard({required this.trends});

  @override
  Widget build(BuildContext context) {
    final points = trends.take(20).toList().reversed.toList();

    if (points.length < 2) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(AppCopy.insightsNotEnoughData),
        ),
      );
    }

    final scoreSpots = <FlSpot>[];

    for (var i = 0; i < points.length; i++) {
      scoreSpots.add(FlSpot(i.toDouble(), points[i].score));
    }

    const scoreColor = Colors.teal;

    final xInterval = (points.length / 4).clamp(1, 6).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppCopy.insightsTrendTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'How this score works',
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => const _OverallScoreInfoDialog(),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              'Overall mood score (0–10) • Recent check-ins',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 10,
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 2,
                    verticalInterval: xInterval,
                  ),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 2,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            value.toInt().toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: xInterval,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.round();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final dt = points[idx].when;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${dt.month}/${dt.day}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: scoreSpots,
                      isCurved: true,
                      barWidth: 3,
                      color: scoreColor,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (LineBarSpot touchedSpot) =>
                          Colors.black87,
                      tooltipRoundedRadius: 10,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      tooltipMargin: 12,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        if (touchedSpots.isEmpty) return const [];

                        // Only one series now. Use the first spot.
                        final s = touchedSpots.first;
                        final idx = s.x.round().clamp(0, points.length - 1);
                        final dt = points[idx].when;
                        final date = '${dt.month}/${dt.day}';

                        return [
                          LineTooltipItem(
                            '$date\nScore: ${s.y.toStringAsFixed(1)}/10',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ];
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _LegendItem(color: scoreColor, label: 'Overall Mood Score'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _OverallScoreInfoDialog extends StatefulWidget {
  const _OverallScoreInfoDialog();

  @override
  State<_OverallScoreInfoDialog> createState() =>
      _OverallScoreInfoDialogState();
}

class _OverallScoreInfoDialogState extends State<_OverallScoreInfoDialog> {
  bool _showFormula = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Overall score (0–10)'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is a simple summary number used to show your trend over time.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'It starts from your selected mood (base), then adjusts slightly based on:',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '• Energy, focus, connection (can raise/lower the score)',
              style: textTheme.bodyMedium,
            ),
            Text(
              '• Tension (generally lowers the score)',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'How to read it:',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '• Focus on direction (up/down) and stability.',
              style: textTheme.bodyMedium,
            ),
            Text(
              '• Don’t overthink exact numbers — it’s not a diagnosis.',
              style: textTheme.bodyMedium,
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // ✅ Collapsible section
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _showFormula = !_showFormula),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(_showFormula ? Icons.expand_less : Icons.expand_more),
                    const SizedBox(width: 8),
                    Text(
                      _showFormula ? 'Hide formula' : 'Show formula',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showFormula) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '''
score =
  baseMood
  + 0.18 × (energy − 5)
  + 0.14 × (focus − 5)
  + 0.14 × (connection − 5)
  − 0.18 × (tension − 5)

then clamped to 0–10
'''
                      .trim(),
                  style: textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: the app’s code uses the same idea with slightly different weights.',
                style: textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
