# Notification Troubleshooting Guide

## Issue: Scheduled notifications not appearing

If test notifications work but scheduled notifications don't, follow these steps:

### 1. Grant Exact Alarm Permission (Android 12+)
1. Go to **Settings** → **Apps** → **FitTrack** (or your app name)
2. Tap **Special app access** (or **App permissions**)
3. Tap **Alarms & reminders**
4. Enable **"Allow"**

### 2. Disable Battery Optimization
1. Go to **Settings** → **Apps** → **FitTrack**
2. Tap **Battery** (or **App battery usage**)
3. Select **"Unrestricted"** or **"Not optimized"**

### 3. Keep App in Foreground (For Testing)
- Keep the app open when testing scheduled notifications
- Android may delay notifications if the app is in the background

### 4. Check Console Logs
Look for these messages:
- `✅ Notification scheduled successfully!`
- `📌 Scheduled with EXACT alarm mode` or `📌 Scheduled with INEXACT alarm mode`
- `✅ Verified in pending notifications`

### 5. Test with Longer Time
- Try scheduling a notification for 5-10 minutes in the future
- Inexact alarms may have a delay of a few minutes

### 6. Verify Notification Channel
1. Go to **Settings** → **Apps** → **FitTrack** → **Notifications**
2. Ensure **"Goal Reminders"** channel is enabled
3. Check that sound and vibration are enabled

## Why This Happens

- **Android 12+** requires explicit permission for exact alarms
- **Battery optimization** can prevent scheduled notifications
- **Doze mode** delays notifications when the device is idle
- **Inexact alarms** may have delays (up to 15 minutes)

## Solution

The app now tries **exact alarms first** (more reliable), then falls back to **inexact alarms** if permission is not granted. Inexact alarms will still work but may have a small delay.

