import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service that provides direct access to step counter sensor
/// without requiring Health Connect or Samsung Health.
///
/// Uses Android's hardware Step Counter sensor (TYPE_STEP_COUNTER)
/// which provides cumulative steps since device boot.
class DirectStepService {
  DirectStepService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel = const MethodChannel(
    'com.example.health/step_counter',
  );

  StreamController<int>? _stepStreamController;
  Stream<int>? _stepStream;

  int? _lastStepCount;
  int? _baselineStepCount;
  DateTime? _baselineDate;

  bool _isListening = false;
  bool _baselineLoaded = false;
  int? _lastNativeTodaySteps;
  int? _lastComputedTodaySteps;
  int? _lastReturnedTodaySteps;
  int? _lastKnownCurrentStepCount;

  static const String _baselineCountKey = 'step_baseline_count';
  static const String _baselineDateKey = 'step_baseline_date';

  /// Checks if the step counter sensor is available on this device.
  Future<bool> isStepCounterAvailable() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'isStepCounterAvailable',
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Gets the current cumulative step count from the sensor.
  /// This is the total steps since device boot, not daily steps.
  Future<int?> getCurrentStepCount() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod<int>('getCurrentStepCount');
      _lastKnownCurrentStepCount = result;
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Loads the baseline from persistent storage.
  Future<void> _loadBaseline() async {
    if (_baselineLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCount = prefs.getInt(_baselineCountKey);
      final savedDateStr = prefs.getString(_baselineDateKey);

      if (savedCount != null && savedCount > 0 && savedDateStr != null) {
        try {
          _baselineDate = DateTime.parse(savedDateStr);
          _baselineStepCount = savedCount;
        } catch (e) {
          // Invalid date, ignore
        }
      }
      _baselineLoaded = true;
    } catch (e) {
      // If loading fails, continue without baseline
      _baselineLoaded = true;
    }
  }

