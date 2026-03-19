package com.example.health

import android.Manifest
import android.content.Intent
import android.content.ComponentName
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity(), SensorEventListener {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.example.health/step_counter"
    private val UPDATE_CHANNEL = "com.example.health/app_update"
    private var sensorManager: SensorManager? = null
    private var stepCounterSensor: Sensor? = null
    private var stepDetectorSensor: Sensor? = null
    private var methodChannel: MethodChannel? = null
    private var isListening = false
    private var lastStepCount = 0
    private var lastDetectorTodaySteps = 0
    private var isSensorRegistered = false
    private var didStartService = false

    private fun startStepCounterServiceIfPossible(): Boolean {
        if (!canStartHealthForegroundService()) {
            Log.i(TAG, "Skipping StepCounterService startup until ACTIVITY_RECOGNITION permission is granted.")
            return false
        }

        return try {
            val intent = Intent(this, StepCounterService::class.java).apply {
                action = StepCounterService.ACTION_START
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            didStartService = true
            true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start StepCounterService: ${e.message}")
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        stepDetectorSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

        // Start background step service (foreground service) so steps keep counting.
        if (!didStartService) {
            startStepCounterServiceIfPossible()
        }

        // Keep the sensor registered so lastStepCount stays fresh.
        // Streaming to Flutter is still controlled by isListening.
        if (stepCounterSensor != null && !isSensorRegistered) {
            sensorManager?.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_NORMAL)
            if (stepDetectorSensor != null) {
                sensorManager?.registerListener(this, stepDetectorSensor, SensorManager.SENSOR_DELAY_UI)
            }
            isSensorRegistered = true
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
                        result.success(value)
                    }
                }
                "getTodayStepCount" -> {
                    if (stepCounterSensor == null) {
                        result.error("SENSOR_UNAVAILABLE", "Step counter sensor is not available", null)
                    } else {
                        val todaySteps = StepCounterService.readTodaySteps(this)
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
                        if (stepDetectorSensor != null) {
                            sensorManager?.registerListener(this, stepDetectorSensor, SensorManager.SENSOR_DELAY_UI)
                        }
                        isSensorRegistered = true
                        lastDetectorTodaySteps = StepCounterService.readTodaySteps(this)

                        // Start background service only after permission is available.
                        if (!didStartService) {
                            startStepCounterServiceIfPossible()
                        }
                        result.success(null)
                    }
                }
                "stopListening" -> {
                    if (isListening) {
                        isListening = false
                    }
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                        if (powerManager.isIgnoringBatteryOptimizations(packageName)) {
                            result.success(true)
                        } else {
                            openPreferredBatteryPermissionUi()
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to request ignore battery optimizations", e)
                        result.error("BATTERY_OPT_REQUEST_FAILED", e.message, null)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        openBatteryOptimizationSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open battery optimization settings", e)
                        result.error("BATTERY_SETTINGS_FAILED", e.message, null)
                    }
                }
                "openAutoStartSettings" -> {
                    val opened = openAutoStartSettings()
                    result.success(opened)
                }
                "ensureBackgroundTrackingStarted" -> {
                    result.success(startStepCounterServiceIfPossible())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canRequestPackageInstalls" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            result.success(packageManager.canRequestPackageInstalls())
                        } else {
                            result.success(true)
                        }
                    }
                "openInstallUnknownAppsSettings" -> {
                    try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                            } else {
                                val intent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                            }
                            result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open install unknown apps settings", e)
                        result.error("SETTINGS_OPEN_FAILED", e.message, null)
                    }
                }
                "cleanupDownloadedApks" -> {
                    try {
                        val otaDir = File(filesDir, "ota_update")
                        var deletedFiles = 0
                        var freedBytes = 0L
                        if (otaDir.exists() && otaDir.isDirectory) {
                            otaDir.listFiles()?.forEach { file ->
                                if (file.isFile && file.name.endsWith(".apk", ignoreCase = true)) {
                                    val size = file.length()
                                    if (file.delete()) {
                                        deletedFiles += 1
                                        freedBytes += size
                                    }
                                }
                            }
                        }

                        // Also cleanup any legacy apk files in filesDir root.
                        filesDir.listFiles()?.forEach { file ->
                            if (file.isFile && file.name.endsWith(".apk", ignoreCase = true)) {
                                val size = file.length()
                                if (file.delete()) {
                                    deletedFiles += 1
                                    freedBytes += size
                                }
                            }
                        }

                        result.success(
                            mapOf(
                                "deletedFiles" to deletedFiles,
                                "freedBytes" to freedBytes
                            )
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to cleanup downloaded APKs", e)
                        result.error("CLEANUP_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canStartHealthForegroundService(): Boolean {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.Q) {
            return true
        }
        return checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED
    }

    private fun openBatteryOptimizationSettings() {
        val intents = listOf(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )

        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return
            }
        }
        throw IllegalStateException("No battery optimization settings screen available")
    }

    private fun openPreferredBatteryPermissionUi() {
        if (openXiaomiBatteryDetails()) {
            return
        }

        val intent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        if (intent.resolveActivity(packageManager) != null) {
            startActivity(intent)
            return
        }

        openBatteryOptimizationSettings()
    }

    private fun openXiaomiBatteryDetails(): Boolean {
        val appLabel = applicationInfo.loadLabel(packageManager).toString()
        val intents = listOf(
            Intent().apply {
                component = ComponentName(
                    "com.miui.powerkeeper",
                    "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"
                )
                putExtra("package_name", packageName)
                putExtra("package_label", appLabel)
                putExtra("packageName", packageName)
            },
            Intent("miui.intent.action.POWER_HIDE_MODE_APP_CONFIG").apply {
                setPackage("com.miui.powerkeeper")
                putExtra("package_name", packageName)
                putExtra("package_label", appLabel)
                putExtra("packageName", packageName)
            }
        )

        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }
        return false
    }

    private fun openAutoStartSettings(): Boolean {
        val intents = listOf(
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity"
                )
            }
        )

        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }
        return false
    }

    override fun onSensorChanged(event: SensorEvent?) {
        when (event?.sensor?.type) {
            Sensor.TYPE_STEP_COUNTER -> {
                val newCount = event.values[0].toInt()
                if (newCount > 0) {
                    lastStepCount = newCount
                    if (isListening) {
                        methodChannel?.invokeMethod("onStepCountUpdate", lastStepCount)
                    }
                }
            }
            Sensor.TYPE_STEP_DETECTOR -> {
                if (isListening) {
                    lastDetectorTodaySteps = StepCounterService.incrementTodaySteps(this)
                    methodChannel?.invokeMethod("onStepCountUpdate", lastStepCount)
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Not needed for step counter
    }

    override fun onStop() {
        super.onStop()
        startStepCounterServiceIfPossible()
    }

    override fun onDestroy() {
        startStepCounterServiceIfPossible()
        super.onDestroy()
        if (isSensorRegistered) {
            sensorManager?.unregisterListener(this)
            isSensorRegistered = false
        }
    }
}
