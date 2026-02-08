package com.example.health

import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity(), SensorEventListener {
    private val TAG = "StepCounter"
    private val CHANNEL = "com.example.health/step_counter"
    private var sensorManager: SensorManager? = null
    private var stepCounterSensor: Sensor? = null
    private var methodChannel: MethodChannel? = null
    private var isListening = false
    private var lastStepCount = 0
    private var isSensorRegistered = false
    private var didStartService = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        Log.d(TAG, "Step sensor available: ${stepCounterSensor != null}")

        // Start background step service (foreground service) so steps keep counting.
        if (!didStartService) {
            val intent = Intent(this, StepCounterService::class.java).apply {
                action = StepCounterService.ACTION_START
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            didStartService = true
            Log.d(TAG, "StepCounterService start requested")
        }

        // Keep the sensor registered so lastStepCount stays fresh.
        // Streaming to Flutter is still controlled by isListening.
        if (stepCounterSensor != null && !isSensorRegistered) {
            sensorManager?.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_NORMAL)
            isSensorRegistered = true
            Log.d(TAG, "Sensor registered (persistent)")
        }
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isStepCounterAvailable" -> {
                    result.success(stepCounterSensor != null)
                }
                "getCurrentStepCount" -> {
                    if (stepCounterSensor == null) {
                        result.error("SENSOR_UNAVAILABLE", "Step counter sensor is not available", null)
                    } else {
                        // Return the last known value; sensor is kept registered.
                        var value = if (lastStepCount > 0) lastStepCount else 0
                        if (value == 0) {
                            value = StepCounterService.readLastStepCount(this)
                        }
                        Log.d(TAG, "getCurrentStepCount -> $value")
                        result.success(value)
                    }
                }
                "getTodayStepCount" -> {
                    if (stepCounterSensor == null) {
                        result.error("SENSOR_UNAVAILABLE", "Step counter sensor is not available", null)
                    } else {
                        val todaySteps = StepCounterService.readTodaySteps(this)
                        Log.d(TAG, "getTodayStepCount -> $todaySteps")
                        result.success(todaySteps)
                    }
                }
                "startListening" -> {
                    if (stepCounterSensor == null) {
                        result.error("SENSOR_UNAVAILABLE", "Step counter sensor is not available", null)
                    } else if (isListening) {
                        result.success(null)
                    } else {
                        isListening = true
                        // Always re-register when listening starts. On some devices,
                        // listeners registered before ACTIVITY_RECOGNITION permission
                        // grant can remain silent until re-registered.
                        if (isSensorRegistered) {
                            sensorManager?.unregisterListener(this)
                            isSensorRegistered = false
                        }
                        sensorManager?.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_NORMAL)
                        isSensorRegistered = true
                        Log.d(TAG, "Sensor re-registered (startListening)")
                        result.success(null)
                    }
                }
                "stopListening" -> {
                    if (isListening) {
                        isListening = false
                    }
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
            val newCount = event.values[0].toInt()
            Log.d(TAG, "onSensorChanged -> $newCount")
            if (newCount > 0) {
                lastStepCount = newCount
                if (isListening) {
                    methodChannel?.invokeMethod("onStepCountUpdate", lastStepCount)
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Not needed for step counter
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isSensorRegistered) {
            sensorManager?.unregisterListener(this)
            isSensorRegistered = false
        }
    }
}
