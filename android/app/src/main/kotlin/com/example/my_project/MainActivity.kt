package com.milanium.mtaxi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createTaxiNotificationChannel()
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun createTaxiNotificationChannel() {
        val channelId = "mtaxi_orders_v2"
        val channelName = "MTaxi Order Alerts"
        val soundUri = Uri.parse(
            "android.resource://" + applicationContext.packageName + "/" + R.raw.whatsapp_notification
        )
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Loud order alerts for drivers"
            setSound(soundUri, attributes)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 700, 250, 900, 250, 1100)
            enableLights(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
