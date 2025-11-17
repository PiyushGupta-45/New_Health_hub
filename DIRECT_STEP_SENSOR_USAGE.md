# Direct Step Sensor Access

This implementation allows you to get step data directly from the phone's hardware sensor **without requiring Health Connect or Samsung Health**.

## How It Works

The `DirectStepService` uses Android's **Step Counter Sensor** (TYPE_STEP_COUNTER), which is a hardware sensor available on most modern Android devices (API 19+). This sensor provides:

- **Cumulative steps** since device boot (not daily steps)
- **Hardware-based** accuracy (more reliable than software sensors)
- **No external dependencies** (no Health Connect, no Samsung Health)

## Key Features

1. **Direct Hardware Access**: Uses the phone's built-in step counter sensor
2. **Daily Step Calculation**: Automatically calculates today's steps by maintaining a baseline
3. **Real-time Updates**: Optional stream for real-time step count updates
4. **Automatic Reset**: Baseline resets automatically at the start of each day

## Usage

### Basic Usage

```dart
import 'package:your_app/services/direct_step_service.dart';

final stepService = DirectStepService();

// Check if sensor is available
final isAvailable = await stepService.isStepCounterAvailable();

if (isAvailable) {
  // Get today's steps
  final todaySteps = await stepService.getTodaySteps();
  print('Today\'s steps: $todaySteps');
  
  // Get cumulative steps (since device boot)
  final cumulative = await stepService.getCurrentStepCount();
  print('Cumulative steps: $cumulative');
}
```

### Real-time Updates

```dart
// Start listening for step updates
final stepStream = stepService.startListening();

stepStream.listen((cumulativeSteps) {
  // Calculate today's steps if baseline is set
  if (stepService.baselineStepCount != null) {
    final todaySteps = cumulativeSteps - stepService.baselineStepCount!;
    print('Today\'s steps: $todaySteps');
  }
});

// Don't forget to stop listening when done
stepService.stopListening();
```

### Full Example

See `lib/services/direct_step_service_example.dart` for a complete working example.

## Permissions

The service requires the **ACTIVITY_RECOGNITION** permission, which is already declared in your `AndroidManifest.xml`. The permission will be requested automatically when you call `getTodaySteps()`.

## Important Notes

1. **Device Reboot**: The step counter resets to 0 when the device reboots. The service handles this by resetting the baseline automatically.

2. **Sensor Availability**: Not all devices have a step counter sensor. Always check `isStepCounterAvailable()` before using the service.

3. **Baseline Management**: The service automatically sets a baseline at the start of each day. You can also manually set a baseline using `setBaseline()` if needed.

4. **Cumulative vs Daily**: The sensor provides cumulative steps since boot. Daily steps are calculated by subtracting the baseline (steps at start of day) from the current count.

## Comparison with Health Connect

| Feature | Direct Step Sensor | Health Connect |
|---------|-------------------|----------------|
| External App Required | ❌ No | ✅ Yes |
| Works Offline | ✅ Yes | ✅ Yes |
| Historical Data | ❌ No (only since boot) | ✅ Yes |
| Multiple Sources | ❌ No | ✅ Yes |
| Workout Data | ❌ No | ✅ Yes |
| Setup Complexity | ✅ Simple | ❌ Complex |

## Integration with Existing Code

You can use this service alongside or instead of `HealthSyncService`. For example:

```dart
// Try direct sensor first (no dependencies)
final directService = DirectStepService();
if (await directService.isStepCounterAvailable()) {
  final steps = await directService.getTodaySteps();
  // Use steps...
} else {
  // Fallback to Health Connect
  final healthService = HealthSyncService();
  // Use health service...
}
```

## Troubleshooting

- **Sensor not available**: Some older devices or emulators may not have the step counter sensor. Test on a real device.
- **Zero steps**: Make sure you've granted the ACTIVITY_RECOGNITION permission.
- **Steps not updating**: The sensor may take a moment to provide the first reading. Wait a few seconds after starting the listener.