  /// Saves the baseline to persistent storage.
  Future<void> _saveBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_baselineStepCount != null && _baselineDate != null) {
        await prefs.setInt(_baselineCountKey, _baselineStepCount!);
        await prefs.setString(
          _baselineDateKey,
          _baselineDate!.toIso8601String(),
        );
      }
    } catch (e) {
      // If saving fails, continue without persistence
    }
  }

  /// Gets today's step count by calculating the difference
  /// from a stored baseline (steps at start of day).
  ///
  /// If no baseline exists, it will be set automatically.
  Future<int> getTodaySteps() async {
    if (!Platform.isAndroid) {
      return 0;
    }

    // Try native background-calculated daily steps first so day rollover works
    // even when the app was not opened at midnight.
    int? nativeToday;
    try {
      nativeToday = await _channel.invokeMethod<int>('getTodayStepCount');
      _lastNativeTodaySteps = nativeToday;
    } catch (_) {
      // Fallback to baseline-based computation below.
    }

    // Load baseline from storage first
    await _loadBaseline();

    // Request permission first
    final permissionStatus = await Permission.activityRecognition.request();
    if (!permissionStatus.isGranted) {
      throw StepCounterException(
        'Activity recognition permission is required to read step counts.',
      );
    }

    // Get current count - wait a bit for sensor to initialize if needed
    int? currentCount = await getCurrentStepCount();

    // If we got 0 or null, wait a bit and try again (sensor might need time)
    if (currentCount == null || currentCount == 0) {
      await Future.delayed(const Duration(milliseconds: 300));
      currentCount = await getCurrentStepCount();
    }

    if (currentCount == null || currentCount == 0) {
      // Sensor might not be ready yet, return 0 for now
      // If native provided a valid value (including 0), prefer it.
      if (nativeToday != null && nativeToday >= 0) {
        _lastComputedTodaySteps = 0;
        _lastReturnedTodaySteps = nativeToday;
        return nativeToday;
      }
      _lastComputedTodaySteps = 0;
      _lastReturnedTodaySteps = 0;
      return 0;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if we need to reset baseline (new day or first time)
    if (_baselineDate == null || _baselineDate!.isBefore(today)) {
      // Store baseline for today - this is the cumulative count at start of day
      // If device was booted before today, this will be high, but that's okay
      // because we'll track steps from this point forward
      _baselineStepCount = currentCount;
      _baselineDate = today;
      _lastStepCount = currentCount;
      await _saveBaseline(); // Persist the baseline
      // Start at 0 from the current baseline unless native already has a known
      // positive value for today (for example from background tracking).
      if (nativeToday != null && nativeToday >= 0) {
        _lastComputedTodaySteps = 0;
        _lastReturnedTodaySteps = nativeToday > 0 ? nativeToday : 0;
        return _lastReturnedTodaySteps!;
      }
      _lastComputedTodaySteps = 0;
      _lastReturnedTodaySteps = 0;
      return 0;
    }

    // Calculate today's steps from baseline
    if (_baselineStepCount != null && _baselineStepCount! > 0) {
      final todaySteps = currentCount - _baselineStepCount!;
      _lastStepCount = currentCount;
      final computed = todaySteps > 0 ? todaySteps : 0;
      _lastComputedTodaySteps = computed;
      // Primary source should be computed sensor delta from current baseline.
      // Native value is kept only as fallback when computed path is unavailable.
      _lastReturnedTodaySteps = computed;
      return computed;
    }

    // Fallback: if baseline is null or 0, set it to current count
    // This handles the case where baseline wasn't loaded properly
    _baselineStepCount = currentCount;
    _baselineDate = today;
    _lastStepCount = currentCount;
    await _saveBaseline();
    if (nativeToday != null && nativeToday >= 0) {
      _lastComputedTodaySteps = 0;
      _lastReturnedTodaySteps = nativeToday;
      return nativeToday;
    }
    _lastComputedTodaySteps = 0;
    _lastReturnedTodaySteps = 0;
    return 0;
  }

  /// Sets a custom baseline step count for today.
  /// Useful if you want to sync with another source or handle edge cases.
  Future<void> setBaseline(int baselineCount, DateTime date) async {
    _baselineStepCount = baselineCount;
    _baselineDate = date;
    await _saveBaseline();
  }

  /// Resets the baseline to the current step count.
  /// This will make the app start counting from this point forward.
  Future<void> resetBaselineToNow() async {
    final currentCount = await getCurrentStepCount();
    if (currentCount != null && currentCount > 0) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      _baselineStepCount = currentCount;
      _baselineDate = today;
      _lastStepCount = currentCount;
      await _saveBaseline();
    }
  }

  /// Clears the stored baseline (for testing or reset purposes).
  Future<void> clearBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_baselineCountKey);
      await prefs.remove(_baselineDateKey);
      _baselineStepCount = null;
      _baselineDate = null;
      _baselineLoaded = false;
    } catch (e) {
      // Ignore errors
    }
  }

  /// Gets the stored baseline step count.
  int? get baselineStepCount => _baselineStepCount;
  int? get lastNativeTodaySteps => _lastNativeTodaySteps;
  int? get lastComputedTodaySteps => _lastComputedTodaySteps;
  int? get lastReturnedTodaySteps => _lastReturnedTodaySteps;
  int? get lastKnownCurrentStepCount => _lastKnownCurrentStepCount;

  /// Gets the date when baseline was set.
  DateTime? get baselineDate => _baselineDate;

  /// Starts listening to step counter updates.
  /// Returns a stream of step counts (cumulative since boot).
  Stream<int> startListening() {
    if (_isListening && _stepStream != null) {
      return _stepStream!;
    }

    _stepStreamController = StreamController<int>.broadcast();
    _stepStream = _stepStreamController!.stream;
    _isListening = true;

    _channel.invokeMethod('startListening');

    return _stepStream!;
  }

  /// Stops listening to step counter updates.
  void stopListening() {
    if (!_isListening) return;

    _channel.invokeMethod('stopListening');
    _stepStreamController?.close();
    _stepStreamController = null;
    _stepStream = null;
    _isListening = false;
  }

  /// Handles method calls from native code.
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onStepCountUpdate':
        final stepCount = call.arguments as int;
        _lastStepCount = stepCount;
        _stepStreamController?.add(stepCount);
        break;
      default:
        throw MissingPluginException(
          'No implementation found for method ${call.method}',
        );
    }
  }

  /// Disposes resources.
  void dispose() {
    stopListening();
  }
}

/// Exception thrown when step counter operations fail.
class StepCounterException implements Exception {
  const StepCounterException(this.message);

  final String message;

  @override
  String toString() => 'StepCounterException: $message';
}
