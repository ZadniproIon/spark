import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../utils/motion.dart';
import 'icon_button.dart';

Future<void> showAuthSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AuthSheet(),
  );
}

class AuthSheet extends ConsumerStatefulWidget {
  const AuthSheet({super.key});

  @override
  ConsumerState<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends ConsumerState<AuthSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyAuthError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleEmailSignIn() async {
    await _handleEmailAuth(signUp: false);
  }

  Future<void> _handleEmailSignUp() async {
    await _handleEmailAuth(signUp: true);
  }

  Future<void> _handleEmailAuth({required bool signUp}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (signUp) {
        await ref
            .read(authControllerProvider)
            .signUpWithEmail(email: email, password: password);

        final authController = ref.read(authControllerProvider);
        if (authController.currentUser == null) {
          try {
            await authController.signInWithEmail(
              email: email,
              password: password,
            );
          } catch (_) {
            // If email confirmation is enabled (or any sign-in restriction applies),
            // fall back to the informational message below.
          }
        }
      } else {
        await ref
            .read(authControllerProvider)
            .signInWithEmail(email: email, password: password);
      }

      if (!mounted) {
        return;
      }

      final isSignedInNow =
          ref.read(authControllerProvider).currentUser != null;
      if (isSignedInNow) {
        Navigator.of(context).pop();
      } else if (signUp) {
        setState(() {
          _error =
              'Account created. If email confirmation is enabled, check your inbox.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyAuthError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyAuthError(Object error) {
    if (error is AuthApiException) {
      final code = error.code?.toLowerCase() ?? '';
      final message = error.message.toLowerCase();

      if (code == 'invalid_credentials' ||
          code == 'invalid_login_credentials' ||
          message.contains('invalid login credentials')) {
        return 'Invalid email or password.';
      }

      if (code == 'user_already_exists' ||
          message.contains('user already registered')) {
        return 'An account with this email already exists.';
      }

      if (code == 'email_not_confirmed' ||
          message.contains('email not confirmed')) {
        return 'Please confirm your email before signing in.';
      }

      if (code == 'signup_disabled' ||
          message.contains('signups not allowed')) {
        return 'Email sign-up is currently disabled.';
      }

      if (code == 'weak_password' || message.contains('weak password')) {
        return 'Password is too weak. Try a stronger password.';
      }

      if (code == 'email_address_invalid' ||
          (message.contains('email') && message.contains('invalid'))) {
        return 'Please enter a valid email address.';
      }

      if (message.contains('rate limit') || message.contains('too many')) {
        return 'Too many attempts. Please wait a bit and try again.';
      }

      return error.message;
    }

    if (error is AuthException && error.message.isNotEmpty) {
      return error.message;
    }

    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.toLowerCase().contains('network')) {
      return 'Network error. Check your connection and try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      bottom: false,
      child: AnimatedPadding(
        duration: Motion.keyboard,
        curve: Motion.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + safeBottom),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SparkIconButton(
                    icon: LucideIcons.x,
                    onPressed: () => Navigator.of(context).pop(),
                    isCircular: true,
                    borderColor: colors.border,
                    backgroundColor: colors.bgCard,
                    iconColor: colors.textPrimary,
                    haptic: HapticLevel.light,
                  ),
                  const Spacer(),
                  Text(
                    'Sign in',
                    style: AppTextStyles.section.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Guest notes merge into your account when you sign in.',
                textAlign: TextAlign.center,
                style: AppTextStyles.secondary.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTextStyles.secondary.copyWith(color: colors.red),
                ),
              ],
              const SizedBox(height: 16),
              _AuthInputField(
                controller: _emailController,
                hintText: 'Email',
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 12),
              _AuthInputField(
                controller: _passwordController,
                hintText: 'Password',
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                trailing: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          triggerHapticFromContext(
                            context,
                            HapticLevel.selection,
                          );
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AuthActionButton(
                      icon: LucideIcons.logIn,
                      label: 'Sign in',
                      onTap: _isLoading ? null : _handleEmailSignIn,
                      haptic: HapticLevel.medium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AuthActionButton(
                      icon: LucideIcons.userPlus,
                      label: 'Create',
                      onTap: _isLoading ? null : _handleEmailSignUp,
                      haptic: HapticLevel.medium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AuthActionButton(
                icon: LucideIcons.globe,
                label: 'Continue with Google',
                onTap: _isLoading ? null : _handleGoogle,
                haptic: HapticLevel.medium,
              ),
              if (_isLoading) ...[
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthInputField extends StatelessWidget {
  const _AuthInputField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              obscureText: obscureText,
              autocorrect: false,
              enableSuggestions: !obscureText,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isDense: true,
                hintStyle: AppTextStyles.secondary.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              style: AppTextStyles.primary.copyWith(color: colors.textPrimary),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _AuthActionButton extends StatelessWidget {
  const _AuthActionButton({
    required this.label,
    this.icon,
    this.onTap,
    this.haptic = HapticLevel.light,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final HapticLevel haptic;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              triggerHapticFromContext(context, haptic);
              onTap?.call();
            },
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.6 : 1,
        duration: Motion.fast,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: colors.textPrimary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTextStyles.button.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
