import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/flights/widgets/price_history_card.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// FareDetailsSheet
/// ----------------
/// Bottom sheet con las tarifas disponibles de un vuelo. La PRIMERA
/// fila es el histórico de precios de la ruta (`PriceHistoryCard`,
/// en USD) para que se vea la tendencia antes de elegir tarifa. Cada
/// tarjeta de tarifa tiene padding de 16px (antes 18) y beneficios en
/// 11.5px — más denso en información sin perder legibilidad, ya que
/// el sheet puede llegar a mostrar hasta 10 beneficios por tarifa.
class FareDetailsSheet extends StatelessWidget {
  final FlightModel flight;

  const FareDetailsSheet({super.key, required this.flight});

  static Future<FareModel?> show(BuildContext context, FlightModel flight) {
    return showModalBottomSheet<FareModel>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FareDetailsSheet(flight: flight),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                16,
                AppSpacing.xxl,
                8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${flight.fares.length} tarifas disponibles',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 21),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  4,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                itemCount: flight.fares.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  // Índice 0: histórico de precios de la ruta del vuelo
                  // (GET /prices/history, en USD), encima de las
                  // tarifas para que el usuario vea la tendencia antes
                  // de elegir.
                  if (index == 0) {
                    return PriceHistoryCard(
                      originCode: flight.origin.code,
                      destinationCode: flight.destination.code,
                      departureDate: flight.departureTime,
                    );
                  }
                  final fare = flight.fares[index - 1];
                  return _FareTierCard(
                    fare: fare,
                    onSelect: () => Navigator.of(context).pop(fare),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FareTierCard extends StatelessWidget {
  final FareModel fare;
  final VoidCallback onSelect;

  const _FareTierCard({required this.fare, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fare.tierName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 11),
          ...fare.benefits.map((benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        benefit,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyFormatter.cop(fare.price),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    'Por pasajero · incluye tasas',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 112,
                height: 42,
                child: CustomButton(label: 'Elegir', onPressed: onSelect),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
