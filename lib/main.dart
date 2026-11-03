import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:royal_airlines/app.dart';
import 'package:royal_airlines/services/push_message_handler.dart';
import 'package:royal_airlines/services/push_notification_service.dart';

/// Handler de mensajes con la app en segundo plano o cerrada. Debe ser una
/// función de nivel superior y llevar `@pragma`, porque Android la ejecuta en un
/// aislado aparte. Las notificaciones con bloque `notification` (las de oferta)
/// las muestra el sistema solo; aquí solo se deja Firebase listo en ese aislado.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Entry point de la aplicación. Deliberadamente mínimo: toda la
/// configuracion real (controllers, tema y rutas) vive en [RoyalAirlinesApp]
/// dentro de `app.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nunca lanza: sin google-services.json (o fuera de Android) `isAvailable`
  // queda en false y la app arranca igual, solo sin notificaciones.
  await PushNotificationService.instance.init();
  if (PushNotificationService.instance.isAvailable) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    PushMessageHandler.instance.init();
  }

  runApp(const RoyalAirlinesApp());
}
