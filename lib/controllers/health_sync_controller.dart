import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/direct_step_service.dart';
import '../services/health_sync_service.dart';
import '../services/steps_sync_service.dart';

/// High-level status for sync actions so that the UI can react accordingly.
enum HealthSyncStatus {
  idle,
  syncing,
  ready,
  permissionsRequired,
  healthConnectUnavailable,
  platformNotSupported,
  error,
}

/// A controller that orchestrates syncing health data and exposes the latest
/// snapshot to the UI.
class HealthSyncController extends ChangeNotifier {
  HealthSyncController({
    HealthSyncService? service,
    DirectStepService? directStepService,
  }) : _service = service,
       _directStepService = directStepService ?? DirectStepService() {
    // Start listening to step updates when controller is created
    _initializeStepListener();
    // Start periodic backend sync every 1 minute
    _startPeriodicBackendSync();
  }

  final HealthSyncService? _service;
  final DirectStepService _directStepService;
  final StepsSyncService _stepsSyncService = StepsSyncService();
  StreamSubscription<int>? _stepSubscription;

  // Track the date for which the current baseline applies.
  DateTime? _lastListenerDay;

  DateTime? _lastSyncedToBackend;
  static const Duration _syncInterval = Duration(
    minutes: 1,
  ); // Sync every 1 minute
  Timer? _periodicSyncTimer;
  Timer? _periodicStepCheckTimer;
  bool _hydratedFromBackend = false;
  bool _hydratingFromBackend = false;
  bool _isSyncingFromSensor = false;
  DateTime? _lastBaselineAlignment;
  int? _lastCumulativeSteps;
  int _displayBaselineSteps = 0;
  int? _displayBaselineCumulative;
  int? _lastSyncedSteps;
  DateTime? _lastBackendSyncAttemptAt;
  DateTime? _lastBackendSyncSuccessAt;
  int? _lastBackendSyncAttemptSteps;
  String? _lastBackendSyncResult;

  int _resolveDisplaySteps({
    required int sensorTodaySteps,
    int? cumulativeSteps,
  }) {
    if (_displayBaselineSteps <= 0) return sensorTodaySteps;

    var resolved = sensorTodaySteps < _displayBaselineSteps
        ? _displayBaselineSteps
        : sensorTodaySteps;

    if (cumulativeSteps != null && _displayBaselineCumulative != null) {
      final delta = cumulativeSteps - _displayBaselineCumulative!;
      if (delta > 0) {
        final baselinePlusDelta = _displayBaselineSteps + delta;
        if (baselinePlusDelta > resolved) {
          resolved = baselinePlusDelta;
        }
      }
    }

    return resolved;
  }

  Future<int> _resolveSensorStepsForBackend(int fallbackSteps) async {
    if (!Platform.isAndroid) {
      return fallbackSteps;
    }

    final uiSteps = _snapshot?.todaySteps;
    if (uiSteps != null && uiSteps >= 0) {
      return uiSteps;
    }

    final todaySteps = await _directStepService.getTodaySteps();
    if (todaySteps >= 0) {
      return todaySteps;
    }

    final cachedToday = _directStepService.lastReturnedTodaySteps;
    if (cachedToday != null && cachedToday >= 0) {
      return cachedToday;
    }

    return fallbackSteps;
  }

  Future<void> _syncSensorStepsToBackend({
    required int fallbackSteps,
    bool force = false,
  }) async {
    final todaySteps = await _resolveSensorStepsForBackend(fallbackSteps);
    await _syncStepsToBackend(todaySteps, force: force);
  }

  void _triggerBackendSyncForLiveSteps(int fallbackSteps) {
    Future<void>(() async {
      try {
        await _syncSensorStepsToBackend(fallbackSteps: fallbackSteps);
      } catch (e) {
        _lastBackendSyncResult = 'error: $e';
        if (kDebugMode) {
          print('WARN: Live step backend sync failed: $e');
        }
      }
    });
  }

