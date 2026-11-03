import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/animations/app_motion.dart';
import 'package:royal_airlines/core/routes/app_routes.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/features/reservations/repository/reservations_store.dart';
import 'package:royal_airlines/features/reservations/widgets/reservation_card.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// ReservationsScreen
/// -------------------
class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthController>().isAuthenticated;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mis Reservas')),
      body: SafeArea(
        top: false,
        child: isAuthenticated
            ? const _ReservationsList()
            : const _GuestReservationsPrompt(),
      ),
    );
  }
}

class _ReservationsList extends StatelessWidget {
  const _ReservationsList();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ReservationsStore>();

    if (store.isLoading) {
      return const _LoadingReservations();
    }

    if (store.isEmpty) {
      return const _EmptyReservations();
    }

    final reservations = store.reservations;
    final upcomingCount = reservations
        .where(
          (reservation) =>
              reservation.flight.departureTime.isAfter(DateTime.now()),
        )
        .length;

    return RefreshIndicator(
      onRefresh: store.refresh,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          AppSpacing.xxl,
        ),
        itemCount: reservations.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: _ReservationsHero(
                totalCount: reservations.length,
                upcomingCount: upcomingCount,
              ),
            );
          }

          final reservation = reservations[index - 1];
          return ReservationCard(
            reservation: reservation,
            index: index - 1,
          );
        },
      ),
    );
  }
}

class _ReservationsHero extends StatelessWidget {
  final int totalCount;
  final int upcomingCount;

  const _ReservationsHero({
    required this.totalCount,
    required this.upcomingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
        ),
        boxShadow: [...AppShadows.floating, ...AppShadows.goldGlow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.glassOverlay,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: const Icon(
                  Icons.airplane_ticket_rounded,
                  color: AppColors.gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panel de viaje',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.goldLight,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      upcomingCount > 0
                          ? 'Tienes $upcomingCount vuelo(s) próximo(s)'
                          : 'Todas tus reservas están al día',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Revisa tus reservas confirmadas, consulta horarios y mantén todos tus vuelos en un solo lugar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.76),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Reservas',
                  value: '$totalCount',
                  icon: Icons.confirmation_number_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _HeroStat(
                  label: 'Próximas',
                  value: '$upcomingCount',
                  icon: Icons.flight_takeoff_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.glassOverlay,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.goldLight, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingReservations extends StatefulWidget {
  const _LoadingReservations();

  @override
  State<_LoadingReservations> createState() => _LoadingReservationsState();
}

class _LoadingReservationsState extends State<_LoadingReservations>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glow = _controller.value;
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.xxl,
          ),
          children: [
            _LoadingHero(glow: glow),
            const SizedBox(height: AppSpacing.xl),
            for (var index = 0; index < 3; index++) ...[
              _LoadingReservationCard(
                glow: glow,
                index: index,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        );
      },
    );
  }
}

class _LoadingHero extends StatelessWidget {
  final double glow;

  const _LoadingHero({required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.24),
        ),
        boxShadow: AppShadows.floating,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SkeletonBox(
                width: 50,
                height: 50,
                glow: glow,
                borderRadius: AppSpacing.radiusMd,
                tint: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(
                      width: 110,
                      height: 12,
                      glow: glow,
                      tint: Colors.white.withValues(alpha: 0.14),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SkeletonBox(
                      width: double.infinity,
                      height: 22,
                      glow: glow,
                      tint: Colors.white.withValues(alpha: 0.20),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBox(
            width: double.infinity,
            height: 14,
            glow: glow,
            tint: Colors.white.withValues(alpha: 0.14),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SkeletonBox(
            width: double.infinity,
            height: 14,
            glow: glow,
            tint: Colors.white.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

class _LoadingReservationCard extends StatelessWidget {
  final double glow;
  final int index;

  const _LoadingReservationCard({
    required this.glow,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final delayGlow = (glow + (index * 0.08)).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(
                        width: 68,
                        height: 10,
                        glow: delayGlow,
                        tint: Colors.white.withValues(alpha: 0.14),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SkeletonBox(
                        width: 128,
                        height: 22,
                        glow: delayGlow,
                        tint: Colors.white.withValues(alpha: 0.22),
                      ),
                    ],
                  ),
                ),
                _SkeletonBox(
                  width: 78,
                  height: 28,
                  glow: delayGlow,
                  borderRadius: 999,
                  tint: AppColors.gold.withValues(alpha: 0.22),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SkeletonBox(
                        width: double.infinity,
                        height: 72,
                        glow: delayGlow,
                        borderRadius: AppSpacing.radiusMd,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _SkeletonBox(
                        width: double.infinity,
                        height: 72,
                        glow: delayGlow,
                        borderRadius: AppSpacing.radiusMd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _SkeletonBox(
                  width: double.infinity,
                  height: 56,
                  glow: delayGlow,
                  borderRadius: AppSpacing.radiusMd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double glow;
  final double borderRadius;
  final Color? tint;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.glow,
    this.borderRadius = AppSpacing.radiusSm,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = tint ?? AppColors.skeletonBase;
    final highlightColor = Color.lerp(
          baseColor,
          tint == null
              ? AppColors.skeletonHighlight
              : Colors.white.withValues(alpha: 0.45),
          0.22 + (glow * 0.52),
        ) ??
        baseColor;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
        ),
      ),
    );
  }
}

class _EmptyReservations extends StatelessWidget {
  const _EmptyReservations();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            gradient: AppColors.glassGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.floating,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.goldGlow,
                ),
                child: const Icon(
                  Icons.airplane_ticket_rounded,
                  size: 40,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Aún no tienes reservas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Cuando confirmes un vuelo, aquí verás tus reservas, horarios y detalles del viaje.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _EmptyStateBadge(
                    icon: Icons.airplane_ticket_rounded,
                    label: 'Tus reservas confirmadas',
                  ),
                  _EmptyStateBadge(
                    icon: Icons.notifications_active_outlined,
                    label: 'Todo en un solo lugar',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyStateBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestReservationsPrompt extends StatelessWidget {
  const _GuestReservationsPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl - 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const Text(
              'Inicia sesión para ver tus reservas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Crea una cuenta o inicia sesión para consultar el historial completo de tus vuelos reservados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            CustomButton(
              label: 'Iniciar sesión',
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.register),
              child: const Text(
                'Crear una cuenta nueva',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
