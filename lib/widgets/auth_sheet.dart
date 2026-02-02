import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth({required bool isSignIn}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authControllerProvider);
      if (isSignIn) {
        await auth.signInWithEmail(email, password);
      } else {
        await auth.registerWithEmail(email, password);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: colors.border),
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
            const SizedBox(height: 16),
            _AuthField(
              controller: _emailController,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _AuthField(
              controller: _passwordController,
              hintText: 'Password',
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTextStyles.secondary.copyWith(
                  color: colors.red,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AuthActionButton(
                    label: 'Sign in',
                    onTap: _isLoading
                        ? null
                        : () => _handleEmailAuth(isSignIn: true),
                    haptic: HapticLevel.medium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AuthActionButton(
                    label: 'Create account',
                    onTap: _isLoading
                        ? null
                        : () => _handleEmailAuth(isSignIn: false),
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
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.secondary.copyWith(
            color: colors.textSecondary,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: AppTextStyles.primary.copyWith(
          color: colors.textPrimary,
          height: 1.2,
        ),
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
        duration: const Duration(milliseconds: 150),
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
                style: AppTextStyles.button.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
