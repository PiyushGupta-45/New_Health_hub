import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Represents the type of failure that occurred while trying to sync data
/// from Health Connect.
enum HealthSyncErrorType {
  /// Runtime permissions, Health Connect permissions, or both were denied.
  permissionsDenied,

  /// Health Connect is not installed or not available on the device.
  healthConnectUnavailable,

  /// The current platform is not supported for Samsung Health syncing.
  platformNotSupported,

  /// An unexpected error occurred.
  unknown,
}

/// Exception thrown when the health data synchronization cannot be completed.
class HealthSyncException implements Exception {
  const HealthSyncException(this.type, this.message, {this.cause});

  final HealthSyncErrorType type;
  final String message;
  final Object? cause;

  @override
  String toString() => 'HealthSyncException($type): $message';
}

/// Summary of a single workout pulled from Health Connect.
class WorkoutEntry {
  WorkoutEntry({
    required this.typeLabel,
    required this.start,
    required this.end,
    required this.sourceName,
    this.distanceKm,
    this.energyKcal,
    this.steps,
  });

  factory WorkoutEntry.fromHealthDataPoint(HealthDataPoint point) {
    final workoutValue = point.value is WorkoutHealthValue
        ? point.value as WorkoutHealthValue
        : null;
    final summary = point.workoutSummary;

    final totalDistanceMeters = _pickNonZeroValue<num>([
      summary?.totalDistance,
      workoutValue?.totalDistance,
    ]);
    final totalEnergy = _pickNonZeroValue<num>([
      summary?.totalEnergyBurned,
      workoutValue?.totalEnergyBurned,
    ]);
    final totalSteps = _pickNonZeroValue<num>([
      summary?.totalSteps,
      workoutValue?.totalSteps,
    ]);

    return WorkoutEntry(
      typeLabel: _formatWorkoutType(
        workoutValue?.workoutActivityType.name ??
            summary?.workoutType ??
            'Workout',
      ),
      start: point.dateFrom,
      end: point.dateTo,
      sourceName: point.sourceName,
      distanceKm: totalDistanceMeters != null
          ? totalDistanceMeters.toDouble() / 1000
          : null,
      energyKcal: totalEnergy?.toDouble(),
      steps: totalSteps?.toInt(),
    );
  }

  final String typeLabel;
  final DateTime start;
  final DateTime end;
  final String sourceName;
  final double? distanceKm;
  final double? energyKcal;
  final int? steps;

  Duration get duration => end.difference(start);

  static T? _pickNonZeroValue<T extends num>(List<T?> values) {
    for (final value in values) {
      if (value != null && value > 0) {
        return value;
      }
    }
    return null;
  }

  static String _formatWorkoutType(String raw) {
    if (raw.isEmpty) return 'Workout';
    final normalized = raw.replaceAll('_', ' ').toLowerCase();
    return normalized
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}

/// Result returned after a successful sync.
class HealthSyncSnapshot {
  const HealthSyncSnapshot({
    required this.todaySteps,
    required this.workouts,
    required this.rangeStart,
    required this.rangeEnd,
    required this.locationPermissionGranted,
    this.stepsBySource = const {},
    this.primaryStepsSource,
  });

  final int todaySteps;
  final List<WorkoutEntry> workouts;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool locationPermissionGranted;
  final Map<String, int> stepsBySource;
  final String? primaryStepsSource;

  int get workoutCount => workouts.length;
}

/// Handles all interactions with the health plugin and Health Connect.
class HealthSyncService {
  HealthSyncService({Health? healthClient})
    : _health = healthClient ?? Health();

  final Health _health;

  bool _configured = false;

  static const Duration defaultLookBackPeriod = Duration(days: 7);

  static const List<HealthDataType> _requiredTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SPEED,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  /// Opens the Health Connect install page on Android devices.
  Future<void> openHealthConnectInstallPage() async {
    try {
      await _health.installHealthConnect();
    } catch (_) {
      // Ignore errors when trying to open the install page.
    }
  }

