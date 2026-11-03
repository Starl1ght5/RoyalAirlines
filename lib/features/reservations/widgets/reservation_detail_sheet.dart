import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/models/reservation_model.dart';
import 'package:royal_airlines/services/reservation_service.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// ReservationDetailSheet
/// ----------------------
/// Abre el detalle de una reserva. Recibe los datos de la lista como
/// arranque inmediato y en paralelo refresca `GET /reservations/{id}`
/// para mostrar la versión ACTUALIZADA (estado, asientos, precio) que
/// tenga el backend; si el backend falla, se queda con los datos locales.
class ReservationDetailSheet extends StatefulWidget {
  final ReservationModel reservation;

  const ReservationDetailSheet({super.key, required this.reservation});

  @override
  State<ReservationDetailSheet> createState() => _ReservationDetailSheetState();
}

class _ReservationDetailSheetState extends State<ReservationDetailSheet> {
  late ReservationModel _reservation;
  final ReservationService _service = ReservationService();

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
    _refreshDetail();
  }

  Future<void> _refreshDetail() async {
    try {
      final fresh = await _service.fetchReservationDetail(
        widget.reservation.id,
      );
      if (!mounted) return;
      setState(() => _reservation = fresh);
    } catch (_) {
      // Backend caído o detalle inexistente: la hoja ya muestra datos
      // válidos de la lista, así que no se bloquea ni se cierra.
    }
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final reservation = _reservation;
    final flight = reservation.flight;
    final passengerName = reservation.passengers.isNotEmpty
        ? reservation.passengers.first.fullName
        : 'Pasajero principal';
    final statusLabel =
        flight.departureTime.isAfter(DateTime.now()) ? 'Próximo' : 'Completado';
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
          boxShadow: AppShadows.floating,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.xxl + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Tu reserva',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${flight.origin.city} → ${flight.destination.city}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.34),
                  ),
                  boxShadow: [...AppShadows.card, ...AppShadows.goldGlow],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CÓDIGO DE RESERVA',
                                style: TextStyle(
                                  color: AppColors.goldLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                reservation.confirmationCode,
                                style: const TextStyle(
                                  color: AppColors.textOnPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(label: statusLabel),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroColumn(
                            label: 'Origen',
                            primary: flight.origin.code,
                            secondary: flight.origin.city,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.glassOverlay,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.flight_rounded,
                                  color: AppColors.gold,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                flight.flightNumber,
                                style: const TextStyle(
                                  color: AppColors.goldLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _HeroColumn(
                            label: 'Destino',
                            primary: flight.destination.code,
                            secondary: flight.destination.city,
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
                        _HeroPill(
                          icon: Icons.calendar_month_rounded,
                          label: _formatDate(flight.departureTime),
                        ),
                        _HeroPill(
                          icon: Icons.access_time_rounded,
                          label:
                              '${_formatTime(flight.departureTime)} · ${_formatTime(flight.arrivalTime)}',
                        ),
                        _HeroPill(
                          icon: Icons.workspace_premium_rounded,
                          label: reservation.fare.tierName,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: _DetailTile(
                      icon: Icons.flight_takeoff_rounded,
                      title: 'Salida',
                      value:
                          '${_formatDate(flight.departureTime)}\n${_formatTime(flight.departureTime)}',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DetailTile(
                      icon: Icons.flight_land_rounded,
                      title: 'Llegada',
                      value:
                          '${_formatDate(flight.arrivalTime)}\n${_formatTime(flight.arrivalTime)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _DetailTile(
                      icon: Icons.event_seat_rounded,
                      title: 'Asientos',
                      value: reservation.seats.join(', '),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DetailTile(
                      icon: Icons.people_alt_rounded,
                      title: 'Pasajeros',
                      value:
                          '${reservation.passengers.length} viajero(s)\n$passengerName',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionHeading(title: 'Resumen del viaje'),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(
                icon: Icons.airlines_rounded,
                label: 'Aerolínea',
                value: '${flight.airline} · ${flight.flightNumber}',
              ),
              _InfoRow(
                icon: Icons.luggage_rounded,
                label: 'Tarifa',
                value: reservation.fare.tierName,
              ),
              _InfoRow(
                icon: Icons.credit_card_rounded,
                label: 'Pago',
                value:
                    '${reservation.payment.maskedCardNumber} · ${reservation.payment.cardHolderName}',
              ),
              _InfoRow(
                icon: Icons.precision_manufacturing_rounded,
                label: 'Aeronave',
                value: flight.aircraft,
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionHeading(title: 'Beneficios incluidos'),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final benefit in reservation.fare.benefits)
                    _BenefitChip(label: benefit),
                  const _BenefitChip(label: 'Asiento reservado'),
                  const _BenefitChip(label: 'Check-in digital'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            CurrencyFormatter.cop(reservation.totalPrice),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              CustomButton.secondary(
                label: 'Cerrar',
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;

  const _SectionHeading({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = label == 'Próximo';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isUpcoming
            ? AppColors.goldLight
            : AppColors.textOnPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isUpcoming
              ? AppColors.gold
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isUpcoming ? AppColors.primaryDark : AppColors.textOnPrimary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _HeroColumn extends StatelessWidget {
  final String label;
  final String primary;
  final String secondary;
  final CrossAxisAlignment alignment;
  final TextAlign textAlign;

  const _HeroColumn({
    required this.label,
    required this.primary,
    required this.secondary,
    this.alignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          textAlign: textAlign,
          style: const TextStyle(
            color: AppColors.goldLight,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          primary,
          textAlign: textAlign,
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          secondary,
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

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

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

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
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
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    fontWeight: FontWeight.w700,
                    height: 1.45,
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

class _BenefitChip extends StatelessWidget {
  final String label;

  const _BenefitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
