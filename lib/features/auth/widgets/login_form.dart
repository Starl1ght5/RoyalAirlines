import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/routes/app_routes.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/utils/validators.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/features/auth/widgets/social_login_buttons.dart';
import 'package:royal_airlines/services/auth_service.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';
import 'package:royal_airlines/shared/widgets/custom_textfield.dart';

/// LoginForm
/// ---------
/// El banner de error ahora usa un ícono en círculo rojo sólido en
/// vez de un ícono suelto — más llamativo. El link "Regístrate" usa
/// gradiente dorado sobre el texto.
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(AuthController auth) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await auth.login(
        email: _emailController.text, password: _passwordController.text);

    if (!mounted) return;
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);
    }
  }

  void _handleGuestAccess(BuildContext context) {
    context.read<AuthController>().continueAsGuest();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
  }

  void _showForgotPasswordSheet(BuildContext context) {
    final resetEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.xxl,
            right: AppSpacing.xxl,
            top: AppSpacing.xxl,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xxl,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2))),
                const Text('Recuperar contraseña',
                    style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 7),
                const Text(
                    'Ingresa tu correo y te enviaremos instrucciones para restablecer tu contraseña.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4)),
                const SizedBox(height: AppSpacing.xl),
                CustomTextField(
                    controller: resetEmailController,
                    label: 'Correo electrónico',
                    hint: 'tucorreo@ejemplo.com',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email),
                const SizedBox(height: AppSpacing.xl),
                CustomButton(
                  label: 'Enviar instrucciones',
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await context.read<AuthController>().requestPasswordReset(
                            email: resetEmailController.text,
                          );
                    } on AuthException catch (e) {
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                          content: Text(e.message),
                          backgroundColor: AppColors.error));
                      return;
                    }
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Si el correo existe, recibirás instrucciones para restablecer tu contraseña.'),
                        backgroundColor: AppColors.primary));
                  },
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(resetEmailController.dispose);
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
              if (auth.status == AuthStatus.error)
                _ErrorBanner(message: auth.errorMessage!),
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
                  hint: 'Ingresa tu contraseña',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => Validators.password(v)),
              const SizedBox(height: AppSpacing.sm + 2),
              _RememberAndForgotRow(
                  auth: auth,
                  onForgotPassword: () => _showForgotPasswordSheet(context)),
              const SizedBox(height: AppSpacing.xxl + 4),
              CustomButton(
                  label: 'Iniciar sesión',
                  isLoading: auth.isLoading,
                  onPressed: () => _handleLogin(auth)),
              const SizedBox(height: AppSpacing.xl),
              SocialLoginButtons(
                onSuccess: () =>
                    Navigator.of(context).pushReplacementNamed(AppRoutes.main),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: TextButton(
                  onPressed: () => _handleGuestAccess(context),
                  child: const Text('Explorar sin cuenta',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline)),
                ),
              ),
              const SizedBox(height: AppSpacing.xl + 4),
              const _RegisterLink(),
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

class _RememberAndForgotRow extends StatelessWidget {
  final AuthController auth;
  final VoidCallback onForgotPassword;

  const _RememberAndForgotRow(
      {required this.auth, required this.onForgotPassword});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              SizedBox(
                width: 21,
                height: 21,
                child: Checkbox(
                    value: auth.rememberMe,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    onChanged: (value) =>
                        auth.toggleRememberMe(value ?? false)),
              ),
              const SizedBox(width: 8),
              const Text('Recordarme',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Flexible(
          child: TextButton(
            onPressed: onForgotPassword,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('¿Olvidaste tu contraseña?',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ),
      ],
    );
  }
}

class _RegisterLink extends StatelessWidget {
  const _RegisterLink();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          style:
              const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          children: [
            const TextSpan(text: '¿No tienes cuenta? '),
            TextSpan(
              text: 'Regístrate',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800),
              recognizer: TapGestureRecognizer()
                ..onTap =
                    () => Navigator.of(context).pushNamed(AppRoutes.register),
            ),
          ],
        ),
      ),
    );
  }
}
