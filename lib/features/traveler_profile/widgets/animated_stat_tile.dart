import 'package:flutter/material.dart';
import 'package:royal_airlines/core/animations/app_motion.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';

/// AnimatedStatTile
/// ----------------
/// Tarjeta de métrica con jerarquía premium y contador animado.
class AnimatedStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Duration delay;

  const AnimatedStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final valueSpec = _AnimatedValueSpec.fromValue(value);

    return Container(
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: AppShadows.card,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.goldLight, size: 20),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const Spacer(),
          _AnimatedValueText(
            valueSpec: valueSpec,
            duration: AppMotion.slow + delay,
            style: theme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.primaryDark,
                ) ??
                const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.primaryDark,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.bodyMedium?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ) ??
                const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: AppMotion.slow + delay,
              curve: AppMotion.standard,
              builder: (context, progress, _) {
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 6,
                      color: AppColors.surfaceVariant,
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          gradient: AppColors.goldGradient,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedValueText extends StatelessWidget {
  final _AnimatedValueSpec valueSpec;
  final TextStyle style;
  final Duration duration;

  const _AnimatedValueText({
    required this.valueSpec,
    required this.style,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    if (valueSpec.numericValue == null) {
      return Text(valueSpec.rawValue, style: style, maxLines: 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: valueSpec.numericValue!.toDouble()),
      duration: duration,
      curve: AppMotion.standard,
      builder: (context, animatedValue, _) {
        return Text(
          valueSpec.format(animatedValue.round()),
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _AnimatedValueSpec {
  final String rawValue;
  final int? numericValue;
  final String prefix;
  final String suffix;

  const _AnimatedValueSpec({
    required this.rawValue,
    required this.numericValue,
    required this.prefix,
    required this.suffix,
  });

  factory _AnimatedValueSpec.fromValue(String value) {
    final firstDigitIndex = value.indexOf(_digitPattern);
    if (firstDigitIndex == -1) {
      return _AnimatedValueSpec(
        rawValue: value,
        numericValue: null,
        prefix: '',
        suffix: '',
      );
    }

    final lastDigitIndex = value.lastIndexOf(_digitPattern);
    final prefix = value.substring(0, firstDigitIndex);
    final suffix = value.substring(lastDigitIndex + 1);
    final digits = value
        .substring(firstDigitIndex, lastDigitIndex + 1)
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    final parsedNumber = int.tryParse(digits);

    if (parsedNumber == null) {
      return _AnimatedValueSpec(
        rawValue: value,
        numericValue: null,
        prefix: '',
        suffix: '',
      );
    }

    return _AnimatedValueSpec(
      rawValue: value,
      numericValue: parsedNumber,
      prefix: prefix,
      suffix: suffix,
    );
  }

  String format(int value) {
    if (numericValue == null) return rawValue;
    return '$prefix${_formatThousands(value)}$suffix';
  }

  static String _formatThousands(int number) {
    final digits = number.toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      if (index != 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[index]);
    }

    return buffer.toString();
  }
}

final RegExp _digitPattern = RegExp(r'\d');
