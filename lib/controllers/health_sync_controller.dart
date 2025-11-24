import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
class HealthSyncController
    extends
        ChangeNotifier {
  HealthSyncController({
    HealthSyncService? service,
    DirectStepService? directStepService,
  }) : _service =
           service,
       _directStepService =
           directStepService ??
           DirectStepService() {
    // Start listening to step updates when controller is created
    _initializeStepListener();
    // Start periodic backend sync every 1 minute
    _startPeriodicBackendSync();
  }

  final HealthSyncService? _service;
  final DirectStepService _directStepService;
  final StepsSyncService _stepsSyncService = StepsSyncService();

  // Track the date for which the current baseline applies.
  DateTime? _lastListenerDay;

  DateTime? _lastSyncedToBackend;
  static const Duration _syncInterval = Duration(
    minutes: 1,
  ); // Sync every 1 minute
  Timer? _periodicSyncTimer;
  bool _hydratedFromBackend = false;
  bool _hydratingFromBackend = false;
  bool _isSyncingFromSensor = false;
  DateTime? _lastBaselineAlignment;

  void _startPeriodicBackendSync() {
    // Sync to backend every 1 minute regardless of step changes
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) async {
      if (_snapshot != null && _snapshot!.todaySteps >= 0) {
        await _syncStepsToBackend(_snapshot!.todaySteps, force: true);
      }
    });
  }

  void _initializeStepListener() {
    // Start listening to step counter for real-time updates.
    // If day changes we reset the sensor baseline to the current cumulative value
    // so today's steps start from 0.
    _directStepService.startListening().listen(
      (
        cumulativeSteps,
      ) async {
        final now = DateTime.now();
        final today = DateTime(
          now.year,
          now.month,
          now.day,
        );

        // Initialize _lastListenerDay on first event
        _lastListenerDay ??= today;

        // If day rolled over, set new baseline so today's steps start at 0
        if (today.isAfter(
          _lastListenerDay!,
        )) {
          try {
            await _directStepService.setBaseline(
              cumulativeSteps,
              today,
            );
            _lastListenerDay = today;

            // Reset snapshot's todaySteps to 0 and update rangeStart/rangeEnd
            _snapshot = HealthSyncSnapshot(
              todaySteps: 0,
              workouts:
                  _snapshot?.workouts ??
                  const [],
              rangeStart: today.subtract(
                const Duration(
                  days: 7,
                ),
              ),
              rangeEnd: now,
              locationPermissionGranted:
                  _snapshot?.locationPermissionGranted ??
                  false,
              stepsBySource: {
                'Phone Sensor': 0,
              },
              primaryStepsSource: 'Phone Sensor',
            );
            notifyListeners();
          } catch (
            e
          ) {
            if (kDebugMode) {
              print(
                '⚠️ Failed to reset baseline on day rollover: $e',
              );
            }
          }
          return; // skip further processing for this event
        }

        // Don't update from sensor if we're currently syncing or just hydrated from backend
        if (_isSyncingFromSensor || _hydratingFromBackend) {
          return;
        }
        
        // Wait a brief moment after baseline alignment to let sensor stabilize
        if (_lastBaselineAlignment != null) {
          final timeSinceAlignment = DateTime.now().difference(_lastBaselineAlignment!);
          if (timeSinceAlignment < const Duration(milliseconds: 500)) {
            return;
          }
        }

        // Normal per-event update using current baseline
        // Initialize baseline if needed
        if (_directStepService.baselineStepCount == null) {
          try {
            // This will set the baseline if it doesn't exist
            await _directStepService.setBaseline(cumulativeSteps, today);
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Failed to initialize baseline: $e');
            }
          }
        }

        if (_directStepService.baselineStepCount != null) {
          final baseline = _directStepService.baselineStepCount!;
          final todaySteps =
              cumulativeSteps -
              baseline;
          final now = DateTime.now();
          
          if (todaySteps < 0) {
            // Defensive: if sensor counter reset unexpectedly, set baseline to current cumulative
            try {
              await _directStepService.setBaseline(
                cumulativeSteps,
                today,
              );
              if (kDebugMode)
                print(
                  '🔁 Baseline adjusted because todaySteps < 0',
                );
              return;
            } catch (_) {}
          }

          // Only update if we have valid steps and they're greater than or equal to current
          // This prevents overwriting backend data with 0
          if (todaySteps >= 0) {
            final currentSteps = _snapshot?.todaySteps ?? 0;
            // Only update if sensor shows more steps, or if we don't have a snapshot yet
            if (todaySteps >= currentSteps || _snapshot == null) {
              _snapshot = HealthSyncSnapshot(
                todaySteps: todaySteps,
                workouts: _snapshot?.workouts ?? const [],
                rangeStart: _snapshot?.rangeStart ?? now.subtract(const Duration(days: 7)),
                rangeEnd: now,
                locationPermissionGranted: _snapshot?.locationPermissionGranted ?? false,
                stepsBySource: {
                  'Phone Sensor': todaySteps,
                },
                primaryStepsSource: 'Phone Sensor',
              );
              _status = HealthSyncStatus.ready;
              notifyListeners();

              // Auto-sync to backend (throttled)
              _syncStepsToBackend(
                todaySteps,
              );
            }
          }
        } else {
          // If we still don't have a baseline, create a snapshot with 0 steps only if we don't have one
          final now = DateTime.now();
          if (_snapshot == null) {
            _snapshot = HealthSyncSnapshot(
              todaySteps: 0,
              workouts: const [],
              rangeStart: now.subtract(const Duration(days: 7)),
              rangeEnd: now,
              locationPermissionGranted: false,
              stepsBySource: const {},
            );
            _status = HealthSyncStatus.ready;
            notifyListeners();
          }
        }
      },
    );
  }

  Future<
    void
  >
  hydrateFromBackend({bool force = false}) async {
    if ((_hydratedFromBackend && !force) ||
        _hydratingFromBackend)
      return;
    _hydratingFromBackend = true;
    try {
      final token = await _stepsSyncService.getAuthToken();
      if (token ==
              null ||
          token.isEmpty) {
        return;
      }

      final result = await _stepsSyncService.getTodaySteps();
      if (result['success'] ==
          true) {
        final data =
            result['data']
                as Map<
                  String,
                  dynamic
                >? ??
            {};
        final steps =
            (data['steps']
                is num)
            ? (data['steps']
                      as num)
                  .toInt()
            : 0;
        final source =
            data['source']?.toString() ??
            'Cloud Sync';
        final dateString = data['date']?.toString();
        final dataDate =
            dateString !=
                null
            ? DateTime.tryParse(
                dateString,
              )
            : null;
        final now = DateTime.now();
        final referenceDate =
            dataDate ??
            now;
        final rangeStart = referenceDate.subtract(
          const Duration(
            days: 7,
          ),
        );

        // Always update snapshot with backend data if it's available
        if (steps >= 0) {
          _snapshot = HealthSyncSnapshot(
            todaySteps: steps,
            workouts:
                _snapshot?.workouts ??
                const [],
            rangeStart: rangeStart,
            rangeEnd: referenceDate,
            locationPermissionGranted:
                _snapshot?.locationPermissionGranted ??
                false,
            stepsBySource: {
              'Cloud Sync': steps,
            },
            primaryStepsSource: source,
          );
          _status = HealthSyncStatus.ready;
          _lastSyncedAt = referenceDate;
          notifyListeners();
        }

        // Align sensor baseline with server data
        await _alignSensorBaselineWithServer(
          steps,
        );
        _hydratedFromBackend = true;
      } else {
        final error =
            result['error']?.toString().toLowerCase() ??
            '';
        if (error.contains(
              'auth',
            ) ||
            error.contains(
              'token',
            ) ||
            error.contains(
              'unauthorized',
            )) {
          _hydratedFromBackend = true; // avoid repeated unauthorized calls
        }
      }
    } catch (
      e
    ) {
      if (kDebugMode) {
        print(
          '⚠️ Failed to hydrate steps from backend: $e',
        );
      }
    } finally {
      _hydratingFromBackend = false;
    }
  }

  Future<
    void
  >
  _alignSensorBaselineWithServer(
    int steps,
  ) async {
    if (steps < 0) return;
    
    try {
      final currentCount = await _directStepService.getCurrentStepCount();
      if (currentCount == null || currentCount <= 0) {
        // If sensor isn't ready, don't align yet
        return;
      }
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Calculate target baseline: current cumulative count minus steps from server
      final targetBaseline = currentCount - steps;
      
      // Only set baseline if it makes sense (targetBaseline should be >= 0 and <= currentCount)
      if (targetBaseline >= 0 && targetBaseline <= currentCount) {
        await _directStepService.setBaseline(targetBaseline, today);
        _lastBaselineAlignment = DateTime.now();
        if (kDebugMode) {
          print('✅ Aligned sensor baseline: currentCount=$currentCount, steps=$steps, baseline=$targetBaseline');
        }
      } else {
        // If calculation doesn't make sense, set baseline to current count (start fresh)
        // This happens if server has more steps than sensor shows (e.g., sensor reset)
        await _directStepService.setBaseline(currentCount, today);
        _lastBaselineAlignment = DateTime.now();
        if (kDebugMode) {
          print('⚠️ Baseline alignment issue: currentCount=$currentCount, steps=$steps, setting baseline to currentCount');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to align sensor baseline: $e');
      }
    }
  }

  // Sync steps to backend (throttled to avoid too many requests)
  Future<
    void
  >
  _syncStepsToBackend(
    int steps, {
    bool force = false,
  }) async {
    // Check if user is authenticated first
    final token = await _stepsSyncService.getAuthToken();
    if (token ==
            null ||
        token.isEmpty) {
      // User not authenticated, skip sync
      if (kDebugMode) {
        print(
          '⚠️ Skipping steps sync - user not authenticated',
        );
      }
      return;
    }

    // Only sync if enough time has passed since last sync (unless forced)
    if (!force &&
        _lastSyncedToBackend !=
            null &&
        DateTime.now().difference(
              _lastSyncedToBackend!,
            ) <
            _syncInterval) {
      return;
    }

    try {
      final result = await _stepsSyncService.storeSteps(
        steps: steps,
        source:
            _snapshot?.primaryStepsSource ??
            'Phone Sensor',
      );

      if (result['success'] ==
          true) {
        _lastSyncedToBackend = DateTime.now();
        if (kDebugMode) {
          print(
            '✅ Steps synced to backend: $steps',
          );
        }
      } else {
        if (kDebugMode) {
          print(
            '⚠️ Failed to sync steps: ${result['error']}',
          );
        }
      }
    } catch (
      e
    ) {
      if (kDebugMode) {
        print(
          '⚠️ Error syncing steps: $e',
        );
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

  bool get isSyncing =>
      _status ==
      HealthSyncStatus.syncing;

  /// Convenience getter for the latest step count.
  int get todaySteps =>
      _snapshot?.todaySteps ??
      0;
  Map<
    String,
    int
  >
  get stepsBySource =>
      _snapshot?.stepsBySource ??
      const <
        String,
        int
      >{};
  String? get primaryStepsSource => _snapshot?.primaryStepsSource;
  bool get locationPermissionGranted =>
      _snapshot?.locationPermissionGranted ??
      false;

  /// Requests the latest data from the step sensor (or Health Connect if available).
  Future<
    void
  >
  sync({
    bool force = false,
  }) async {
    if (isSyncing && !force) return;
    if (!force &&
        _snapshot !=
            null &&
        _status ==
            HealthSyncStatus.ready &&
        _lastSyncedAt !=
            null &&
        DateTime.now()
                .difference(
                  _lastSyncedAt!,
                )
                .inMinutes <
            1) {
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
          final now = DateTime.now();
          final rangeStart = now.subtract(
            const Duration(
              days: 7,
            ),
          );

          // Only update if sensor shows valid steps (>= 0) and it's greater than or equal to current
          final currentSteps = _snapshot?.todaySteps ?? 0;
          if (todaySteps >= currentSteps || _snapshot == null) {
            _snapshot = HealthSyncSnapshot(
              todaySteps: todaySteps,
              workouts: const [], // No workout data without Health Connect
              rangeStart: rangeStart,
              rangeEnd: now,
              locationPermissionGranted: false,
              stepsBySource: {
                'Phone Sensor': todaySteps,
              },
              primaryStepsSource: 'Phone Sensor',
            );
            _lastSyncedAt = DateTime.now();
            _status = HealthSyncStatus.ready;
            notifyListeners();

            // Sync to backend (force if this is a manual sync)
            await _syncStepsToBackend(
              todaySteps,
              force: force,
            );
          } else {
            // Keep current snapshot if sensor shows less
            _status = HealthSyncStatus.ready;
            notifyListeners();
          }
          return;
        }
      }

      // Fallback to Health Connect if available and service is provided
      if (_service !=
          null) {
        final result = await _service!.sync();
        _snapshot = result;
        _lastSyncedAt = DateTime.now();
        _status = HealthSyncStatus.ready;
        notifyListeners();

        // Sync to backend (force if this is a manual sync)
        await _syncStepsToBackend(
          result.todaySteps,
          force: force,
        );
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
    } on HealthSyncException catch (
      error
    ) {
      _handleSyncException(
        error,
      );
    } on StepCounterException catch (
      error
    ) {
      _status = HealthSyncStatus.error;
      _errorMessage = error.message;
      _lastError = error;
    } on UnsupportedError catch (
      error
    ) {
      _status = HealthSyncStatus.healthConnectUnavailable;
      _errorMessage = error.message;
      _lastError = error;
    } catch (
      error
    ) {
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
    if (_snapshot !=
        null) {
      _status = HealthSyncStatus.ready;
    } else {
      _status = HealthSyncStatus.idle;
    }
    notifyListeners();
  }

  Future<
    void
  >
  openHealthConnectInstallPage() async {
    if (_service !=
        null) {
      await _service!.openHealthConnectInstallPage();
    }
  }

  void _handleSyncException(
    HealthSyncException error,
  ) {
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
    notifyListeners();
  }

  /// Resets the step baseline to start counting from now.
  /// This will set the baseline to the current step count, so only
  /// new steps taken after this will be counted.
  Future<
    void
  >
  resetStepBaseline() async {
    // First get current count to set as baseline
    final currentCount = await _directStepService.getCurrentStepCount();
    if (currentCount !=
            null &&
        currentCount >
            0) {
      await _directStepService.resetBaselineToNow();
      // Force a sync to update the display (should show 0 after reset)
      await sync(
        force: true,
      );
    } else {
      // If we can't get current count, clear baseline and let it reset on next sync
      await _directStepService.clearBaseline();
      await sync(
        force: true,
      );
    }
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    _directStepService.dispose();
    super.dispose();
  }
}
