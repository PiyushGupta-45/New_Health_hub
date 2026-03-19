package com.example.health

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class StepBootReceiver : BroadcastReceiver() {
    private val tag = "StepBootReceiver"

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val shouldRestart =
            action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == StepCounterService.ACTION_RESTART_SERVICE

        if (!shouldRestart) {
            return
        }

        val serviceIntent = Intent(context, StepCounterService::class.java).apply {
            this.action = StepCounterService.ACTION_START
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.w(tag, "Failed to restart step service on boot: ${e.message}")
        }
    }
}
