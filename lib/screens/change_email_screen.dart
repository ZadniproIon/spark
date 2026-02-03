import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../widgets/icon_button.dart';

class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  late final TextEditingController _currentEmailController;
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _newEmailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _autoValidate = false;
  bool _isSaving = false;
  String? _newEmailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    final email = ref.read(authControllerProvider).currentUser?.email ?? '';
    _currentEmailController = TextEditingController(text: email);
    _newEmailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _currentEmailController.dispose();
    _newEmailController.dispose();
    _passwordController.dispose();
    _newEmailFocus.dispose();
    _passwordFocus.dispose();
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

  bool _isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  bool _isValidInputs() {
    final currentEmail = _currentEmailController.text.trim();
    final newEmail = _newEmailController.text.trim();
    final password = _passwordController.text;
    if (currentEmail.isEmpty || !_supportsPassword()) {
      return false;
    }
    if (!_isValidEmail(newEmail) || newEmail == currentEmail) {
      return false;
    }
    if (password.isEmpty) {
      return false;
    }
    return true;
  }

  bool _validateAndSetErrors() {
    final currentEmail = _currentEmailController.text.trim();
    final newEmail = _newEmailController.text.trim();
    final password = _passwordController.text;
    String? newEmailError;
    String? passwordError;

    if (!_supportsPassword()) {
      passwordError = 'Email/password is not enabled for this account.';
    } else if (password.isEmpty) {
      passwordError = 'Password is required.';
    }

    if (currentEmail.isEmpty) {
      newEmailError = 'No email is associated with this account.';
    } else if (newEmail.isEmpty) {
      newEmailError = 'Enter a new email.';
    } else if (!_isValidEmail(newEmail)) {
      newEmailError = 'Enter a valid email.';
    } else if (newEmail == currentEmail) {
      newEmailError = 'New email must be different.';
    }

    setState(() {
      _newEmailError = newEmailError;
      _passwordError = passwordError;
    });

    return newEmailError == null && passwordError == null;
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
      final currentEmail = _currentEmailController.text.trim();
      final newEmail = _newEmailController.text.trim();
      final password = _passwordController.text;
      await auth.reauthenticateWithPassword(currentEmail, password);
      await auth.updateEmail(newEmail);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (error) {
      setState(() {
        if (error.code == 'wrong-password') {
          _passwordError = 'Incorrect password.';
        } else if (error.code == 'invalid-email') {
          _newEmailError = 'Enter a valid email.';
        } else if (error.code == 'email-already-in-use') {
          _newEmailError = 'Email is already in use.';
        } else if (error.code == 'requires-recent-login') {
          _passwordError = 'Please sign in again.';
        } else {
          _passwordError = 'Could not update email.';
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
                      label: 'Current email',
                      controller: _currentEmailController,
                      readOnly: true,
                      keyboardType: TextInputType.emailAddress,
                      textColor: colors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    _LabeledField(
                      label: 'New email',
                      controller: _newEmailController,
                      focusNode: _newEmailFocus,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _newEmailError,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        _passwordFocus.requestFocus();
                      },
                    ),
                    const SizedBox(height: 16),
                    _LabeledField(
                      label: 'Password confirmation',
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: true,
                      errorText: _passwordError,
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
