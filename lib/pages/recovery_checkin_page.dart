import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/recovery_checkin_service.dart';

class RecoveryCheckInPage extends StatefulWidget {
  const RecoveryCheckInPage({super.key});

  @override
  State<RecoveryCheckInPage> createState() => _RecoveryCheckInPageState();
}

class _RecoveryCheckInPageState extends State<RecoveryCheckInPage> {
  final RecoveryCheckInService _service = RecoveryCheckInService();

  RecoveryCheckIn? _entry;
  RecoveryInsight? _insight;
  bool _isLoading = true;
  bool _isSaving = false;

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = await _service.loadEntry(_todayKey);
    final insight = _service.buildInsight(
      energy: entry.energy,
      soreness: entry.soreness,
      sleepQuality: entry.sleepQuality,
      stress: entry.stress,
    );
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _insight = insight;
      _isLoading = false;
    });
  }

  Future<void> _save({
    int? energy,
    int? soreness,
    int? sleepQuality,
    int? stress,
  }) async {
    final current = _entry;
    if (current == null) return;
    final insight = _service.buildInsight(
      energy: energy ?? current.energy,
      soreness: soreness ?? current.soreness,
      sleepQuality: sleepQuality ?? current.sleepQuality,
      stress: stress ?? current.stress,
    );
    final updated = RecoveryCheckIn(
      dateKey: current.dateKey,
      energy: energy ?? current.energy,
      soreness: soreness ?? current.soreness,
      sleepQuality: sleepQuality ?? current.sleepQuality,
      stress: stress ?? current.stress,
      recommendation: insight.recommendation,
    );

    setState(() {
      _entry = updated;
      _insight = insight;
      _isSaving = true;
    });
    await _service.saveEntry(updated);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _entry == null || _insight == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recovery Check-In'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: text,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Readiness Score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_insight!.score}/100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _insight!.title,
                  style: const TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _insight!.recommendation,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (_isSaving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _RecoverySliderCard(
            title: 'Energy',
            subtitle: 'How ready do you feel physically?',
            value: _entry!.energy,
            onChanged: (value) => _save(energy: value),
          ),
          const SizedBox(height: 12),
          _RecoverySliderCard(
            title: 'Soreness',
            subtitle: 'How sore or beat up do you feel?',
            value: _entry!.soreness,
            onChanged: (value) => _save(soreness: value),
          ),
          const SizedBox(height: 12),
          _RecoverySliderCard(
            title: 'Sleep Quality',
            subtitle: 'How restorative was your sleep?',
            value: _entry!.sleepQuality,
            onChanged: (value) => _save(sleepQuality: value),
          ),
          const SizedBox(height: 12),
          _RecoverySliderCard(
            title: 'Stress',
            subtitle: 'How mentally loaded do you feel today?',
            value: _entry!.stress,
            onChanged: (value) => _save(stress: value),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Use this before training. The score does not replace medical advice, but it helps guide whether today should be hard, moderate, or recovery-focused.',
              style: TextStyle(color: sub, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoverySliderCard extends StatelessWidget {
  const _RecoverySliderCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$value/5',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: sub, fontSize: 12),
          ),
          Slider(
            min: 1,
            max: 5,
            divisions: 4,
            value: value.toDouble(),
            onChanged: (newValue) => onChanged(newValue.round()),
          ),
        ],
      ),
    );
  }
}
