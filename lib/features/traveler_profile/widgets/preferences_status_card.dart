import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/traveler_profile/controller/traveler_preferences_controller.dart';
import 'package:royal_airlines/features/traveler_profile/widgets/preferences_sheet.dart';
import 'package:royal_airlines/models/travel_class.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// MonthLabels
/// -----------
/// Etiquetas en español de los meses, compartidas entre la tarjeta de
/// preferencias y el sheet de edición para no duplicar la lista.
class MonthLabels {
  MonthLabels._();

  static const List<String> short = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  static String join(List<int> months) {
    final sorted = [...months]..sort();
    return sorted
        .where((month) => month >= 1 && month <= 12)
        .map((month) => short[month - 1])
        .join(', ');
  }
}

/// PreferencesStatusCard
/// ---------------------
/// Sección "Mis preferencias de viajero" dentro de la pestaña "Para
/// ti". Muestra dos estados:
///
/// - PERFIL SIN DATOS: invitación a completar las preferencias.
/// - CON DATOS: resumen (intereses, presupuesto, meses, estilo y
///   clase), barra de completitud y acceso a editar.
///
/// Las sugerencias de campos opcionales pendientes se muestran como
/// AYUDA, nunca como error: los datos incompletos son válidos.
class PreferencesStatusCard extends StatelessWidget {
  const PreferencesStatusCard({super.key});

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      // El sheet vive bajo el Navigator raíz (no bajo este subtree),
      // así que el controller se le pasa explícitamente.
      builder: (_) => PreferencesSheet(
        controller: context.read<TravelerPreferencesController>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TravelerPreferencesController>();
    if (!controller.isActive) return const SizedBox.shrink();

    return controller.hasPreferences
        ? _FilledCard(controller: controller, onEdit: () => _openSheet(context))
        : _EmptyCard(onTap: () => _openSheet(context));
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.gold,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'Cuéntanos cómo viajas',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Define tus intereses, presupuesto y meses disponibles. '
            'Con esa información podré recomendarte destinos con un '
            'índice de compatibilidad pensado para ti.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomButton(
            label: 'Completar preferencias',
            icon: Icons.edit_outlined,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _FilledCard extends StatelessWidget {
  const _FilledCard({required this.controller, required this.onEdit});

  final TravelerPreferencesController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final prefs = controller.preferences;
    final completion = controller.completionPercentage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.gold,
                  size: 19,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'Tus preferencias de viajero',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _CompletionBadge(percent: completion),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _CompletionBar(percent: completion),
          const SizedBox(height: AppSpacing.lg),
          _InfoRow(
            icon: Icons.favorite_outline_rounded,
            label: 'Intereses',
            value: prefs.interests.map((interest) => interest.label).join(', '),
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Presupuesto',
            value:
                '${CurrencyFormatter.cop(prefs.budgetMin)} – ${CurrencyFormatter.cop(prefs.budgetMax)}',
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Meses disponibles',
            value: prefs.preferredMonths.isEmpty
                ? 'Sin definir aún'
                : MonthLabels.join(prefs.preferredMonths),
            isMuted: prefs.preferredMonths.isEmpty,
          ),
          if (prefs.style != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InfoRow(
              icon: Icons.hiking_outlined,
              label: 'Estilo',
              value: prefs.style!.label,
            ),
          ],
          if (prefs.preferredClass != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InfoRow(
              icon: Icons.airline_seat_recline_extra_outlined,
              label: 'Clase preferida',
              value: prefs.preferredClass!.shortLabel,
            ),
          ],
          if (prefs.missingRecommendedInfo.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _SuggestionBox(messages: prefs.missingRecommendedInfo),
          ],
          const SizedBox(height: AppSpacing.lg),
          CustomButton.secondary(
            label: 'Editar preferencias',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Guardadas en este dispositivo, asociadas a tu cuenta.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final isComplete = percent >= 100;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: (isComplete ? AppColors.success : AppColors.primary)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: isComplete ? AppColors.success : AppColors.primary,
        ),
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  const _CompletionBar({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: LinearProgressIndicator(
        value: percent / 100,
        minHeight: 8,
        backgroundColor: AppColors.surfaceVariant,
        valueColor: AlwaysStoppedAnimation(
          percent >= 100 ? AppColors.success : AppColors.primary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isMuted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final valueColor = isMuted ? AppColors.textTertiary : AppColors.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestionBox extends StatelessWidget {
  const _SuggestionBox({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 16, color: AppColors.info),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Puedes afinar tu perfil',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $message',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
