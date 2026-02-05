import 'dart:async';

import 'package:flutter/material.dart';

import '../models/manual_workout_template.dart';
import '../services/workout_log_service.dart';

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({
    super.key,
    required this.template,
    required this.logService,
  });

  final ManualWorkoutTemplate template;
  final WorkoutLogService logService;

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  DateTime? _sessionStart;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isSaving = false;
  String? _error;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;

  static const double _assumedWeightKg = 70;

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  double get _caloriesBurned {
    final effectiveDuration = _stopwatch.elapsed - _pausedDuration;
    final minutes = effectiveDuration.inSeconds / 60.0;
    if (minutes <= 0) return 0;
    final caloriesPerMinute = (widget.template.met * 3.5 * _assumedWeightKg) / 200;
    return caloriesPerMinute * minutes;
  }

  String get _timerLabel {
    final effectiveDuration = _stopwatch.elapsed - _pausedDuration;
    final hours = effectiveDuration.inHours.toString().padLeft(2, '0');
    final minutes = effectiveDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = effectiveDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _startWorkout() {
    if (_isRunning && !_isPaused) return;
    
    setState(() {
      if (!_isRunning) {
        _isRunning = true;
        _sessionStart = DateTime.now();
      }
      _isPaused = false;
      _error = null;
      
      // If resuming from pause, add the pause duration
      if (_pauseStartTime != null) {
        _pausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }
    });
    _stopwatch.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _pauseWorkout() {
    if (!_isRunning || _isPaused) return;
    
    setState(() {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
    });
    _stopwatch.stop();
    _ticker?.cancel();
  }

  Future<void> _finishWorkout() async {
    if (!_isRunning || _sessionStart == null) {
      setState(() {
        _error = 'Start the workout before saving.';
      });
      return;
    }

    // Calculate effective duration (excluding paused time)
    Duration effectiveDuration;
    if (_pauseStartTime != null) {
      // If currently paused, add the current pause duration to total paused time
      final currentPause = DateTime.now().difference(_pauseStartTime!);
      final totalPaused = _pausedDuration + currentPause;
      effectiveDuration = _stopwatch.elapsed - totalPaused;
    } else {
      effectiveDuration = _stopwatch.elapsed - _pausedDuration;
    }

    if (effectiveDuration.inSeconds < 10) {
      setState(() {
        _error = 'Keep going for at least 10 seconds to log a workout.';
      });
      return;
    }

    final durationSeconds = effectiveDuration.inSeconds;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    _ticker?.cancel();
    _stopwatch.stop();

    try {
      // Calculate calories and ensure it's valid
      final caloriesValue = _caloriesBurned;
      final caloriesToSave = caloriesValue > 0 ? caloriesValue : 0.1;
      
      // Debug logging
      debugPrint('Saving workout:');
      debugPrint('  Type: ${widget.template.title}');
      debugPrint('  Start: ${_sessionStart!.toIso8601String()}');
      debugPrint('  Duration: $durationSeconds seconds');
      debugPrint('  Calories: $caloriesToSave');
      debugPrint('  MET: ${widget.template.met}');
      
      final log = await widget.logService.createLog(
        workoutType: widget.template.title,
        startTime: _sessionStart!,
        durationSeconds: durationSeconds,
        calories: caloriesToSave,
        met: widget.template.met,
      );

      if (!mounted) return;

      if (log == null) {
        setState(() {
          _isSaving = false;
          _error = 'Could not save workout. Please try again.';
        });
        return;
      }

      Navigator.of(context).pop(log);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        // Extract clean error message
        final errorStr = error.toString();
        if (errorStr.startsWith('Exception: ')) {
          _error = errorStr.substring(11);
        } else {
          _error = errorStr;
        }
      });
    }
  }

  Future<bool> _confirmExit() async {
    if (!_isRunning || _isSaving) {
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard session?'),
          content: const Text('You have an active workout. Do you want to discard it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final accent = template.accentColor;
    final gradient = template.gradientColors.length >= 2
        ? LinearGradient(
            colors: template.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return PopScope(
      canPop: !_isRunning || _isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmExit();
        if (!context.mounted) return;
        if (shouldPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(template.title),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white,
          foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFF1F5F9)
              : Colors.black,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: gradient,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(template.icon, size: 48, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      template.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'Difficulty • ${template.difficulty}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Live Session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _timerLabel,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _SessionStat(
                          label: 'Calories',
                          value: _caloriesBurned.toStringAsFixed(1),
                          unit: 'kcal',
                        ),
                        _SessionStat(
                          label: 'Intensity',
                          value: template.difficulty,
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (!_isRunning)
                      ElevatedButton(
                        onPressed: _isSaving ? null : _startWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Start Workout'),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : _isPaused
                                      ? _startWorkout
                                      : _pauseWorkout,
                              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                              label: Text(_isPaused ? 'Resume' : 'Pause'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isPaused
                                    ? Colors.green
                                    : Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _finishWorkout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Finish & Save'),
                            ),
                          ),
                        ],
                      ),
                      if (!_isSaving)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextButton(
                            onPressed: () async {
                              final shouldDiscard = await _confirmExit();
                              if (!context.mounted) return;
                              if (shouldDiscard) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text('Cancel Session'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  const _SessionStat({
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (unit != null)
          Text(
            unit!,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