  void _startPeriodicBackendSync() {
    // Sync to backend every 1 minute.
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) async {
      if (_snapshot == null) return;

      try {
        final steps = _snapshot!.todaySteps;
        await _syncSensorStepsToBackend(fallbackSteps: steps, force: true);
      } catch (e) {
        _lastBackendSyncResult = 'error: $e';
        if (kDebugMode) {
          print('⚠️ Periodic 1-minute backend sync failed: $e');
        }
      }
    });

    // Also periodically check step sensor directly in case stream isn't updating
    _periodicStepCheckTimer?.cancel();
    _periodicStepCheckTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      if (_isSyncingFromSensor || _hydratingFromBackend) return;

      try {
        if (Platform.isAndroid) {
          final isAvailable = await _directStepService.isStepCounterAvailable();
          if (isAvailable) {
            final latestCumulative = await _directStepService
                .getCurrentStepCount();
            var cumulativeChanged = false;
            if (latestCumulative != null &&
                latestCumulative > 0 &&
                latestCumulative != _lastCumulativeSteps) {
              _lastCumulativeSteps = latestCumulative;
              cumulativeChanged = true;
            }

            // Always query today's steps. Some devices can keep this updated
            // via native/background service even if cumulative callback is stale.
            final todaySteps = await _directStepService.getTodaySteps();
            if (todaySteps >= 0) {
              final displaySteps = _resolveDisplaySteps(
                sensorTodaySteps: todaySteps,
                cumulativeSteps: latestCumulative,
              );
              final currentSteps = _snapshot?.todaySteps ?? 0;
              if (_snapshot == null || displaySteps != currentSteps) {
                final now = DateTime.now();
                _snapshot = HealthSyncSnapshot(
                  todaySteps: displaySteps,
                  workouts: _snapshot?.workouts ?? const [],
                  rangeStart:
                      _snapshot?.rangeStart ??
                      now.subtract(const Duration(days: 7)),
                  rangeEnd: now,
                  locationPermissionGranted:
                      _snapshot?.locationPermissionGranted ?? false,
                  stepsBySource: {
                    'Phone Sensor': displaySteps,
                    if (_snapshot?.stepsBySource['Cloud Sync'] != null)
                      'Cloud Sync': _snapshot!.stepsBySource['Cloud Sync']!,
                  },
                  primaryStepsSource: 'Phone Sensor',
                );
                _status = HealthSyncStatus.ready;
                notifyListeners();
                _triggerBackendSyncForLiveSteps(displaySteps);
                if (kDebugMode) {
                  print('Periodic check: Steps updated to $displaySteps');
                }
              } else if (cumulativeChanged) {
                notifyListeners();
                if (kDebugMode) {
                  print(
                    'Periodic check: Cumulative updated to $latestCumulative',
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Periodic step check failed: $e');
        }
      }
    });
  }

  void _initializeStepListener() {
    // Start listening to step counter for real-time updates.
    // Ensure Activity Recognition permission is granted before registering
    // for sensor updates, otherwise some devices won't emit events.
    // If day changes we reset the sensor baseline to the current cumulative value
    // so today's steps start from 0.
    Future<void>(() async {
      if (!Platform.isAndroid) return;

      try {
        var permissionStatus = await Permission.activityRecognition.status;
        if (!permissionStatus.isGranted) {
          permissionStatus = await Permission.activityRecognition.request();
        }
        if (!permissionStatus.isGranted) {
          _status = HealthSyncStatus.permissionsRequired;
          notifyListeners();
          if (kDebugMode) {
            print(
              '⚠️ Activity recognition permission not granted; step listener not started.',
            );
          }
          return;
        }

        // Warm up baseline so stream updates can be interpreted immediately.
        try {
          await _directStepService.getTodaySteps();
        } catch (_) {
          // Ignore; sensor may be unavailable or temporarily not ready.
        }

        await _stepSubscription?.cancel();
        _stepSubscription = _directStepService.startListening().listen((
          cumulativeSteps,
        ) async {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // Initialize _lastListenerDay on first event
          _lastListenerDay ??= today;

          // If day rolled over, set new baseline so today's steps start at 0
          if (today.isAfter(_lastListenerDay!)) {
            try {
              await _directStepService.setBaseline(cumulativeSteps, today);
              _lastListenerDay = today;

              // Reset snapshot's todaySteps to 0 and update rangeStart/rangeEnd
              _snapshot = HealthSyncSnapshot(
                todaySteps: 0,
                workouts: _snapshot?.workouts ?? const [],
                rangeStart: today.subtract(const Duration(days: 7)),
                rangeEnd: now,
                locationPermissionGranted:
                    _snapshot?.locationPermissionGranted ?? false,
                stepsBySource: {'Phone Sensor': 0},
                primaryStepsSource: 'Phone Sensor',
              );
              _displayBaselineSteps = 0;
              _displayBaselineCumulative = null;
              notifyListeners();
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Failed to reset baseline on day rollover: $e');
              }
            }
            return; // skip further processing for this event
          }

          // Don't update from sensor if we're currently syncing (but allow during hydration after a delay)
          if (_isSyncingFromSensor) {
            return;
          }

          // Wait a brief moment after baseline alignment to let sensor stabilize
          if (_lastBaselineAlignment != null) {
            final timeSinceAlignment = DateTime.now().difference(
              _lastBaselineAlignment!,
            );
            if (timeSinceAlignment < const Duration(milliseconds: 1000)) {
              // Still allow updates if sensor is increasing (cumulative steps are increasing)
              // This ensures we don't block legitimate step increases
              final lastCumulative = _directStepService.baselineStepCount ?? 0;
              if (cumulativeSteps <= lastCumulative) {
                return; // Sensor hasn't increased, wait for alignment to complete
              }
            }
          }

          // Normal per-event update using current baseline
          // Initialize baseline if needed
          if (_directStepService.baselineStepCount == null ||
              _directStepService.baselineStepCount! <= 0) {
            try {
              // This will set the baseline if it doesn't exist
              if (cumulativeSteps > 0) {
                await _directStepService.setBaseline(cumulativeSteps, today);
                if (kDebugMode) {
                  print('Initialized baseline: $cumulativeSteps');
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('Failed to initialize baseline: $e');
              }
            }
          }

          // Track last cumulative steps for comparison
          _lastCumulativeSteps = cumulativeSteps;

          final todaySteps = await _directStepService.getTodaySteps();
          if (todaySteps >= 0) {
            final displaySteps = _resolveDisplaySteps(
              sensorTodaySteps: todaySteps,
              cumulativeSteps: cumulativeSteps,
            );
            final now = DateTime.now();
            final currentSteps = _snapshot?.todaySteps ?? 0;
            if (_snapshot == null || displaySteps != currentSteps) {
              if (kDebugMode) {
                print('Steps updated:  ->  (cumulative=)');
              }
              _snapshot = HealthSyncSnapshot(
                todaySteps: displaySteps,
                workouts: _snapshot?.workouts ?? const [],
                rangeStart:
                    _snapshot?.rangeStart ??
                    now.subtract(const Duration(days: 7)),
                rangeEnd: now,
                locationPermissionGranted:
                    _snapshot?.locationPermissionGranted ?? false,
                stepsBySource: {
                  'Phone Sensor': displaySteps,
                  if (_snapshot?.stepsBySource['Cloud Sync'] != null)
                    'Cloud Sync': _snapshot!.stepsBySource['Cloud Sync']!,
                },
                primaryStepsSource: 'Phone Sensor',
              );
              _status = HealthSyncStatus.ready;
              notifyListeners();
              _triggerBackendSyncForLiveSteps(displaySteps);
            }
          }
        });
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to start step listener: $e');
        }
      }
    });
  }

  Future<void> hydrateFromBackend({bool force = false}) async {
    if ((_hydratedFromBackend && !force) || _hydratingFromBackend) return;
    _hydratingFromBackend = true;
    try {
      final token = await _stepsSyncService.getAuthToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final result = await _stepsSyncService.getTodaySteps();
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final steps = (data['steps'] is num)
            ? (data['steps'] as num).toInt()
            : 0;
        final source = data['source']?.toString() ?? 'Cloud Sync';
        final dateString = data['date']?.toString();
        final dataDate = dateString != null
            ? DateTime.tryParse(dateString)
            : null;
        final now = DateTime.now();
        final referenceDate = dataDate ?? now;
        final rangeStart = referenceDate.subtract(const Duration(days: 7));

        // Align sensor baseline with server data first
        await _alignSensorBaselineWithServer(steps);

        // After aligning baseline, get steps from sensor (not server) for display
        if (Platform.isAndroid) {
          try {
            final isAvailable = await _directStepService
                .isStepCounterAvailable();
            if (isAvailable) {
              int? sensorSteps;
              final currentCount = await _directStepService
                  .getCurrentStepCount();
              final baseline = _directStepService.baselineStepCount;
              if (currentCount != null &&
                  currentCount > 0 &&
                  baseline != null &&
                  baseline >= 0) {
                sensorSteps = currentCount - baseline;
              } else {
                sensorSteps = await _directStepService.getTodaySteps();
              }

              if (sensorSteps >= 0) {
                _displayBaselineSteps = steps > 0 ? steps : 0;
                _displayBaselineCumulative = currentCount;
                final displaySteps = _resolveDisplaySteps(
                  sensorTodaySteps: sensorSteps,
                  cumulativeSteps: currentCount,
                );
                final primarySource = 'Phone Sensor';

                _snapshot = HealthSyncSnapshot(
                  todaySteps: displaySteps,
                  workouts: _snapshot?.workouts ?? const [],
                  rangeStart: rangeStart,
                  rangeEnd: referenceDate,
                  locationPermissionGranted:
                      _snapshot?.locationPermissionGranted ?? false,
                  stepsBySource: {
                    'Phone Sensor': sensorSteps,
                    'Cloud Sync': steps,
                  },
                  primaryStepsSource: primarySource,
                );
                _status = HealthSyncStatus.ready;
                _lastSyncedAt = referenceDate;
                notifyListeners();

                if (kDebugMode) {
                  print(
                    'Hydrated: Sensor steps=$sensorSteps, Server steps=$steps (display=$displaySteps, baseline=$_displayBaselineSteps)',
                  );
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Failed to get sensor steps after hydration: $e');
            }
            // Fallback to server steps if sensor fails
            if (steps >= 0) {
              _displayBaselineSteps = steps;
              _displayBaselineCumulative = null;
              _snapshot = HealthSyncSnapshot(
                todaySteps: steps,
                workouts: _snapshot?.workouts ?? const [],
                rangeStart: rangeStart,
                rangeEnd: referenceDate,
                locationPermissionGranted:
                    _snapshot?.locationPermissionGranted ?? false,
                stepsBySource: {'Cloud Sync': steps},
                primaryStepsSource: source,
              );
              _status = HealthSyncStatus.ready;
              _lastSyncedAt = referenceDate;
              notifyListeners();
            }
          }
        } else {
          // Non-Android: use server steps as fallback
          if (steps >= 0) {
            _displayBaselineSteps = steps;
            _displayBaselineCumulative = null;
            _snapshot = HealthSyncSnapshot(
              todaySteps: steps,
              workouts: _snapshot?.workouts ?? const [],
              rangeStart: rangeStart,
              rangeEnd: referenceDate,
              locationPermissionGranted:
                  _snapshot?.locationPermissionGranted ?? false,
              stepsBySource: {'Cloud Sync': steps},
              primaryStepsSource: source,
            );
            _status = HealthSyncStatus.ready;
            _lastSyncedAt = referenceDate;
            notifyListeners();
          }
        }

        _hydratedFromBackend = true;
      } else {
        final error = result['error']?.toString().toLowerCase() ?? '';
        if (error.contains('auth') ||
            error.contains('token') ||
            error.contains('unauthorized')) {
          _hydratedFromBackend = true; // avoid repeated unauthorized calls
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to hydrate steps from backend: $e');
      }
    } finally {
      _hydratingFromBackend = false;
    }
  }

  Future<void> _alignSensorBaselineWithServer(int steps) async {
    if (steps < 0) return;

    try {
      final currentCount = await _directStepService.getCurrentStepCount();
      if (currentCount == null || currentCount <= 0) {
        // If sensor isn't ready, don't align yet
        if (kDebugMode) {
          print(
            '⚠️ Sensor not ready for baseline alignment (currentCount=$currentCount)',
          );
        }
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get current baseline to check if we need to update
      final currentBaseline = _directStepService.baselineStepCount ?? 0;

      // Calculate target baseline: current cumulative count minus steps from server
      final targetBaseline = currentCount - steps;

      // Only set baseline if it makes sense (targetBaseline should be >= 0 and <= currentCount)
      // Also only update if it's different from current baseline to avoid unnecessary updates
      if (targetBaseline >= 0 &&
          targetBaseline <= currentCount &&
          targetBaseline != currentBaseline) {
        await _directStepService.setBaseline(targetBaseline, today);
        _lastBaselineAlignment = DateTime.now();
        if (kDebugMode) {
          print(
            '✅ Aligned sensor baseline: currentCount=$currentCount, serverSteps=$steps, baseline=$targetBaseline (was $currentBaseline)',
          );
        }
      } else if (targetBaseline < 0 || targetBaseline > currentCount) {
        // If calculation doesn't make sense (server has more steps than sensor can account for),
        // set baseline to current count so sensor can start tracking from now
        // This preserves server steps but allows sensor to continue tracking
        if (currentBaseline != currentCount) {
          await _directStepService.setBaseline(currentCount, today);
          _lastBaselineAlignment = DateTime.now();
          if (kDebugMode) {
            print(
              '⚠️ Baseline alignment: serverSteps ($steps) > sensor can account for. Setting baseline to currentCount ($currentCount) to continue tracking.',
            );
          }
        }
      } else {
        if (kDebugMode) {
          print(
            'ℹ️ Baseline already aligned: currentCount=$currentCount, serverSteps=$steps, baseline=$currentBaseline',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to align sensor baseline: $e');
      }
    }
  }

  // Sync steps to backend (throttled to avoid too many requests)
  Future<void> _syncStepsToBackend(int steps, {bool force = false}) async {
    _lastBackendSyncAttemptAt = DateTime.now();
    _lastBackendSyncAttemptSteps = steps;

    if (steps <= 0) {
      _lastBackendSyncResult = 'skipped: steps <= 0';
      if (kDebugMode) {
        print('Skipping steps sync - invalid steps count: $steps');
      }
      return;
    }

    if (!force && _lastSyncedSteps != null && steps <= _lastSyncedSteps!) {
      _lastBackendSyncResult =
          'skipped: not increased (last=$_lastSyncedSteps)';
      return;
    }

    final token = await _stepsSyncService.getAuthToken();
    if (token == null || token.isEmpty) {
      _lastBackendSyncResult = 'skipped: no auth token';
      if (kDebugMode) {
        print('Skipping steps sync - user not authenticated');
      }
      return;
    }

    if (!force &&
        _lastSyncedToBackend != null &&
        DateTime.now().difference(_lastSyncedToBackend!) < _syncInterval) {
      _lastBackendSyncResult = 'skipped: throttled < 1 min';
      return;
    }

    try {
      final result = await _stepsSyncService.storeSteps(
        steps: steps,
        source: _snapshot?.primaryStepsSource ?? 'Phone Sensor',
      );

      if (result['success'] == true) {
        _lastSyncedToBackend = DateTime.now();
        _lastSyncedSteps = steps;
        _lastBackendSyncSuccessAt = _lastSyncedToBackend;
        _lastBackendSyncResult = 'success';
        if (kDebugMode) {
          print('Steps synced to backend: $steps');
        }
      } else {
        _lastBackendSyncResult = 'failed: ${result['error']}';
        if (kDebugMode) {
          print('Failed to sync steps: ${result['error']}');
        }
      }
    } catch (e) {
      _lastBackendSyncResult = 'error: $e';
      if (kDebugMode) {
        print('Error syncing steps: $e');
      }
    }
  }

  HealthSyncStatus _status = HealthSyncStatus.idle;
  HealthSyncSnapshot? _snapshot;
  DateTime? _lastSyncedAt;
  String? _errorMessage;
  Object? _lastError;

  HealthSyncSnapshot? get snapshot => _snapshot;
  HealthSyncStatus get status => _status;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get errorMessage => _errorMessage;
  Object? get lastError => _lastError;

  bool get isSyncing => _status == HealthSyncStatus.syncing;

  /// Convenience getter for the latest step count.
  int get todaySteps => _snapshot?.todaySteps ?? 0;
  Map<String, int> get stepsBySource =>
      _snapshot?.stepsBySource ?? const <String, int>{};
  String? get primaryStepsSource => _snapshot?.primaryStepsSource;
  bool get locationPermissionGranted =>
      _snapshot?.locationPermissionGranted ?? false;
  int? get debugSensorCumulative =>
      _directStepService.lastKnownCurrentStepCount;
  int? get debugNativeTodaySteps => _directStepService.lastNativeTodaySteps;
  int? get debugComputedTodaySteps => _directStepService.lastComputedTodaySteps;
  int? get debugReturnedTodaySteps => _directStepService.lastReturnedTodaySteps;
  int? get debugBaseline => _directStepService.baselineStepCount;
  int? get debugLastSyncedSteps => _lastSyncedSteps;
  DateTime? get debugLastBackendSyncAttemptAt => _lastBackendSyncAttemptAt;
  DateTime? get debugLastBackendSyncSuccessAt => _lastBackendSyncSuccessAt;
  int? get debugLastBackendSyncAttemptSteps => _lastBackendSyncAttemptSteps;
  String? get debugLastBackendSyncResult => _lastBackendSyncResult;
  int get displayBaselineSteps => _displayBaselineSteps;

  /// Requests the latest data from the step sensor (or Health Connect if available).
  Future<void> sync({bool force = false}) async {
    if (isSyncing && !force) return;
    if (!force &&
        _snapshot != null &&
        _status == HealthSyncStatus.ready &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!).inMinutes < 1) {
      // Avoid hammering the API if data was synced very recently (1 minute now).
      return;
    }

    _status = HealthSyncStatus.syncing;
    _errorMessage = null;
    _lastError = null;
    _isSyncingFromSensor = true;
    notifyListeners();

    try {
      // Try direct step sensor first (no Health Connect required)
      if (Platform.isAndroid) {
        final isAvailable = await _directStepService.isStepCounterAvailable();
        if (isAvailable) {
          final todaySteps = await _directStepService.getTodaySteps();
          final currentCumulative = await _directStepService
              .getCurrentStepCount();
          final now = DateTime.now();
          final rangeStart = now.subtract(const Duration(days: 7));

          // Update whenever sensor daily steps changed, including day rollover decreases.
          final currentSteps = _snapshot?.todaySteps ?? 0;
          final displaySteps = _resolveDisplaySteps(
            sensorTodaySteps: todaySteps,
            cumulativeSteps: currentCumulative,
          );
          if (_snapshot == null || displaySteps != currentSteps) {
            _snapshot = HealthSyncSnapshot(
              todaySteps: displaySteps,
              workouts: const [], // No workout data without Health Connect
              rangeStart: rangeStart,
              rangeEnd: now,
              locationPermissionGranted: false,
              stepsBySource: {'Phone Sensor': displaySteps},
              primaryStepsSource: 'Phone Sensor',
            );
            _lastSyncedAt = DateTime.now();
            _status = HealthSyncStatus.ready;
            notifyListeners();

            // Sync to backend (force if this is a manual sync)
            await _syncSensorStepsToBackend(
              fallbackSteps: displaySteps,
              force: force,
            );
          } else {
            // Keep current snapshot if sensor shows less
            _status = HealthSyncStatus.ready;
            notifyListeners();
            await _syncSensorStepsToBackend(
              fallbackSteps: displaySteps,
              force: force,
            );
          }
          return;
        }
      }

      // Fallback to Health Connect if available and service is provided
      if (_service != null) {
        final result = await _service!.sync();
        _snapshot = result;
        _lastSyncedAt = DateTime.now();
        _status = HealthSyncStatus.ready;
        notifyListeners();

        // Sync to backend (force if this is a manual sync)
        await _syncStepsToBackend(result.todaySteps, force: force);
      } else {
        // If no sensor and no service, create empty snapshot so UI can display
        final now = DateTime.now();
        _snapshot = HealthSyncSnapshot(
          todaySteps: 0,
          workouts: const [],
          rangeStart: now.subtract(const Duration(days: 7)),
          rangeEnd: now,
          locationPermissionGranted: false,
          stepsBySource: const {},
        );
        _lastSyncedAt = DateTime.now();
        _status = HealthSyncStatus.ready;
        notifyListeners();

        throw const HealthSyncException(
          HealthSyncErrorType.platformNotSupported,
          'Step counter sensor not available and Health Connect service not provided.',
        );
      }
    } on HealthSyncException catch (error) {
      _handleSyncException(error);
    } on StepCounterException catch (error) {
      _status = HealthSyncStatus.error;
      _errorMessage = error.message;
      _lastError = error;
    } on UnsupportedError catch (error) {
      _status = HealthSyncStatus.healthConnectUnavailable;
      _errorMessage = error.message;
      _lastError = error;
    } catch (error) {
      _status = HealthSyncStatus.error;
      _errorMessage = error.toString();
      _lastError = error;
    } finally {
      _isSyncingFromSensor = false;
      notifyListeners();
    }
  }

  /// Clears the current error message.
  void clearError() {
    _errorMessage = null;
    if (_snapshot != null) {
      _status = HealthSyncStatus.ready;
    } else {
      _status = HealthSyncStatus.idle;
    }
    notifyListeners();
  }

  Future<void> openHealthConnectInstallPage() async {
    if (_service != null) {
      await _service!.openHealthConnectInstallPage();
    }
  }

  void _handleSyncException(HealthSyncException error) {
    _errorMessage = error.message;
    _lastError = error;
    switch (error.type) {
      case HealthSyncErrorType.permissionsDenied:
        _status = HealthSyncStatus.permissionsRequired;
        break;
      case HealthSyncErrorType.healthConnectUnavailable:
        _status = HealthSyncStatus.healthConnectUnavailable;
        break;
      case HealthSyncErrorType.platformNotSupported:
        _status = HealthSyncStatus.platformNotSupported;
        break;
      case HealthSyncErrorType.unknown:
        _status = HealthSyncStatus.error;
        break;
    }
  }

  /// Clears cached data and forces a fresh sync.
  void clearCache() {
    _snapshot = null;
    _lastSyncedAt = null;
    _status = HealthSyncStatus.idle;
    _errorMessage = null;
    _lastError = null;
    _hydratedFromBackend = false;
    _lastBaselineAlignment = null;
    _displayBaselineSteps = 0;
    _displayBaselineCumulative = null;
    _lastSyncedSteps = null;
    _lastBackendSyncAttemptAt = null;
    _lastBackendSyncSuccessAt = null;
    _lastBackendSyncAttemptSteps = null;
    _lastBackendSyncResult = null;
    notifyListeners();
  }

  /// Resets the step baseline to start counting from now.
  /// This will set the baseline to the current step count, so only
  /// new steps taken after this will be counted.
  Future<void> resetStepBaseline() async {
    _displayBaselineSteps = 0;
    _displayBaselineCumulative = null;
    // First get current count to set as baseline
    final currentCount = await _directStepService.getCurrentStepCount();
    if (currentCount != null && currentCount > 0) {
      await _directStepService.resetBaselineToNow();
      // Force a sync to update the display (should show 0 after reset)
      await sync(force: true);
    } else {
      // If we can't get current count, clear baseline and let it reset on next sync
      await _directStepService.clearBaseline();
      await sync(force: true);
    }
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    _periodicStepCheckTimer?.cancel();
    _stepSubscription?.cancel();
    _directStepService.dispose();
    super.dispose();
  }
}
