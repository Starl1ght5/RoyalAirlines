import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/services/push_notification_service.dart';
import 'package:royal_airlines/services/tracking_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pregunta una sola vez, justo después de guardar las preferencias de viaje,
/// si el usuario quiere recibir alertas de ofertas. Es el momento en que ya
/// vio el valor de dar sus datos, por eso el permiso se pide aquí y no al
/// abrir la app.
///
/// Reglas:
///  - Solo en plataformas con push y con Firebase disponible.
///  - No pregunta si las alertas ya están activas y con permiso concedido.
///  - Se pregunta UNA vez por cuenta (el flag se guarda aunque responda
///    "Ahora no"); el interruptor de Perfil sigue disponible.
///  - Si acepta: `PUT /users/me/consent` (marketingOptIn=true, conservando el
///    permiso de tracking) y luego el diálogo del sistema. Si el sistema lo
///    rechaza no se insiste.
///  - Nunca lanza: un fallo aquí no debe afectar el guardado de preferencias.
Future<void> maybeAskOfferAlerts(BuildContext context) async {
  try {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    final push = PushNotificationService.instance;
    if (!push.isSupported) return;
    await push.init();
    if (!push.isAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'offer_alerts_prompted_$userId';
    if (prefs.getBool(key) ?? false) return;

    final consentService = TrackingConsentService();
    final consent = await consentService.fetch();
    if (consent.marketingOptIn && await push.hasPermission()) return;

    if (!context.mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        icon: const Icon(
          Icons.notifications_active_outlined,
          color: AppColors.primary,
          size: 30,
        ),
        title: const Text(
          '¿Quieres que te avisemos?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Te enviaremos una notificación cuando haya ofertas que coincidan '
          'con tu perfil de viaje. Puedes desactivarlas cuando quieras desde '
          'Perfil.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Sí, avísame'),
          ),
        ],
      ),
    );

    // Se marca como preguntado sin importar la respuesta: no insistir.
    await prefs.setBool(key, true);
    if (accepted != true) return;

    await consentService.save(
      tracking: consent.tracking,
      marketingOptIn: true,
    );
    await push.requestPermissionAndRegister();
  } catch (error) {
    debugPrint('Alertas de ofertas: no se pudo completar la pregunta ($error)');
  }
}
