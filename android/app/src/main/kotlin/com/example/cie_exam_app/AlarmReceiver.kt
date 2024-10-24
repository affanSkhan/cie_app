package com.example.cie_exam_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Create a notification when the alarm is received
        val alarmSound: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val notificationId = intent.getIntExtra("notificationId", 0)
        val title = intent.getStringExtra("title") ?: "Exam Reminder"
        val body = intent.getStringExtra("body") ?: "Your exam is about to start!"

        // Build the notification
        val builder = NotificationCompat.Builder(context, "exam_reminder_channel")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setSound(alarmSound)
            .setAutoCancel(true)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, builder.build())
    }

    companion object {
        fun showReminderNotification(context: Context, alarmId: Int, title: String, body: String) {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("notificationId", alarmId)
                putExtra("title", title)
                putExtra("body", body)
            }
            context.sendBroadcast(intent)
        }
    }
}
