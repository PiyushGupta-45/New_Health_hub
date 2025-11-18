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
class HealthSyncController extends ChangeNotifier {
  HealthSyncController({HealthSyncService? service, DirectStepService? directStepService})
    : _service = service,
      _directStepService = directStepService ?? DirectStepService() {
    // Start listening to step updates when controller is created
    _initializeStepListener();
  }

  final HealthSyncService? _service;
  final DirectStepService _directStepService;
  final StepsSyncService _stepsSyncService = StepsSyncService();
  
  DateTime? _lastSyncedToBackend;
  static const Duration _syncInterval = Duration(minutes: 5); // Sync every 5 minutes
  bool _hydratedFromBackend = false;
  bool _hydratingFromBackend = false;

  void _initializeStepListener() {
    // Start listening to step counter for real-time updates
    _directStepService.startListening().listen((cumulativeSteps) {
      // Update snapshot if we have one and baseline is set
      if (_snapshot != null && _directStepService.baselineStepCount != null) {
        final todaySteps = cumulativeSteps - _directStepService.baselineStepCount!;
        if (todaySteps > 0) {
          final now = DateTime.now();
          _snapshot = HealthSyncSnapshot(
            todaySteps: todaySteps,
            workouts: _snapshot!.workouts,
            rangeStart: _snapshot!.rangeStart,
            rangeEnd: now,
            locationPermissionGranted: _snapshot!.locationPermissionGranted,
            stepsBySource: {'Phone Sensor': todaySteps},
            primaryStepsSource: 'Phone Sensor',
          );
          notifyListeners();
          
          // Auto-sync to backend (throttled)
          _syncStepsToBackend(todaySteps);
        }
      }
    });
  }

  Future<void> hydrateFromBackend() async {
    if (_hydratedFromBackend || _hydratingFromBackend) return;
    _hydratingFromBackend = true;
    try {
      final token = await _stepsSyncService.getAuthToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final result = await _stepsSyncService.getTodaySteps();
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final steps = (data['steps'] is num) ? (data['steps'] as num).toInt() : 0;
        final source = data['source']?.toString() ?? 'Cloud Sync';
        final dateString = data['date']?.toString();
        final dataDate = dateString != null ? DateTime.tryParse(dateString) : null;
        final now = DateTime.now();
        final referenceDate = dataDate ?? now;
        final rangeStart = referenceDate.subtract(const Duration(days: 7));

        if (_snapshot == null || steps > (_snapshot?.todaySteps ?? 0)) {
          _snapshot = HealthSyncSnapshot(
            todaySteps: steps,
            workouts: _snapshot?.workouts ?? const [],
            rangeStart: rangeStart,
            rangeEnd: referenceDate,
            locationPermissionGranted: _snapshot?.locationPermissionGranted ?? false,
            stepsBySource: {
              'Cloud Sync': steps,
            },
            primaryStepsSource: source,
          );
          _status = HealthSyncStatus.ready;
          _lastSyncedAt = referenceDate;
          notifyListeners();
        }

        await _alignSensorBaselineWithServer(steps);
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
    if (steps <= 0) return;
    final currentCount = await _directStepService.getCurrentStepCount();
    if (currentCount == null || currentCount <= 0) return;
    final targetBaseline = currentCount - steps;
    if (targetBaseline < 0) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await _directStepService.setBaseline(targetBaseline, today);
  }

  // Sync steps to backend (throttled to avoid too many requests)
  Future<void> _syncStepsToBackend(int steps) async {
    // Check if user is authenticated first
    final token = await _stepsSyncService.getAuthToken();
    if (token == null || token.isEmpty) {
      // User not authenticated, skip sync
      if (kDebugMode) {
        print('⚠️ Skipping steps sync - user not authenticated');
      }
      return;
    }

    // Only sync if enough time has passed since last sync
    if (_lastSyncedToBackend != null &&
        DateTime.now().difference(_lastSyncedToBackend!) < _syncInterval) {
      return;
    }

    try {
      final result = await _stepsSyncService.storeSteps(
        steps: steps,
        source: _snapshot?.primaryStepsSource ?? 'Phone Sensor',
      );
      
      if (result['success'] == true) {
        _lastSyncedToBackend = DateTime.now();
        if (kDebugMode) {
          print('✅ Steps synced to backend: $steps');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Failed to sync steps: ${result['error']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error syncing steps: $e');
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

  /// Requests the latest data from the step sensor (or Health Connect if available).
  Future<void> sync({bool force = false}) async {
    if (isSyncing) return;
    if (!force &&
        _snapshot != null &&
        _status == HealthSyncStatus.ready &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!).inMinutes < 5) {
      // Avoid hammering the API if data was synced very recently.
      return;
    }

    _status = HealthSyncStatus.syncing;
    _errorMessage = null;
    _lastError = null;
    notifyListeners();

    try {
      // Try direct step sensor first (no Health Connect required)
      if (Platform.isAndroid) {
        final isAvailable = await _directStepService.isStepCounterAvailable();
        if (isAvailable) {
          final todaySteps = await _directStepService.getTodaySteps();
          final now = DateTime.now();
          final rangeStart = now.subtract(const Duration(days: 7));
          
          // Create snapshot with steps from direct sensor
          _snapshot = HealthSyncSnapshot(
            todaySteps: todaySteps,
            workouts: const [], // No workout data without Health Connect
            rangeStart: rangeStart,
            rangeEnd: now,
            locationPermissionGranted: false,
            stepsBySource: {'Phone Sensor': todaySteps},
            primaryStepsSource: 'Phone Sensor',
          );
          _lastSyncedAt = DateTime.now();
          _status = HealthSyncStatus.ready;
          notifyListeners();
          
          // Sync to backend
          _syncStepsToBackend(todaySteps);
          return;
        }
      }

      // Fallback to Health Connect if available and service is provided
      if (_service != null) {
        final result = await _service!.sync();
        _snapshot = result;
        _lastSyncedAt = DateTime.now();
        _status = HealthSyncStatus.ready;
        
        // Sync to backend
        _syncStepsToBackend(result.todaySteps);
      } else {
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
    notifyListeners();
  }

  /// Resets the step baseline to start counting from now.
  /// This will set the baseline to the current step count, so only
  /// new steps taken after this will be counted.
  Future<void> resetStepBaseline() async {
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
    _directStepService.dispose();
    super.dispose();
  }
}
