import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/services/push_notification_service.dart';
import 'package:royal_airlines/services/tracking_consent_service.dart';
import 'package:royal_airlines/services/user_event_tracker.dart';

/// ConsentSettingsCard
/// -------------------
/// Sección "Privacidad y datos" de Perfil con los DOS permisos del
/// consentimiento (`GET`/`PUT /users/me/consent`), que son
/// independientes:
///
///  - **tracking** → habilita la recolección de eventos de
///    comportamiento que alimentan al recomendador. Al cambiarlo se
///    actualiza también `UserEventTracker.enabled`, así el efecto es
///    inmediato (sin esperar al próximo arranque).
///  - **marketingOptIn** → autoriza ofertas por correo/notificación.
///
/// El estado real se lee del backend al montar la tarjeta; si no se
/// pudo leer (sin red, endpoint caído) los toggles quedan
/// DESHABILITADOS con aviso y opción de reintentar, en vez de
/// asumir `false` — asumirlo y guardar pisaría el otro permiso.
class ConsentSettingsCard extends StatefulWidget {
  const ConsentSettingsCard({super.key});

  @override
  State<ConsentSettingsCard> createState() => _ConsentSettingsCardState();
}

class _ConsentSettingsCardState extends State<ConsentSettingsCard> {
  final TrackingConsentService _service = TrackingConsentService();

  bool _tracking = false;
  bool _marketingOptIn = false;
  String? _consentDate;

  /// `true` si las alertas están activadas pero el sistema no dio permiso de
  /// notificaciones (lo rechazaron o lo quitaron en los ajustes del teléfono).
  /// No se vuelve a pedir: solo se explica dónde activarlo.
  bool _pushBlocked = false;

  /// `true` mientras se hace el `GET` inicial.
  bool _loading = true;

  /// `true` si el `GET` inicial falló: sin estado real del servidor no
  /// se puede editar (ver doc de la clase).
  bool _loadFailed = false;

  /// `true` mientras hay un `PUT` en vuelo (los toggles se bloquean
  /// para no disparar escrituras concurrentes que se pisen).
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final consent = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _tracking = consent.tracking;
        _marketingOptIn = consent.marketingOptIn;
        _consentDate = consent.consentDate;
        _loading = false;
      });
      // Refuerzo de la puerta de arranque (lib/app.dart): por si el
      // `GET` de arranque falló por red o el usuario cambió de equipo.
      context.read<UserEventTracker>().enabled = consent.tracking;
      if (consent.marketingOptIn) _refreshPushBlocked();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _save(
      {required bool tracking, required bool marketingOptIn}) async {
    final previousTracking = _tracking;
    final previousMarketing = _marketingOptIn;

    // Optimista: el toggle responde al instante y se revierte si el
    // backend rechaza la escritura.
    setState(() {
      _tracking = tracking;
      _marketingOptIn = marketingOptIn;
      _saving = true;
    });

    try {
      final saved = await _service.save(
        tracking: tracking,
        marketingOptIn: marketingOptIn,
      );
      if (!mounted) return;
      setState(() {
        _tracking = saved.tracking;
        _marketingOptIn = saved.marketingOptIn;
        _consentDate = saved.consentDate ?? _consentDate;
        _saving = false;
      });
      context.read<UserEventTracker>().enabled = saved.tracking;
      if (saved.marketingOptIn != previousMarketing) {
        await _applyPushChange(saved.marketingOptIn);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tracking = previousTracking;
        _marketingOptIn = previousMarketing;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar tu preferencia. Intenta de nuevo.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Activar las alertas pide el permiso del sistema y registra el token; al
  /// desactivarlas se da de baja el dispositivo. Nunca lanza (el servicio de
  /// push ya captura sus errores).
  Future<void> _applyPushChange(bool enabled) async {
    final push = PushNotificationService.instance;
    if (!push.isSupported) return;
    if (enabled) {
      final granted = await push.requestPermissionAndRegister();
      if (!mounted) return;
      setState(() => _pushBlocked = !granted);
    } else {
      await push.unregister();
      if (!mounted) return;
      setState(() => _pushBlocked = false);
    }
  }

  /// Revisa (sin diálogos) si el permiso del sistema sigue concedido.
  Future<void> _refreshPushBlocked() async {
    final push = PushNotificationService.instance;
    if (!push.isSupported) return;
    final granted = await push.hasPermission();
    if (!mounted) return;
    setState(() => _pushBlocked = !granted);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.10),
                        AppColors.primary.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.privacy_tip_outlined,
                    size: 23,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacidad y datos',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Tú decides qué se registra y para qué.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.2,
                    ),
                  ),
                ),
              )
            else if (_loadFailed) ...[
              const Text(
                'No se pudo cargar tu configuración de privacidad. '
                'Revisa tu conexión.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Reintentar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ] else ...[
              _ConsentToggleRow(
                icon: Icons.analytics_outlined,
                title: 'Personalizar mi experiencia',
                subtitle: 'Registra búsquedas, vistas y clics para mejorar las '
                    'recomendaciones que ves en la app. No se envía nada '
                    'sin tu permiso.',
                value: _tracking,
                onChanged: _saving
                    ? null
                    : (value) => _save(
                          tracking: value,
                          marketingOptIn: _marketingOptIn,
                        ),
              ),
              const Divider(color: AppColors.divider, height: 1),
              _ConsentToggleRow(
                icon: Icons.campaign_outlined,
                title: 'Alertas de ofertas',
                subtitle: 'Permite enviarte ofertas por correo o notificación '
                    'cuando coincidan con tu perfil. Permiso separado del '
                    'anterior.',
                value: _marketingOptIn,
                onChanged: _saving
                    ? null
                    : (value) => _save(
                          tracking: _tracking,
                          marketingOptIn: value,
                        ),
              ),
              if (_marketingOptIn && _pushBlocked) ...[
                const SizedBox(height: AppSpacing.sm),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Las notificaciones están desactivadas en tu teléfono. '
                        'Puedes activarlas desde Ajustes > Aplicaciones > '
                        'Royal Airlines > Notificaciones.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_consentDate != null && _consentDate!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Último registro de consentimiento: ${_formatDate(_consentDate!)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// `2026-10-28T17:00:00` -> `28/10/2026 17:00`. Si el formato no es
  /// el esperado se muestra tal cual (nunca lanzar dentro de build).
  static String _formatDate(String raw) {
    final match =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}:\d{2})').firstMatch(raw);
    if (match == null) return raw;
    return '${match.group(3)}/${match.group(2)}/${match.group(1)} '
        '${match.group(4)}';
  }
}

/// Fila con icono, textos y switch, alineada con el resto de tarjetas
/// de Perfil. `onChanged == null` deja el switch deshabilitado
/// (mientras carga, mientras guarda o si falló la lectura inicial).
class _ConsentToggleRow extends StatelessWidget {
  const _ConsentToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.textOnPrimary,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.surfaceVariant,
            inactiveThumbColor: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
