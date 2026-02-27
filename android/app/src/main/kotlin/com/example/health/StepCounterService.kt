package com.example.health

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class StepCounterService : Service(), SensorEventListener {
    private val TAG = "StepCounterService"
    private var sensorManager: SensorManager? = null
    private var stepCounterSensor: Sensor? = null
    private var isRegistered = false

    private val prefs by lazy {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(true)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                try {
                    startAsForeground()
                } catch (e: SecurityException) {
                    Log.w(TAG, "FGS start blocked: ${e.message}")
                    stopSelf()
                    return START_NOT_STICKY
                }
                registerSensorIfNeeded()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterSensor()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
            val newCount = event.values[0].toInt()
            if (newCount > 0) {
                val today = todayKey()
                val previousDate = prefs.getString(PREF_DAY_START_DATE, null)
                val previousLast = prefs.getInt(PREF_LAST_STEP_COUNT, 0)
                var dayStartCount = prefs.getInt(PREF_DAY_START_COUNT, 0)

                if (previousDate == null || previousDate != today) {
                    // Day rollover: if we did not sample exactly at midnight, previousLast can
                    // be stale (hours/days old), which inflates today's steps massively.
                    // Anchor to the first reading seen today.
                    dayStartCount = newCount
                } else if (dayStartCount <= 0) {
                    dayStartCount = newCount
                }

                val todaySteps = (newCount - dayStartCount).coerceAtLeast(0)
                prefs.edit()
                    .putInt(PREF_LAST_STEP_COUNT, newCount)
                    .putString(PREF_DAY_START_DATE, today)
                    .putInt(PREF_DAY_START_COUNT, dayStartCount)
                    .putInt(PREF_TODAY_STEPS, todaySteps)
                    .apply()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No-op
    }

    private fun registerSensorIfNeeded() {
        if (stepCounterSensor == null || isRegistered) return
        sensorManager?.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_NORMAL)
        isRegistered = true
    }

    private fun unregisterSensor() {
        if (!isRegistered) return
        sensorManager?.unregisterListener(this)
        isRegistered = false
    }

    private fun startAsForeground() {
        val channelId = ensureNotificationChannel()
        val notification = buildNotification(channelId)
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(channelId: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (intent != null) {
            PendingIntent.getActivity(
                this,
                0,
                intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )
        } else {
            null
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }

        builder
            .setContentTitle("HealthHub is tracking steps")
            .setContentText("Step counting is active in the background")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }

        return builder.build()
    }

    private fun ensureNotificationChannel(): String {
        val channelId = NOTIFICATION_CHANNEL_ID
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = manager.getNotificationChannel(channelId)
            if (existing == null) {
                val channel = NotificationChannel(
                    channelId,
                    "Step Tracking",
                    NotificationManager.IMPORTANCE_LOW
                )
                manager.createNotificationChannel(channel)
            }
        }
        return channelId
    }

    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "step_counter_channel"
        private const val NOTIFICATION_ID = 10101
        private const val PREFS_NAME = "step_counter_prefs"
        private const val PREF_LAST_STEP_COUNT = "last_step_count"
        private const val PREF_DAY_START_DATE = "day_start_date"
        private const val PREF_DAY_START_COUNT = "day_start_count"
        private const val PREF_TODAY_STEPS = "today_steps"

        const val ACTION_START = "com.example.health.action.START_STEP_SERVICE"
        const val ACTION_STOP = "com.example.health.action.STOP_STEP_SERVICE"

        fun readLastStepCount(context: Context): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getInt(PREF_LAST_STEP_COUNT, 0)
        }

        fun readTodaySteps(context: Context): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val storedDate = prefs.getString(PREF_DAY_START_DATE, null)
            val today = todayKey()
            if (storedDate == today) {
                return prefs.getInt(PREF_TODAY_STEPS, 0).coerceAtLeast(0)
            }
            return 0
        }

        private fun todayKey(): String {
            val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            return formatter.format(Date())
        }
    }
}
