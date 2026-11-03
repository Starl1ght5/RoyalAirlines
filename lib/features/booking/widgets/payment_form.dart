import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/validators.dart';
import 'package:royal_airlines/shared/widgets/custom_textfield.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';
import 'package:royal_airlines/shared/widgets/section_title.dart';

class PaymentFormControllers {
  final TextEditingController cardHolderController = TextEditingController();
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  void dispose() {
    cardHolderController.dispose();
    cardNumberController.dispose();
    expiryController.dispose();
    cvvController.dispose();
  }
}

class PaymentForm extends StatelessWidget {
  final PaymentFormControllers controllers;

  const PaymentForm({super.key, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Pago'),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.glassGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              const FadeSlideIn(
                index: 0,
                child: _PaymentHeader(),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                index: 1,
                child: CustomTextField(
                  controller: controllers.cardHolderController,
                  label: 'Titular de la tarjeta',
                  hint: 'Como aparece en la tarjeta',
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      Validators.required(v, fieldName: 'El titular'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FadeSlideIn(
                index: 2,
                child: CustomTextField(
                  controller: controllers.cardNumberController,
                  label: 'Número de tarjeta',
                  hint: '1234 5678 9012 3456',
                  icon: Icons.credit_card_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _CardNumberFormatter(),
                  ],
                  validator: _validateCardNumber,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FadeSlideIn(
                      index: 3,
                      child: CustomTextField(
                        controller: controllers.expiryController,
                        label: 'Vencimiento',
                        hint: 'MM/YY',
                        icon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _ExpiryDateFormatter(),
                        ],
                        validator: _validateExpiry,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FadeSlideIn(
                      index: 4,
                      child: CustomTextField(
                        controller: controllers.cvvController,
                        label: 'CVV',
                        hint: '123',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: _validateCvv,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const FadeSlideIn(
                index: 5,
                child: _PaymentNote(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String? _validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(' ', '');
    if (digits.isEmpty) return 'Ingresa el número de tarjeta';
    if (digits.length < 16) return 'Número de tarjeta incompleto';
    return null;
  }

  static String? _validateExpiry(String? value) {
    if (value == null || value.isEmpty) return 'Requerido';
    final regex = RegExp(r'^\d{2}/\d{2}$');
    if (!regex.hasMatch(value)) return 'Formato MM/YY';
    return null;
  }

  static String? _validateCvv(String? value) {
    if (value == null || value.length < 3) return 'CVV inválido';
    return null;
  }
}

class _PaymentHeader extends StatelessWidget {
  const _PaymentHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: const Icon(
            Icons.lock_rounded,
            color: AppColors.gold,
            size: 21,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos de pago',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Usa una tarjeta de prueba para completar la simulación.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const _HeaderBadge(label: 'Seguro'),
      ],
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final String label;

  const _HeaderBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _PaymentNote extends StatelessWidget {
  const _PaymentNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.info),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Pago simulado: no se procesa ningún cargo real y tus datos no se almacenan.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 16; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
