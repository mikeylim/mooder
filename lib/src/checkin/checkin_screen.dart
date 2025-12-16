// checkin_screen.dart
import 'package:flutter/material.dart';

import '../utils/app_copy.dart';
import '../utils/state_tag_formatter.dart';
import 'checkin_models.dart';
import 'checkin_repository.dart';
import 'checkin_result_screen.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _repo = CheckInRepository();

  int _step = 0;

  PrimaryMood _primaryMood = PrimaryMood.neutral;
  int _intensity = 5;
  int _energy = 5;
  int _focus = 5;
  int _connection = 5;
  int _tension = 5;

  bool _selfHarmThoughts = false;

  final List<String> _allDrivers = const [
    'Stress',
    'Work/School',
    'Relationships',
    'Health',
    'Money',
    'Loneliness',
    'Sleep',
    'Self-esteem',
    'Uncertainty',
    'Other',
  ];
  final Set<String> _selectedDrivers = {};

  bool _loading = false;
  String? _error;

  int get _totalSteps => 5;

  void _toggleDriver(String d) {
    setState(() {
      _error = null;
      if (_selectedDrivers.contains(d)) {
        _selectedDrivers.remove(d);
      } else {
        if (_selectedDrivers.length >= 3) {
          _error = AppCopy.errPickUpTo3Drivers; // add to AppCopy (recommended)
          return;
        }
        _selectedDrivers.add(d);
      }
    });
  }

  void _next() {
    setState(() {
      _error = null;
      if (_step < _totalSteps - 1) _step += 1;
    });
  }

  void _back() {
    setState(() {
      _error = null;
      if (_step > 0) _step -= 1;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final input = _previewInput();

    try {
      final checkinId = await _repo.saveCheckIn(input);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              CheckInResultScreen(input: input, checkinId: checkinId),
        ),
      );
    } catch (_) {
      setState(() => _error = AppCopy.errGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  CheckInInput _previewInput() {
    return CheckInInput(
      primaryMood: _primaryMood,
      intensity: _intensity,
      energy: _energy,
      focus: _focus,
      connection: _connection,
      tension: _tension,
      drivers: _selectedDrivers.toList(),
      selfHarmThoughts: _selfHarmThoughts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stateTagPreview = _previewInput().computeStateTag();

    return Scaffold(
      appBar: AppBar(title: const Text(AppCopy.checkInTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppCopy.stepPrefix} ${_step + 1} of $_totalSteps',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatStateTag(stateTagPreview),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: (_step + 1) / _totalSteps),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(child: _buildStepContent(context)),
            ),

            const SizedBox(height: 10),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : (_step == 0 ? null : _back),
                    child: const Text(AppCopy.back),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : (_step == _totalSteps - 1 ? _submit : _next),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _step == _totalSteps - 1
                                ? AppCopy.saveCheckIn
                                : AppCopy.next,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_step) {
      case 0:
        return _stepMood();
      case 1:
        return _stepIntensityEnergy();
      case 2:
        return _stepQuickChecks();
      case 3:
        return _stepDrivers();
      case 4:
      default:
        return _stepSafetyAndReview();
    }
  }

  Widget _stepMood() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(AppCopy.moodQuestion),
        const SizedBox(height: 8),
        DropdownButtonFormField<PrimaryMood>(
          initialValue: _primaryMood,
          items: PrimaryMood.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
              .toList(),
          onChanged: (v) =>
              setState(() => _primaryMood = v ?? PrimaryMood.neutral),
        ),
        const SizedBox(height: 16),
        Text(AppCopy.moodTip, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _stepIntensityEnergy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sliderQuestion(
          title: AppCopy.intensityLabel,
          value: _intensity,
          helper: AppCopy.scaleHintIntensity, // add to AppCopy (recommended)
          onChanged: (v) => setState(() => _intensity = v),
        ),
        _sliderQuestion(
          title: AppCopy.energyLabel,
          value: _energy,
          helper: AppCopy.scaleHintEnergy, // add to AppCopy (recommended)
          onChanged: (v) => setState(() => _energy = v),
        ),
      ],
    );
  }

  Widget _stepQuickChecks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(AppCopy.quickCheckTitle),
        const SizedBox(height: 8),
        _sliderQuestion(
          title: AppCopy.focusLabel,
          value: _focus,
          helper: AppCopy.scaleHintFocus, // add to AppCopy (recommended)
          onChanged: (v) => setState(() => _focus = v),
        ),
        _sliderQuestion(
          title: AppCopy.connectionLabel,
          value: _connection,
          helper: AppCopy.scaleHintConnection, // add to AppCopy (recommended)
          onChanged: (v) => setState(() => _connection = v),
        ),
        _sliderQuestion(
          title: AppCopy.tensionLabel,
          value: _tension,
          helper: AppCopy.scaleHintTension, // add to AppCopy (recommended)
          onChanged: (v) => setState(() => _tension = v),
        ),
      ],
    );
  }

  Widget _stepDrivers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(AppCopy.driversTitle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allDrivers.map((d) {
            final selected = _selectedDrivers.contains(d);
            return FilterChip(
              selected: selected,
              label: Text(d),
              onSelected: (_) => _toggleDriver(d),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          _selectedDrivers.isEmpty
              ? 'Selected: ${AppCopy.driversNone}'
              : 'Selected: ${_selectedDrivers.join(", ")}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _stepSafetyAndReview() {
    final preview = _previewInput();
    final stateTagPreview = preview.computeStateTag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text(AppCopy.safetyTitle),
          subtitle: const Text(AppCopy.safetySubtitle),
          value: _selfHarmThoughts,
          onChanged: (v) => setState(() => _selfHarmThoughts = v),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppCopy.reviewTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Mood: ${_primaryMood.label}'),
                Text('${AppCopy.intensityLabel}: $_intensity / 10'),
                Text('${AppCopy.energyLabel}: $_energy / 10'),
                Text('${AppCopy.focusLabel}: $_focus / 10'),
                Text('${AppCopy.connectionLabel}: $_connection / 10'),
                Text('${AppCopy.tensionLabel}: $_tension / 10'),
                Text(
                  _selectedDrivers.isEmpty
                      ? 'Drivers: ${AppCopy.driversNone}'
                      : 'Drivers: ${_selectedDrivers.join(", ")}',
                ),
                const SizedBox(height: 8),
                Text(
                  formatStateTag(stateTagPreview),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (preview.selfHarmThoughts) ...[
                  const SizedBox(height: 8),
                  Text(
                    AppCopy.safetyWillEnable,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sliderQuestion({
    required String title,
    required int value,
    required String helper,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 4),
        Text(helper, style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: value.toString(),
          onChanged: (v) => onChanged(v.round()),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
