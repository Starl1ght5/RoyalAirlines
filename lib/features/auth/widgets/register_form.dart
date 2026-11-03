import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/routes/app_routes.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/utils/validators.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/features/auth/widgets/social_login_buttons.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';
import 'package:royal_airlines/shared/widgets/custom_textfield.dart';

/// RegisterForm
/// ------------
/// Mismo tratamiento visual que [LoginForm]: banner de error con
/// círculo sólido, checkbox de términos con acento dorado en el error.
class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _acceptedTerms = false;
  bool _showTermsError = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister(AuthController auth) async {
    FocusScope.of(context).unfocus();

    final bool isFormValid = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_acceptedTerms);

    if (!isFormValid || !_acceptedTerms) return;

    await auth.register(
      fullName: _fullNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (auth.registerStatus == AuthStatus.success) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (auth.registerStatus == AuthStatus.error)
                _ErrorBanner(message: auth.registerErrorMessage!),
              CustomTextField(
                  controller: _fullNameController,
                  label: 'Nombre completo',
                  hint: 'Tu nombre y apellido',
                  icon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      Validators.required(v, fieldName: 'El nombre')),
              const SizedBox(height: AppSpacing.lg),
              CustomTextField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  hint: 'tucorreo@ejemplo.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email),
              const SizedBox(height: AppSpacing.lg),
              CustomTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  hint: 'Mínimo 8 caracteres',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) => Validators.password(v, minLength: 8)),
              const SizedBox(height: AppSpacing.lg),
              CustomTextField(
                controller: _confirmPasswordController,
                label: 'Confirmar contraseña',
                hint: 'Repite tu contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                  if (v != _passwordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _TermsCheckbox(
                value: _acceptedTerms,
                showError: _showTermsError,
                onChanged: (value) {
                  setState(() {
                    _acceptedTerms = value;
                    if (value) _showTermsError = false;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              CustomButton(
                  label: 'Crear cuenta',
                  isLoading: auth.isRegisterLoading,
                  onPressed: () => _handleRegister(auth)),
              const SizedBox(height: AppSpacing.xl),
              SocialLoginButtons(
                onSuccess: () =>
                    Navigator.of(context).pushReplacementNamed(AppRoutes.main),
              ),
              const SizedBox(height: AppSpacing.xl + 4),
              const _LoginLink(),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                  color: AppColors.error, shape: BoxShape.circle),
              child: const Icon(Icons.priority_high_rounded,
                  color: AppColors.textOnPrimary, size: 17)),
          const SizedBox(width: 11),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox(
      {required this.value, required this.showError, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: showError
                ? AppColors.error.withValues(alpha: 0.05)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: showError
                    ? AppColors.error.withValues(alpha: 0.4)
                    : Colors.transparent),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 21,
                height: 21,
                child: Checkbox(
                    value: value,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    onChanged: (v) => onChanged(v ?? false)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4),
                      children: [
                        TextSpan(text: 'Acepto los '),
                        TextSpan(
                            text: 'Términos y Condiciones',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                        TextSpan(text: ' y la '),
                        TextSpan(
                            text: 'Política de Privacidad',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                        TextSpan(text: ' de Royal Airlines'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showError)
          const Padding(
            padding: EdgeInsets.only(left: 6, top: 6),
            child: Text('Debes aceptar los términos para continuar',
                style: TextStyle(
                    color: AppColors.error,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _LoginLink extends StatelessWidget {
  const _LoginLink();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          style:
              const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          children: [
            const TextSpan(text: '¿Ya tienes cuenta? '),
            TextSpan(
              text: 'Inicia sesión',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800),
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
