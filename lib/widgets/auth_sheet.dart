import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../utils/motion.dart';
import 'loading_overlay.dart';

Future<void> showAuthSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AuthSheet(),
  );
}

Future<void> showPasswordRecoverySheet(BuildContext context) async {
  final colors = context.sparkColors;
  final messenger = ScaffoldMessenger.of(context);
  final didUpdate = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PasswordRecoverySheet(),
  );

  if (didUpdate == true && context.mounted) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Password updated.',
          style: AppTextStyles.secondary.copyWith(color: colors.textPrimary),
        ),
        backgroundColor: colors.bgCard,
      ),
    );
  }
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
      await withLoadingOverlay(
        context,
        label: 'Signing in',
        action: () => ref.read(authControllerProvider).signInWithGoogle(),
      );
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

  Future<void> _handleForgotPassword() async {
    final colors = context.sparkColors;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email first to reset password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await withLoadingOverlay(
        context,
        label: 'Sending reset email',
        action: () => ref
            .read(authControllerProvider)
            .sendPasswordResetEmail(email: email),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset email sent. Open the link, then set a new password.',
            style: AppTextStyles.secondary.copyWith(color: colors.textPrimary),
          ),
          backgroundColor: colors.bgCard,
        ),
      );
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
      await withLoadingOverlay(
        context,
        label: signUp ? 'Creating account' : 'Signing in',
        action: () async {
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
        },
      );

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
              Center(
                child: Text(
                  'Sign in',
                  style: AppTextStyles.section.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTextStyles.secondary.copyWith(color: colors.red),
                ),
              ],
              const SizedBox(height: 8),
              _AuthInputField(
                controller: _emailController,
                hintText: 'Email',
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _handleForgotPassword,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: AppTextStyles.secondary.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              Divider(height: 1, thickness: 1, color: colors.border),
              const SizedBox(height: 8),
              _AuthActionButton(
                iconWidget: const _GoogleIcon(),
                label: 'Continue with Google',
                onTap: _isLoading ? null : _handleGoogle,
                haptic: HapticLevel.medium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRecoverySheet extends ConsumerStatefulWidget {
  const _PasswordRecoverySheet();

  @override
  ConsumerState<_PasswordRecoverySheet> createState() =>
      _PasswordRecoverySheetState();
}

class _PasswordRecoverySheetState
    extends ConsumerState<_PasswordRecoverySheet> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _friendlyRecoveryError(Object error) {
    if (error is AuthApiException) {
      final code = error.code?.toLowerCase() ?? '';
      final message = error.message.toLowerCase();

      if (code == 'weak_password' || message.contains('weak password')) {
        return 'Password is too weak. Try a stronger password.';
      }
      if (code == 'same_password' || message.contains('same password')) {
        return 'New password must be different from the current password.';
      }
      if (message.contains('expired') || message.contains('invalid token')) {
        return 'Recovery link expired. Request a new password reset email.';
      }
      return error.message;
    }

    if (error is AuthException && error.message.isNotEmpty) {
      return error.message;
    }

    return 'Something went wrong. Please try again.';
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.length < 8) {
      setState(() => _error = 'Use at least 8 characters for password.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider).updatePassword(password: password);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyRecoveryError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
              Center(
                child: Text(
                  'Set new password',
                  style: AppTextStyles.section.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _AuthInputField(
                controller: _passwordController,
                hintText: 'New password',
                obscureText: _obscurePassword,
                enabled: !_isSaving,
                trailing: GestureDetector(
                  onTap: _isSaving
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
              const SizedBox(height: 8),
              _AuthInputField(
                controller: _confirmController,
                hintText: 'Confirm new password',
                obscureText: _obscureConfirm,
                enabled: !_isSaving,
                trailing: GestureDetector(
                  onTap: _isSaving
                      ? null
                      : () {
                          triggerHapticFromContext(
                            context,
                            HapticLevel.selection,
                          );
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _obscureConfirm ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: AppTextStyles.secondary.copyWith(color: colors.red),
                ),
              ],
              const SizedBox(height: 16),
              _AuthActionButton(
                icon: LucideIcons.check,
                label: _isSaving ? 'Saving...' : 'Save password',
                onTap: _isSaving ? null : _submit,
                haptic: HapticLevel.medium,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(8),
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
                  height: 1.2,
                ),
              ),
              style: AppTextStyles.primary.copyWith(
                color: colors.textPrimary,
                height: 1.2,
              ),
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
    this.iconWidget,
    this.onTap,
    this.haptic = HapticLevel.light,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final HapticLevel haptic;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return AnimatedOpacity(
      opacity: onTap == null ? 0.6 : 1,
      duration: Motion.fast,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap == null
                ? null
                : () {
                    triggerHapticFromContext(context, haptic);
                    onTap?.call();
                  },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconWidget != null) ...[
                    iconWidget!,
                    const SizedBox(width: 8),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 20, color: colors.textPrimary),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.button.copyWith(
                      color: colors.textPrimary,
                      height: 1.2,
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

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: const [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GoogleIconPathPainter(
                    'M43.611,20.083H42V20H24v8h11.303c-1.649,4.657-6.08,8-11.303,8c-6.627,0-12-5.373-12-12c0-6.627,5.373-12,12-12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C12.955,4,4,12.955,4,24c0,11.045,8.955,20,20,20c11.045,0,20-8.955,20-20C44,22.659,43.862,21.35,43.611,20.083z',
                    Color(0xFFFFC107),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _GoogleIconPathPainter(
                    'M6.306,14.691l6.571,4.819C14.655,15.108,18.961,12,24,12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C16.318,4,9.656,8.337,6.306,14.691z',
                    Color(0xFFFF3D00),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _GoogleIconPathPainter(
                    'M24,44c5.166,0,9.86-1.977,13.409-5.192l-6.19-5.238C29.211,35.091,26.715,36,24,36c-5.202,0-9.619-3.317-11.283-7.946l-6.522,5.025C9.505,39.556,16.227,44,24,44z',
                    Color(0xFF4CAF50),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _GoogleIconPathPainter(
                    'M43.611,20.083H42V20H24v8h11.303c-0.792,2.237-2.231,4.166-4.087,5.571c0.001-0.001,0.002-0.001,0.003-0.002l6.19,5.238C36.971,39.205,44,34,44,24C44,22.659,43.862,21.35,43.611,20.083z',
                    Color(0xFF1976D2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleIconPathPainter extends CustomPainter {
  const _GoogleIconPathPainter(this.pathData, this.color);

  final String pathData;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 48;
    final scaleY = size.height / 48;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    final path = _SvgPathParser(pathData).parse();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleIconPathPainter oldDelegate) {
    return oldDelegate.pathData != pathData || oldDelegate.color != color;
  }
}

class _SvgPathParser {
  _SvgPathParser(this._input);

  final String _input;
  int _index = 0;
  late String _command;
  final Path _path = Path();
  Offset _current = Offset.zero;
  Offset _start = Offset.zero;
  Offset _lastControl = Offset.zero;
  bool _hasLastControl = false;

  Path parse() {
    while (_skipSeparators()) {
      final char = _peek();
      if (_isCommand(char)) {
        _command = _next();
      } else if (_command.isEmpty) {
        throw FormatException('Invalid path data near index $_index');
      }
      _readCommand();
    }
    return _path;
  }

  void _readCommand() {
    switch (_command) {
      case 'M':
      case 'm':
        _readMoveTo(relative: _command == 'm');
        break;
      case 'L':
      case 'l':
        _readLineTo(relative: _command == 'l');
        break;
      case 'H':
      case 'h':
        _readHorizontalTo(relative: _command == 'h');
        break;
      case 'V':
      case 'v':
        _readVerticalTo(relative: _command == 'v');
        break;
      case 'C':
      case 'c':
        _readCubicTo(relative: _command == 'c');
        break;
      case 'S':
      case 's':
        _readSmoothCubicTo(relative: _command == 's');
        break;
      case 'Z':
      case 'z':
        _path.close();
        _current = _start;
        _hasLastControl = false;
        break;
      default:
        throw FormatException('Unsupported SVG command: $_command');
    }
  }

  void _readMoveTo({required bool relative}) {
    final first = _readPoint(relative: relative);
    _path.moveTo(first.dx, first.dy);
    _current = first;
    _start = first;
    _hasLastControl = false;

    while (_hasNumberAhead()) {
      final point = _readPoint(relative: relative);
      _path.lineTo(point.dx, point.dy);
      _current = point;
    }
  }

  void _readLineTo({required bool relative}) {
    while (_hasNumberAhead()) {
      final point = _readPoint(relative: relative);
      _path.lineTo(point.dx, point.dy);
      _current = point;
    }
    _hasLastControl = false;
  }

  void _readHorizontalTo({required bool relative}) {
    while (_hasNumberAhead()) {
      final x = _readNumber();
      final target = Offset(relative ? _current.dx + x : x, _current.dy);
      _path.lineTo(target.dx, target.dy);
      _current = target;
    }
    _hasLastControl = false;
  }

  void _readVerticalTo({required bool relative}) {
    while (_hasNumberAhead()) {
      final y = _readNumber();
      final target = Offset(_current.dx, relative ? _current.dy + y : y);
      _path.lineTo(target.dx, target.dy);
      _current = target;
    }
    _hasLastControl = false;
  }

  void _readCubicTo({required bool relative}) {
    while (_hasNumberAhead()) {
      final c1 = _readPoint(relative: relative);
      final c2 = _readPoint(relative: relative);
      final end = _readPoint(relative: relative);
      _path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      _current = end;
      _lastControl = c2;
      _hasLastControl = true;
    }
  }

  void _readSmoothCubicTo({required bool relative}) {
    while (_hasNumberAhead()) {
      final reflected = _hasLastControl
          ? Offset(
              2 * _current.dx - _lastControl.dx,
              2 * _current.dy - _lastControl.dy,
            )
          : _current;
      final c2 = _readPoint(relative: relative);
      final end = _readPoint(relative: relative);
      _path.cubicTo(reflected.dx, reflected.dy, c2.dx, c2.dy, end.dx, end.dy);
      _current = end;
      _lastControl = c2;
      _hasLastControl = true;
    }
  }

  Offset _readPoint({required bool relative}) {
    final x = _readNumber();
    final y = _readNumber();
    if (relative) {
      return Offset(_current.dx + x, _current.dy + y);
    }
    return Offset(x, y);
  }

  bool _skipSeparators() {
    while (_index < _input.length) {
      final c = _input.codeUnitAt(_index);
      if (c == 32 || c == 44 || c == 10 || c == 13 || c == 9) {
        _index++;
      } else {
        break;
      }
    }
    return _index < _input.length;
  }

  bool _hasNumberAhead() {
    if (!_skipSeparators()) return false;
    final char = _peek();
    if (_isCommand(char)) return false;
    return true;
  }

  double _readNumber() {
    _skipSeparators();
    final start = _index;
    if (_peek() == '+' || _peek() == '-') {
      _index++;
    }
    while (_index < _input.length && _isDigit(_input.codeUnitAt(_index))) {
      _index++;
    }
    if (_index < _input.length && _input.codeUnitAt(_index) == 46) {
      _index++;
      while (_index < _input.length && _isDigit(_input.codeUnitAt(_index))) {
        _index++;
      }
    }
    if (_index < _input.length &&
        (_input.codeUnitAt(_index) == 69 || _input.codeUnitAt(_index) == 101)) {
      _index++;
      if (_peek() == '+' || _peek() == '-') {
        _index++;
      }
      while (_index < _input.length && _isDigit(_input.codeUnitAt(_index))) {
        _index++;
      }
    }
    final token = _input.substring(start, _index);
    return double.parse(token);
  }

  String _peek() => _input[_index];
  String _next() => _input[_index++];

  bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
  bool _isCommand(String c) => 'MmLlHhVvCcSsZz'.contains(c);
}
