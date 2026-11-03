import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/models/traveler_profile_model.dart';

/// ArchetypeBadge
/// --------------
/// Tarjeta hero del perfil de viajero: convierte el arquetipo calculado
/// en una insignia celebratoria con jerarquía premium.
class ArchetypeBadge extends StatelessWidget {
  final TravelerArchetype archetype;

  const ArchetypeBadge({super.key, required this.archetype});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.34),
          width: 1.3,
        ),
        boxShadow: [
          ...AppShadows.floating,
          ...AppShadows.goldGlow,
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -8,
            child: _GlowBubble(
              size: 112,
              color: AppColors.goldLight.withValues(alpha: 0.28),
            ),
          ),
          Positioned(
            bottom: -48,
            left: -14,
            child: _GlowBubble(
              size: 124,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glassOverlay,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  'ARQUETIPO ROYAL',
                  style: theme.labelLarge?.copyWith(
                        color: AppColors.goldLight,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ) ??
                      const TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.goldGlow,
                ),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryDark.withValues(alpha: 0.3),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    archetype.emoji,
                    style: const TextStyle(fontSize: 44),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Tu estilo de viaje',
                style: theme.bodyMedium?.copyWith(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ) ??
                    const TextStyle(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                archetype.label,
                textAlign: TextAlign.center,
                style: theme.headlineMedium?.copyWith(
                      color: AppColors.textOnPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ) ??
                    const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                archetype.description,
                textAlign: TextAlign.center,
                style: theme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.45,
                    ) ??
                    const TextStyle(
                      color: Colors.white70,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.glassOverlay,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.goldLight,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Una lectura visual de tu historial para que entiendas cómo viajas hoy en Royal Airlines.',
                        style: theme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.4,
                            ) ??
                            const TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
