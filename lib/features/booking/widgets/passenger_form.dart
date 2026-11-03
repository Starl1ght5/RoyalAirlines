import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/validators.dart';
import 'package:royal_airlines/shared/widgets/custom_textfield.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';

class PassengerFormControllers {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController documentController = TextEditingController();
  DateTime? birthDate;

  void dispose() {
    fullNameController.dispose();
    documentController.dispose();
  }
}

class PassengerForm extends StatefulWidget {
  final int passengerIndex;
  final PassengerFormControllers controllers;

  const PassengerForm({
    super.key,
    required this.passengerIndex,
    required this.controllers,
  });

  @override
  State<PassengerForm> createState() => _PassengerFormState();
}

class _PassengerFormState extends State<PassengerForm> {
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.controllers.birthDate ??
          DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (date != null) {
      setState(() => widget.controllers.birthDate = date);
    }
  }

  String get _birthDateLabel {
    final date = widget.controllers.birthDate;
    if (date == null) return 'Seleccionar fecha';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final baseIndex = widget.passengerIndex * 3;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                child: Text(
                  '${widget.passengerIndex + 1}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del pasajero',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Completa la información exactamente como aparece en el documento.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: baseIndex,
            child: CustomTextField(
              controller: widget.controllers.fullNameController,
              label: 'Nombre completo',
              hint: 'Como aparece en el documento',
              icon: Icons.person_outline_rounded,
              validator: (v) => Validators.required(v, fieldName: 'El nombre'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(
            index: baseIndex + 1,
            child: CustomTextField(
              controller: widget.controllers.documentController,
              label: 'Número de documento',
              hint: 'Cédula o pasaporte',
              icon: Icons.badge_outlined,
              validator: (v) =>
                  Validators.required(v, fieldName: 'El documento'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(
            index: baseIndex + 2,
            child: _BirthDateField(
              label: _birthDateLabel,
              hasValue: widget.controllers.birthDate != null,
              onTap: _pickBirthDate,
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthDateField extends StatelessWidget {
  final String label;
  final bool hasValue;
  final VoidCallback onTap;

  const _BirthDateField({
    required this.label,
    required this.hasValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fecha de nacimiento',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: hasValue ? AppColors.primary : AppColors.border,
                  width: hasValue ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    size: 19,
                    color:
                        hasValue ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasValue
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
