import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// SocialLoginButtons
/// ------------------
/// Botones de login con Google y Apple. El flujo es REAL:
/// 1. Abre el diálogo nativo del proveedor (Google Sign-In /
///    Sign in with Apple).
/// 2. Envía el `identityToken` (JWT) al backend (`POST /auth/google` o
///    `POST /auth/apple`), que lo verifica y devuelve la sesión.
/// 3. Al exito llama [onSuccess] para navegar igual que el login normal.
///
/// Si el usuario cancela el diálogo, no ocurre nada (sin error). Los
/// errores del backend se muestran junto a estos botones, sin pisar el
/// banner del login ni el del registro.
class SocialLoginButtons extends StatefulWidget {
  const SocialLoginButtons({super.key, required this.onSuccess});

  /// Se invoca cuando el backend YA devolvió sesión (usuario logueado).
  final VoidCallback onSuccess;

  @override
  State<SocialLoginButtons> createState() => _SocialLoginButtonsState();
}

class _SocialLoginButtonsState extends State<SocialLoginButtons> {
  String? _activeProvider; // 'google' | 'apple' | null

  Future<void> _handle(AuthController auth, String provider) async {
    if (auth.isSocialLoading) return;
    setState(() => _activeProvider = provider);

    if (provider == 'google') {
      await auth.loginWithGoogle();
    } else {
      await auth.loginWithApple();
    }

    if (!mounted) return;
    setState(() => _activeProvider = null);
    if (auth.isAuthenticated) widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final loading = auth.isSocialLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DividerRow(label: 'o continúa con'),
            const SizedBox(height: AppSpacing.lg),
            CustomButton.secondary(
              label: 'Continuar con Google',
              icon: Icons.g_mobiledata_rounded,
              isLoading: loading && _activeProvider == 'google',
              onPressed: loading ? null : () => _handle(auth, 'google'),
            ),
            const SizedBox(height: AppSpacing.lg),
            CustomButton.secondary(
              label: 'Continuar con Apple',
              icon: Icons.apple,
              isLoading: loading && _activeProvider == 'apple',
              onPressed: loading ? null : () => _handle(auth, 'apple'),
            ),
            if (auth.socialErrorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorText(message: auth.socialErrorMessage!),
            ],
          ],
        );
      },
    );
  }
}

class _DividerRow extends StatelessWidget {
  final String label;
  const _DividerRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: AppColors.border,
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 15,
          color: AppColors.error,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
