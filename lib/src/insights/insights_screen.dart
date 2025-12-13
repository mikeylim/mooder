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
  final int energy;
  final int tension;
  final int focus;
  final int connection;

  _TrendRow({
    required this.when,
    required this.energy,
    required this.tension,
    required this.focus,
    required this.connection,
  });
}

List<_TrendRow> _buildTrendRows(
  List<CheckInInput> inputs,
  List<DateTime> timestamps,
) {
  final out = <_TrendRow>[];

  for (var i = 0; i < inputs.length; i++) {
    final input = inputs[i];
    final when = i < timestamps.length ? timestamps[i] : DateTime.now();

    out.add(
      _TrendRow(
        when: when,
        energy: input.energy.clamp(0, 10),
        tension: input.tension.clamp(0, 10),
        focus: input.focus.clamp(0, 10),
        connection: input.connection.clamp(0, 10),
      ),
    );
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

    final energySpots = <FlSpot>[];
    final tensionSpots = <FlSpot>[];
    final focusSpots = <FlSpot>[];
    final connectionSpots = <FlSpot>[];

    for (var i = 0; i < points.length; i++) {
      energySpots.add(FlSpot(i.toDouble(), points[i].energy.toDouble()));
      tensionSpots.add(FlSpot(i.toDouble(), points[i].tension.toDouble()));
      focusSpots.add(FlSpot(i.toDouble(), points[i].focus.toDouble()));
      connectionSpots.add(
        FlSpot(i.toDouble(), points[i].connection.toDouble()),
      );
    }

    const energyColor = Colors.green;
    const tensionColor = Colors.red;
    const focusColor = Colors.blue;
    const connectionColor = Colors.purple;

    final xInterval = (points.length / 4).clamp(1, 6).toDouble();

    String _seriesLabel(int barIndex) {
      switch (barIndex) {
        case 0:
          return AppCopy.insightsLegendEnergy;
        case 1:
          return AppCopy.insightsLegendTension;
        case 2:
          return AppCopy.insightsLegendFocus;
        case 3:
          return AppCopy.insightsLegendConnection;
        default:
          return 'Value';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppCopy.insightsTrendTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Y-axis: level (0–10) • X-axis: recent check-ins',
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
                      spots: energySpots,
                      isCurved: true,
                      barWidth: 3,
                      color: energyColor,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: tensionSpots,
                      isCurved: true,
                      barWidth: 3,
                      color: tensionColor,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: focusSpots,
                      isCurved: true,
                      barWidth: 3,
                      color: focusColor,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: connectionSpots,
                      isCurved: true,
                      barWidth: 3,
                      color: connectionColor,
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

                        final spots = [...touchedSpots]
                          ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

                        final idx = spots.first.x.round().clamp(
                          0,
                          points.length - 1,
                        );
                        final dt = points[idx].when;
                        final date = '${dt.month}/${dt.day}';

                        final combined = LineTooltipItem(
                          '$date\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          children: spots.map((s) {
                            final label = _seriesLabel(s.barIndex);
                            return TextSpan(
                              text: '$label: ${s.y.round()}/10\n',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        );

                        return [
                          combined,
                          ...List<LineTooltipItem?>.filled(
                            spots.length - 1,
                            null,
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
                _LegendItem(
                  color: energyColor,
                  label: AppCopy.insightsLegendEnergy,
                ),
                _LegendItem(
                  color: tensionColor,
                  label: AppCopy.insightsLegendTension,
                ),
                _LegendItem(
                  color: focusColor,
                  label: AppCopy.insightsLegendFocus,
                ),
                _LegendItem(
                  color: connectionColor,
                  label: AppCopy.insightsLegendConnection,
                ),
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