  /// Synchronises the latest health metrics needed for the application.
  Future<HealthSyncSnapshot> sync({
    Duration lookBack = defaultLookBackPeriod,
  }) async {
    if (!Platform.isAndroid) {
      throw const HealthSyncException(
        HealthSyncErrorType.platformNotSupported,
        'Samsung Health syncing is currently supported on Android devices only.',
      );
    }

    await _ensureConfigured();

    if (!await _health.isHealthConnectAvailable()) {
      throw const HealthSyncException(
        HealthSyncErrorType.healthConnectUnavailable,
        'Health Connect is not installed or not available on this device.',
      );
    }

    final runtimePermissions = await _requestRuntimePermissions();

    await _ensureHealthPermissions();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final rangeStart = now.subtract(lookBack);

    int todaySteps = 0;
    Map<String, int> stepsBySource = const {};
    String? primaryStepsSource;
    try {
      stepsBySource = await _collectStepsBySource(
        startTime: startOfDay,
        endTime: now,
      );
      if (stepsBySource.isNotEmpty) {
        primaryStepsSource = _selectPrimaryStepsSource(stepsBySource);
        if (primaryStepsSource != null) {
          todaySteps = stepsBySource[primaryStepsSource]!;
        }
      }
    } catch (_) {
      todaySteps = 0;
      stepsBySource = const {};
    }

    if (todaySteps == 0 && stepsBySource.isEmpty) {
      try {
        todaySteps =
            await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
        if (todaySteps > 0) {
          stepsBySource = {'All sources': todaySteps};
          primaryStepsSource = 'All sources';
        }
      } catch (_) {
        todaySteps = 0;
        stepsBySource = const {};
      }
    }

    List<WorkoutEntry> workouts = <WorkoutEntry>[];
    try {
      final rawWorkouts = await _health.getHealthDataFromTypes(
        startTime: rangeStart,
        endTime: now,
        types: const [HealthDataType.WORKOUT],
      );
      final cleaned = _health.removeDuplicates(rawWorkouts);
      workouts =
          cleaned
              .where(
                (point) =>
                    point.workoutSummary != null ||
                    point.value is WorkoutHealthValue,
              )
              .map(WorkoutEntry.fromHealthDataPoint)
              .toList()
            ..sort((a, b) => b.start.compareTo(a.start));
    } on UnsupportedError catch (error) {
      throw HealthSyncException(
        HealthSyncErrorType.unknown,
        'Failed to read workouts from Health Connect: ${error.message}',
        cause: error,
      );
    } catch (error) {
      throw HealthSyncException(
        HealthSyncErrorType.unknown,
        'Unexpected error while reading workouts from Health Connect.',
        cause: error,
      );
    }

    return HealthSyncSnapshot(
      todaySteps: todaySteps,
      workouts: workouts,
      rangeStart: rangeStart,
      rangeEnd: now,
      locationPermissionGranted: runtimePermissions.locationGranted,
      stepsBySource: stepsBySource,
      primaryStepsSource: primaryStepsSource,
    );
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<void> _ensureHealthPermissions() async {
    final permissions = List<HealthDataAccess>.filled(
      _requiredTypes.length,
      HealthDataAccess.READ,
    );

    final hasPermissions =
        await _health.hasPermissions(
          _requiredTypes,
          permissions: permissions,
        ) ??
        false;

    if (hasPermissions) return;

    final granted = await _health.requestAuthorization(
      _requiredTypes,
      permissions: permissions,
    );

    if (!granted) {
      throw const HealthSyncException(
        HealthSyncErrorType.permissionsDenied,
        'Health Connect permissions were not granted.',
      );
    }
  }

  Future<_RuntimePermissionResult> _requestRuntimePermissions() async {
    if (!Platform.isAndroid) {
      return const _RuntimePermissionResult(
        activityRecognitionGranted: true,
        locationGranted: true,
      );
    }

    final activityStatus = await _ensurePermissionGranted(
      Permission.activityRecognition,
    );
    if (!activityStatus.isGranted) {
      throw const HealthSyncException(
        HealthSyncErrorType.permissionsDenied,
        'Activity recognition permission is required to read step counts.',
      );
    }

    final locationStatus = await _ensurePermissionGranted(Permission.location);

    return _RuntimePermissionResult(
      activityRecognitionGranted: activityStatus.isGranted,
      locationGranted: locationStatus.isGranted,
    );
  }

  Future<PermissionStatus> _ensurePermissionGranted(
    Permission permission,
  ) async {
    final status = await permission.status;
    if (status.isGranted) return status;

    final result = await permission.request();
    return result;
  }

  Future<Map<String, int>> _collectStepsBySource({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final rawStepPoints = await _health.getHealthDataFromTypes(
      startTime: startTime,
      endTime: endTime,
      types: const [HealthDataType.STEPS],
    );
    final cleaned = _health.removeDuplicates(rawStepPoints);
    final Map<String, int> accumulator = {};

    for (final point in cleaned) {
      final value = point.value;
      if (value is! NumericHealthValue) continue;
      final steps = value.numericValue.round();
      if (steps <= 0) continue;

      final sourceKey = _resolveStepSourceKey(point);
      accumulator[sourceKey] = (accumulator[sourceKey] ?? 0) + steps;
    }

    if (accumulator.isEmpty) return const {};

    final entries = accumulator.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return LinkedHashMap.fromEntries(entries);
  }

  String _resolveStepSourceKey(HealthDataPoint point) {
    final deviceModel = point.deviceModel?.trim();
    if (deviceModel != null && deviceModel.isNotEmpty) return deviceModel;

    final sourceName = point.sourceName.trim();
    if (sourceName.isNotEmpty) return sourceName;

    final sourceId = point.sourceId.trim();
    if (sourceId.isNotEmpty) return sourceId;

    return point.uuid.isNotEmpty ? point.uuid : 'Unknown source';
  }

  String? _selectPrimaryStepsSource(Map<String, int> stepsBySource) {
    if (stepsBySource.isEmpty) return null;

    String? wearableCandidate;
    int wearableSteps = -1;
    String? fallback;
    int fallbackSteps = -1;

    stepsBySource.forEach((source, steps) {
      if (steps > fallbackSteps) {
        fallback = source;
        fallbackSteps = steps;
      }
      if (_looksLikeWearableSource(source) && steps >= wearableSteps) {
        wearableCandidate = source;
        wearableSteps = steps;
      }
    });

    return wearableCandidate ?? fallback;
  }

  bool _looksLikeWearableSource(String source) {
    final lower = source.toLowerCase();
    return lower.contains('watch') ||
        lower.contains('gear') ||
        lower.contains('wear') ||
        lower.contains('galaxy') ||
        lower.contains('fit') ||
        lower.contains('sm-r');
  }
}

class _RuntimePermissionResult {
  const _RuntimePermissionResult({
    required this.activityRecognitionGranted,
    required this.locationGranted,
  });

  final bool activityRecognitionGranted;
  final bool locationGranted;
}
