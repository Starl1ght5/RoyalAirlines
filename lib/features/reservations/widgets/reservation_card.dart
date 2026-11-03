import 'package:flutter/material.dart';
import 'package:royal_airlines/core/animations/app_motion.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/reservations/widgets/reservation_detail_sheet.dart';
import 'package:royal_airlines/models/reservation_model.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';

/// ReservationCard
/// ---------------
class ReservationCard extends StatefulWidget {
  final ReservationModel reservation;
  final int index;

  const ReservationCard({
    super.key,
    required this.reservation,
    this.index = 0,
  });

  @override
  State<ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<ReservationCard> {
  bool _isPressed = false;

  ReservationModel get reservation => widget.reservation;

  bool get _isUpcoming =>
      reservation.flight.departureTime.isAfter(DateTime.now());

  String _formatDate(DateTime date) {
    const months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  void _showReservationDetails() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReservationDetailSheet(reservation: reservation),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flight = reservation.flight;
    final upcoming = _isUpcoming;
    final status = _ReservationStatus.fromUpcoming(upcoming);

    return FadeSlideIn(
      index: widget.index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: AnimatedScale(
          scale: 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            decoration: BoxDecoration(
              gradient: AppColors.glassGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: _isPressed
                    ? AppColors.gold.withValues(alpha: 0.34)
                    : upcoming
                        ? AppColors.gold.withValues(alpha: 0.22)
                        : AppColors.border,
              ),
              boxShadow: [
                ...AppShadows.card,
                if (upcoming) ...AppShadows.goldGlow,
              ],
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    onHighlightChanged: (value) {
                      if (_isPressed == value) return;
                      setState(() => _isPressed = value);
                    },
                    onTap: _showReservationDetails,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppSpacing.radiusLg),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppColors.glassOverlay,
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusMd,
                                            ),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.12),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.confirmation_number_rounded,
                                            color: AppColors.gold,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'CÓDIGO DE RESERVA',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.2,
                                                  color: AppColors.goldLight,
                                                ),
                                              ),
                                              const SizedBox(height: AppSpacing.xs),
                                              Text(
                                                reservation.displayCode,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.8,
                                                  color: AppColors.textOnPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  _StatusChip(status: status),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: _AirportTextBlock(
                                      code: flight.origin.code,
                                      city: flight.origin.city,
                                      alignment: CrossAxisAlignment.start,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          _formatDuration(flight.duration),
                                          style: const TextStyle(
                                            color: AppColors.goldLight,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              height: 2,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white
                                                        .withValues(alpha: 0),
                                                    Colors.white
                                                        .withValues(alpha: 0.9),
                                                    Colors.white
                                                        .withValues(alpha: 0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: AppColors.glassOverlay,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.12),
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.flight_rounded,
                                                color: AppColors.gold,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          flight.stopsLabel,
                                          style: TextStyle(
                                            color: AppColors.textOnPrimary
                                                .withValues(alpha: 0.78),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: _AirportTextBlock(
                                      code: flight.destination.code,
                                      city: flight.destination.city,
                                      alignment: CrossAxisAlignment.end,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  _HeaderInfoChip(
                                    icon: Icons.calendar_month_rounded,
                                    label: _formatDate(flight.departureTime),
                                  ),
                                  _HeaderInfoChip(
                                    icon: Icons.access_time_rounded,
                                    label:
                                        '${_formatTime(flight.departureTime)} · ${_formatTime(flight.arrivalTime)}',
                                  ),
                                  _HeaderInfoChip(
                                    icon: Icons.airplane_ticket_outlined,
                                    label: flight.flightNumber,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${flight.origin.city} → ${flight.destination.city}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${flight.airline} · Reserva confirmada el ${_formatDate(reservation.bookedAt)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(height: 1.4),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              const _PerforatedDivider(),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoTile(
                                      icon: Icons.calendar_today_rounded,
                                      label: 'Fecha',
                                      value: _formatDate(flight.departureTime),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: _InfoTile(
                                      icon: Icons.event_seat_rounded,
                                      label: 'Asientos',
                                      value: reservation.seats.join(', '),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoTile(
                                      icon: Icons.people_alt_rounded,
                                      label: 'Pasajeros',
                                      value:
                                          '${reservation.passengers.length} viajero(s)',
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: _InfoTile(
                                      icon: Icons.workspace_premium_rounded,
                                      label: 'Tarifa',
                                      value: reservation.fare.tierName,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.gold.withValues(alpha: 0.12),
                                      AppColors.surface,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                  border: Border.all(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.24),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.goldGradient,
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.payments_rounded,
                                        color: AppColors.primaryDark,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Total pagado',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            CurrencyFormatter.cop(
                                                reservation.totalPrice),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: AppColors.primary
                                          .withValues(alpha: 0.45),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: _ActionButton(
                    label: 'Detalle',
                    icon: Icons.info_outline_rounded,
                    isPrimary: true,
                    onTap: _showReservationDetails,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReservationStatus {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  const _ReservationStatus({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  factory _ReservationStatus.fromUpcoming(bool upcoming) {
    if (upcoming) {
      return const _ReservationStatus(
        label: 'PRÓXIMO',
        icon: Icons.flight_takeoff_rounded,
        foregroundColor: AppColors.primaryDark,
        backgroundColor: AppColors.goldLight,
        borderColor: AppColors.gold,
      );
    }

    return _ReservationStatus(
      label: 'COMPLETADO',
      icon: Icons.check_circle_rounded,
      foregroundColor: AppColors.info,
      backgroundColor: AppColors.info.withValues(alpha: 0.12),
      borderColor: AppColors.info.withValues(alpha: 0.2),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _ReservationStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.foregroundColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: status.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AirportTextBlock extends StatelessWidget {
  final String code;
  final String city;
  final CrossAxisAlignment alignment;
  final TextAlign textAlign;

  const _AirportTextBlock({
    required this.code,
    required this.city,
    required this.alignment,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          code,
          textAlign: textAlign,
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          city,
          textAlign: textAlign,
          style: TextStyle(
            color: AppColors.textOnPrimary.withValues(alpha: 0.78),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeaderInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassOverlay,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.goldLight),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: CustomPaint(
        painter: _DashedLinePainter(),
        size: const Size(double.infinity, 12),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.34)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    const dashWidth = 7.0;
    const dashSpace = 5.0;
    double startX = 0;
    final centerY = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(startX + dashWidth, centerY),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: isPrimary ? AppColors.primaryGradient : null,
            color: isPrimary ? null : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isPrimary
                  ? AppColors.gold.withValues(alpha: 0.28)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? AppColors.goldLight : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  color:
                      isPrimary ? AppColors.textOnPrimary : AppColors.primary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
