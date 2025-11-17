package com.example.health

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity(), SensorEventListener {
    private val CHANNEL = "com.example.health/step_counter"
    private var sensorManager: SensorManager? = null
    private var stepCounterSensor: Sensor? = null
    private var methodChannel: MethodChannel? = null
    private var isListening = false
    private var lastStepCount = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        
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
                        // If we're already listening, return the last known value
                        if (isListening && lastStepCount > 0) {
                            result.success(lastStepCount)
                        } else {
                            // Register listener to get current count
                            // The step counter sensor needs to be registered to provide values
                            sensorManager?.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_FASTEST)
                            
                            // Wait a bit for sensor to provide value, then unregister
                            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                sensorManager?.unregisterListener(this)
                                // Return the value we received (or 0 if none)
                                result.success(if (lastStepCount > 0) lastStepCount else 0)
                            }, 500)
                        }
                    }
                }
                "startListening" -> {
                    if (stepCounterSensor == null) {
                        result.error("SENSOR_UNAVAILABLE", "Step counter sensor is not available", null)
                    } else if (isListening) {
                        result.success(null)
                    } else {
                        isListening = true
                        sensorManager?.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_NORMAL)
                        result.success(null)
                    }
                }
                "stopListening" -> {
                    if (isListening) {
                        isListening = false
                        sensorManager?.unregisterListener(this)
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
        if (isListening) {
            sensorManager?.unregisterListener(this)
        }
    }
}
