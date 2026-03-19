import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/walking_mission_service.dart';

class WalkingMissionsPage extends StatefulWidget {
  const WalkingMissionsPage({super.key});

  @override
  State<WalkingMissionsPage> createState() => _WalkingMissionsPageState();
}

class _WalkingMissionsPageState extends State<WalkingMissionsPage> {
  final WalkingMissionService _service = WalkingMissionService();

  List<WalkingMission> _missions = <WalkingMission>[];
  List<WalkingMission> _history = <WalkingMission>[];
  WalkingMission? _activeMission;
  StreamSubscription<Position>? _subscription;
  Position? _lastPosition;
  double _distanceMeters = 0;
  bool _isLoading = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final history = await _service.loadHistory();
    if (!mounted) return;
    setState(() {
      _missions = _service.buildSuggestedMissions();
      _history = history.take(5).toList();
      _isLoading = false;
    });
  }

  Future<void> _startMission(WalkingMission mission) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _status = 'Turn on location services to start a mission.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _status = 'Location permission is required for walking missions.';
      });
      return;
    }

    final initial = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
      ),
    );

    await _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onPosition);

    if (!mounted) return;
    setState(() {
      _activeMission = mission;
      _lastPosition = initial;
      _distanceMeters = 0;
      _status = 'Mission started. Keep moving to reach the route goal.';
    });
  }

  void _onPosition(Position position) {
    final previous = _lastPosition;
    if (previous == null || _activeMission == null) {
      _lastPosition = position;
      return;
    }

    final delta = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    if (delta < 3 || delta > 250) {
      _lastPosition = position;
      return;
    }

    setState(() {
      _distanceMeters += delta;
      _lastPosition = position;
    });

    final targetMeters = _activeMission!.targetKm * 1000;
    if (_distanceMeters >= targetMeters) {
      unawaited(_completeMission());
    }
  }

  Future<void> _completeMission() async {
    final mission = _activeMission;
    if (mission == null) return;
    await _subscription?.cancel();
    final completed = mission.copyWith(completedAt: DateTime.now());
    await _service.saveCompletedMission(completed);
    if (!mounted) return;
    setState(() {
      _activeMission = null;
      _status = 'Mission complete: ${completed.title}';
    });
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${completed.title} completed at ${(completed.targetKm).toStringAsFixed(1)} km',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _cancelMission() async {
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _activeMission = null;
      _distanceMeters = 0;
      _lastPosition = null;
      _status = 'Mission canceled.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Walking Missions'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: text,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Route Goals',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _activeMission == null
                              ? 'Pick a mission and we will track your live distance.'
                              : 'Active: ${_activeMission!.title}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        if (_activeMission != null) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: math.min(
                              1,
                              _distanceMeters /
                                  (_activeMission!.targetKm * 1000),
                            ),
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_distanceMeters / 1000).toStringAsFixed(2)} / ${_activeMission!.targetKm.toStringAsFixed(1)} km',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _status!,
                      style: TextStyle(color: sub),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Suggested Missions',
                    style: TextStyle(
                      color: text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._missions.map(
                    (mission) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mission.title,
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mission.subtitle,
                            style: TextStyle(color: sub),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${mission.targetKm.toStringAsFixed(1)} km goal',
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _activeMission == null
                                    ? () => _startMission(mission)
                                    : null,
                                child: const Text('Start'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_activeMission != null)
                    OutlinedButton.icon(
                      onPressed: _cancelMission,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel Active Mission'),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'Recent Wins',
                    style: TextStyle(
                      color: text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Completed walking missions will show up here.',
                        style: TextStyle(color: sub),
                      ),
                    ),
                  ..._history.map(
                    (mission) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.route_rounded),
                      title: Text(mission.title, style: TextStyle(color: text)),
                      subtitle: Text(
                        '${mission.targetKm.toStringAsFixed(1)} km • ${mission.theme}',
                        style: TextStyle(color: sub),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
