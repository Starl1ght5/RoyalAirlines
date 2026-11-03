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

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthController>().updateProfile(
            fullName: _nameController.text,
            email: _emailController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado'),
          backgroundColor: AppColors.success,
        ),
      );
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                      icon: Icons.edit_outlined,
                      title: 'Editar perfil',
                      description:
                          'Actualiza tus datos personales con un layout más claro y cómodo para completar.',
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
                      controller: _nameController,
                      label: 'Nombre completo',
                      hint: 'Tu nombre y apellido',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          Validators.required(v, fieldName: 'El nombre'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(
                    index: 2,
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
                    index: 3,
                    child: _HintCard(
                      icon: Icons.tips_and_updates_outlined,
                      message:
                          'Tus cambios se aplicarán a la información visible de tu cuenta.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FadeSlideIn(
                    index: 4,
                    child: CustomButton(
                      label: 'Guardar cambios',
                      icon: Icons.save_outlined,
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
