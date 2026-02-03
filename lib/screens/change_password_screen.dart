import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../widgets/icon_button.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FocusNode _currentFocus = FocusNode();
  final FocusNode _newFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  bool _autoValidate = false;
  bool _isSaving = false;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _currentPasswordController.addListener(_onFieldChanged);
    _newPasswordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_autoValidate) {
      _validateAndSetErrors();
    } else {
      setState(() {});
    }
  }

  bool _supportsPassword() {
    final user = ref.read(authControllerProvider).currentUser;
    return user?.providerData.any((p) => p.providerId == 'password') ?? false;
  }

  bool _isValidInputs() {
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (!_supportsPassword()) return false;
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) return false;
    if (next.length < 6) return false;
    if (next != confirm) return false;
    return true;
  }

  bool _validateAndSetErrors() {
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    String? currentError;
    String? newError;
    String? confirmError;

    if (!_supportsPassword()) {
      currentError = 'Email/password is not enabled for this account.';
    } else if (current.isEmpty) {
      currentError = 'Current password is required.';
    }

    if (next.isEmpty) {
      newError = 'New password is required.';
    } else if (next.length < 6) {
      newError = 'Password must be at least 6 characters.';
    }

    if (confirm.isEmpty) {
      confirmError = 'Please confirm your new password.';
    } else if (confirm != next) {
      confirmError = 'Passwords do not match.';
    }

    setState(() {
      _currentPasswordError = currentError;
      _newPasswordError = newError;
      _confirmPasswordError = confirmError;
    });

    return currentError == null && newError == null && confirmError == null;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _autoValidate = true;
    });
    if (!_validateAndSetErrors()) {
      return;
    }

    setState(() => _isSaving = true);
    final auth = ref.read(authControllerProvider);
    try {
      final email = auth.currentUser?.email ?? '';
      final current = _currentPasswordController.text;
      final next = _newPasswordController.text;
      await auth.reauthenticateWithPassword(email, current);
      await auth.updatePassword(next);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (error) {
      setState(() {
        if (error.code == 'wrong-password') {
          _currentPasswordError = 'Incorrect password.';
        } else if (error.code == 'weak-password') {
          _newPasswordError = 'Password is too weak.';
        } else if (error.code == 'requires-recent-login') {
          _currentPasswordError = 'Please sign in again.';
        } else {
          _currentPasswordError = 'Could not update password.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    final canSubmit = _isValidInputs() && !_isSaving;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
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
                  SparkIconButton(
                    icon: LucideIcons.check,
                    onPressed: canSubmit ? _save : null,
                    isCircular: true,
                    borderColor: colors.border,
                    backgroundColor: colors.bgCard,
                    iconColor: colors.textPrimary,
                    haptic: HapticLevel.medium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _LabeledField(
                      label: 'Current password',
                      controller: _currentPasswordController,
                      focusNode: _currentFocus,
                      obscureText: true,
                      errorText: _currentPasswordError,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        _newFocus.requestFocus();
                      },
                    ),
                    const SizedBox(height: 16),
                    _LabeledField(
                      label: 'New password',
                      controller: _newPasswordController,
                      focusNode: _newFocus,
                      obscureText: true,
                      errorText: _newPasswordError,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        _confirmFocus.requestFocus();
                      },
                    ),
                    const SizedBox(height: 16),
                    _LabeledField(
                      label: 'Confirm new password',
                      controller: _confirmPasswordController,
                      focusNode: _confirmFocus,
                      obscureText: true,
                      errorText: _confirmPasswordError,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.obscureText = false,
    this.errorText,
    this.textColor,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;
  final bool obscureText;
  final String? errorText;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    final labelStyle = AppTextStyles.primary.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: colors.textPrimary,
    );
    final fieldStyle = AppTextStyles.primary.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textColor ?? colors.textPrimary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            readOnly: readOnly,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: obscureText,
            onSubmitted: onFieldSubmitted,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: fieldStyle,
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: AppTextStyles.secondary.copyWith(
              fontSize: 12,
              color: colors.red,
            ),
          ),
        ],
      ],
    );
  }
}
