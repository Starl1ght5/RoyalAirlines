package com.stellargear.royalairlines_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createOffersChannel()
    }

    /**
     * Canal "offers" de las notificaciones de oferta. En Android 8+ las
     * notificaciones sin canal existente se descartan o caen en uno generico
     * silencioso, asi que se crea al abrir la app (es idempotente). El id debe
     * ser el mismo que usa el backend y el manifest.
     */
    private fun createOffersChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "offers",
            "Ofertas de vuelos",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Avisos de ofertas que coinciden con tu perfil de viaje"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
