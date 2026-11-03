import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/booking/widgets/baggage_option.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/travel_class.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';
import 'package:royal_airlines/shared/widgets/section_title.dart';

class BookingSummary extends StatelessWidget {
  final FlightModel flight;
  final FareModel fare;
  final int passengerCount;
  final BaggageOption baggageOption;
  final double seatCharge;
  final double travelExtrasCharge;
  final double totalPrice;
  final String title;
  final String? subtitle;

  const BookingSummary({
    super.key,
    required this.flight,
    required this.fare,
    required this.passengerCount,
    required this.baggageOption,
    required this.seatCharge,
    required this.travelExtrasCharge,
    required this.totalPrice,
    this.title = 'Resumen',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final fareSubtotal = fare.price * passengerCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: title),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.glassGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.gold,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${flight.origin.code} ? ${flight.destination.code}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${flight.airline} ? ${flight.flightNumber}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.16),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Text(
                              fare.travelClass.shortLabel,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _SummaryRow(
                              label: '${fare.tierName} x $passengerCount',
                              value: CurrencyFormatter.cop(fareSubtotal),
                            ),
                            if (seatCharge > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _SummaryRow(
                                label: 'Selección de asientos',
                                value: '+${CurrencyFormatter.cop(seatCharge)}',
                              ),
                            ],
                            if (baggageOption.price > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _SummaryRow(
                                label: baggageOption.label,
                                value:
                                    '+${CurrencyFormatter.cop(baggageOption.price)}',
                              ),
                            ],
                            if (travelExtrasCharge > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _SummaryRow(
                                label: 'Extras de viaje',
                                value:
                                    '+${CurrencyFormatter.cop(travelExtrasCharge)}',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL ESTIMADO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: AppColors.gold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Impuestos y extras incluidos',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textOnPrimary
                                    .withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.cop(totalPrice),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
