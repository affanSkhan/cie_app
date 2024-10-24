package com.example.cie_exam_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "exam_reminder_channel"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setExamReminder") {
                val triggerAtMillis: Long = call.argument<Long>("triggerAtMillis") ?: return@setMethodCallHandler
                val notificationId: Int = call.argument<Int>("notificationId") ?: return@setMethodCallHandler
                val title: String = call.argument<String>("title") ?: "Exam Reminder"
                val body: String = call.argument<String>("body") ?: "Your exam is about to start!"

                setExamReminder(this, triggerAtMillis, notificationId, title, body)
                result.success(null)
            }
        }
    }

    private fun setExamReminder(context: Context, triggerAtMillis: Long, notificationId: Int, title: String, body: String) {
        // Create an Intent for the AlarmReceiver
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("notificationId", notificationId)
            putExtra("title", title)
            putExtra("body", body)
        }

        // Create a PendingIntent to be triggered by the alarm
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId, // Unique ID per reminder
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE // FLAG_IMMUTABLE for API 23+
        )

        // Set the alarm using AlarmManager
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, // Wake up the device to trigger the alarm
            triggerAtMillis, // Time at which the alarm should be triggered
            pendingIntent
        )

    }
}
