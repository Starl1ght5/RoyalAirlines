import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/animations/app_motion.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/validators.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';
import 'package:royal_airlines/shared/widgets/custom_textfield.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthController>().changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada'),
          backgroundColor: AppColors.success,
        ),
      );
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openRecoverySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => const _RecoverPasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
            boxShadow: AppShadows.floating,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.xxl,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const FadeSlideIn(
                    child: _SheetHeader(
                      icon: Icons.shield_outlined,
                      title: 'Cambiar contraseña',
                      description:
                          'Refuerza el acceso a tu cuenta con un flujo más claro y consistente.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AnimatedSwitcher(
                    duration: AppMotion.fast,
                    switchInCurve: AppMotion.standard,
                    switchOutCurve: AppMotion.standard,
                    child: _errorMessage == null
                        ? const SizedBox.shrink(key: ValueKey('empty-error'))
                        : Padding(
                            key: ValueKey(_errorMessage),
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.lg),
                            child: _ErrorBanner(message: _errorMessage!),
                          ),
                  ),
                  FadeSlideIn(
                    index: 1,
                    child: CustomTextField(
                      controller: _currentPasswordController,
                      label: 'Contraseña actual',
                      hint: 'Ingresa tu contraseña actual',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => Validators.password(v),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FadeSlideIn(
                    index: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _openRecoverySheet,
                        icon: const Icon(
                          Icons.help_outline_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'No recuerdo la contraseña actual',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          minimumSize: const Size(0, AppSpacing.minTouchTarget),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FadeSlideIn(
                    index: 3,
                    child: CustomTextField(
                      controller: _newPasswordController,
                      label: 'Nueva contraseña',
                      hint: 'Mínimo 8 caracteres',
                      icon: Icons.lock_reset_rounded,
                      isPassword: true,
                      validator: (v) => Validators.password(v, minLength: 8),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(
                    index: 4,
                    child: CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar nueva contraseña',
                      hint: 'Repite la nueva contraseña',
                      icon: Icons.verified_user_outlined,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Confirma tu nueva contraseña';
                        }
                        if (v != _newPasswordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const FadeSlideIn(
                    index: 5,
                    child: _HintCard(
                      icon: Icons.privacy_tip_outlined,
                      message:
                          'Usa una contraseña única para mantener mejor protegida tu cuenta.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FadeSlideIn(
                    index: 6,
                    child: CustomButton(
                      label: 'Actualizar contraseña',
                      icon: Icons.shield_rounded,
                      isLoading: _isSaving,
                      onPressed: _handleSave,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoverPasswordSheet extends StatefulWidget {
  const _RecoverPasswordSheet();

  @override
  State<_RecoverPasswordSheet> createState() => _RecoverPasswordSheetState();
}

class _RecoverPasswordSheetState extends State<_RecoverPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthController>().requestPasswordReset(
            email: _emailController.text,
          );
      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Si el correo existe, recibirás instrucciones para restablecer tu contraseña.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
            boxShadow: AppShadows.floating,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.xxl,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const FadeSlideIn(
                    child: _SheetHeader(
                      icon: Icons.mail_lock_outlined,
                      title: 'Verificar identidad',
                      description:
                          'Ingresa tu correo y te enviaremos instrucciones para recuperar el acceso.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AnimatedSwitcher(
                    duration: AppMotion.fast,
                    switchInCurve: AppMotion.standard,
                    switchOutCurve: AppMotion.standard,
                    child: _errorMessage == null
                        ? const SizedBox.shrink(key: ValueKey('empty-error'))
                        : Padding(
                            key: ValueKey(_errorMessage),
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.lg),
                            child: _ErrorBanner(message: _errorMessage!),
                          ),
                  ),
                  FadeSlideIn(
                    index: 1,
                    child: CustomTextField(
                      controller: _emailController,
                      label: 'Correo electrónico',
                      hint: 'tucorreo@ejemplo.com',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: Validators.email,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const FadeSlideIn(
                    index: 2,
                    child: _HintCard(
                      icon: Icons.info_outline_rounded,
                      message:
                          'Solo necesitas acceso a tu correo para continuar con la recuperación.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FadeSlideIn(
                    index: 3,
                    child: CustomButton.secondary(
                      label: 'Enviar instrucciones',
                      icon: Icons.mark_email_read_rounded,
                      isLoading: _isSending,
                      onPressed: _handleSend,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SheetHeader({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: AppShadows.card,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.goldLight, size: 24),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HintCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
