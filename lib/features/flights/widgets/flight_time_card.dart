import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';

/// FlightTimeCard
/// --------------
/// Horarios de salida/llegada con códigos IATA y una ruta central clara.
class FlightTimeCard extends StatelessWidget {
  final DateTime departureTime;
  final DateTime arrivalTime;
  final Duration duration;
  final String stopsLabel;
  final bool isDirect;
  final String originCode;
  final String destinationCode;

  const FlightTimeCard({
    super.key,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
    required this.stopsLabel,
    required this.isDirect,
    required this.originCode,
    required this.destinationCode,
  });

  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes > 0 ? '${minutes}m' : ''}'.trim();
  }

  bool _arrivesNextDay() {
    return arrivalTime.year != departureTime.year ||
        arrivalTime.month != departureTime.month ||
        arrivalTime.day != departureTime.day;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AirportTimeBlock(
          time: _formatTime(departureTime),
          code: originCode,
          alignment: CrossAxisAlignment.start,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _RouteLine(isDirect: isDirect),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  stopsLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color:
                        isDirect ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        _AirportTimeBlock(
          time: _formatTime(arrivalTime),
          code: destinationCode,
          alignment: CrossAxisAlignment.end,
          caption: _arrivesNextDay() ? '+1 día' : null,
        ),
      ],
    );
  }
}

class _AirportTimeBlock extends StatelessWidget {
  final String time;
  final String code;
  final CrossAxisAlignment alignment;
  final String? caption;

  const _AirportTimeBlock({
    required this.time,
    required this.code,
    required this.alignment,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          time,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  caption!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _RouteLine extends StatelessWidget {
  final bool isDirect;

  const _RouteLine({required this.isDirect});

  @override
  Widget build(BuildContext context) {
    final accent = isDirect ? AppColors.gold : AppColors.primary;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.26)),
          ),
          alignment: Alignment.center,
          child: Icon(
            isDirect
                ? Icons.flight_takeoff_rounded
                : Icons.connecting_airports_rounded,
            size: 15,
            color: accent,
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ],
    );
  }
}
