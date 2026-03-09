import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/haptics_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../utils/motion.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/loading_overlay.dart';
import 'recycle_bin_screen.dart';

String _friendlyAccountError(Object error) {
  if (error is AuthApiException) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();

    if (code == 'weak_password' || message.contains('weak password')) {
      return 'Password is too weak. Try a stronger password.';
    }
    if (code == 'same_password' || message.contains('same password')) {
      return 'New password must be different from the current password.';
    }
    if (code == 'email_address_invalid' ||
        (message.contains('email') && message.contains('invalid'))) {
      return 'Please enter a valid email address.';
    }
    if (message.contains('reauthentication') ||
        code == 'reauthentication_needed') {
      return 'Please sign in again, then retry this action.';
    }
    if (code == 'single_identity_not_deletable' ||
        message.contains('only sign-in method') ||
        message.contains('at least two identities') ||
        message.contains('only identity')) {
      return 'Google cannot be disconnected because it is the only sign-in method.';
    }
    if (message.contains('manual linking')) {
      return 'Google disconnect is not enabled on the server.';
    }
    if (message.contains('identity') && message.contains('not found')) {
      return 'Google sign-in is already disconnected.';
    }
    return error.message;
  }

  if (error is AuthException && error.message.isNotEmpty) {
    return error.message;
  }

  return 'Something went wrong. Please try again.';
}

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  bool _hasGoogleIdentity(User user) {
    final identities = user.identities;
    if (identities != null &&
        identities.any(
          (identity) => identity.provider.toLowerCase() == 'google',
        )) {
      return true;
    }

    final providers = user.appMetadata['providers'];
    if (providers is List &&
        providers.any(
          (provider) => provider.toString().toLowerCase() == 'google',
        )) {
      return true;
    }

    final primaryProvider = user.appMetadata['provider']
        ?.toString()
        .toLowerCase();
    return primaryProvider == 'google';
  }

  String _authProviderLabel(User user) {
    final provider = user.appMetadata['provider']?.toString().toLowerCase();
    switch (provider) {
      case 'google':
        return 'Google';
      case 'email':
        return 'Email + password';
      default:
        return 'Signed-in account';
    }
  }

  String _accountSubtitleForUser(User user) {
    final providerLabel = _authProviderLabel(user);
    final email = user.email;
    if (email == null || email.isEmpty) {
      return providerLabel;
    }
    return '$providerLabel • $email';
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendFeedback(
    BuildContext context,
    WidgetRef ref, {
    required String subject,
    required String template,
  }) async {
    final colors = context.sparkColors;
    String deviceInfo = 'Device: Unknown';
    String osInfo = 'OS: Unknown';
    String appInfo = 'App: Unknown';
    String userInfo = 'User: Unknown';
    // Locale/timezone intentionally omitted.
    try {
      final info = DeviceInfoPlugin();
      final android = await info.androidInfo;
      deviceInfo = 'Device: ${android.manufacturer} ${android.model}';
      osInfo =
          'OS: Android ${android.version.release} (SDK ${android.version.sdkInt})';
    } catch (_) {
      // Ignore and fallback to unknown.
    }
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appInfo = 'App: ${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (_) {
      // Ignore and fallback to unknown.
    }

    final authState = ref.read(authStateProvider);
    final user = authState.valueOrNull;
    userInfo = user == null ? 'User: Guest' : 'User: ${user.id}';

    final body = [
      template,
      '',
      '---',
      appInfo,
      userInfo,
      deviceInfo,
      osInfo,
    ].join('\n');

    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    final uri = Uri.parse(
      'mailto:nutzugt@gmail.com?subject=$encodedSubject&body=$encodedBody',
    );
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open email app.',
            style: AppTextStyles.secondary.copyWith(color: colors.textPrimary),
          ),
          backgroundColor: colors.bgCard,
        ),
      );
    }
  }

  Future<void> _showChangeEmailSheet(BuildContext context) async {
    final colors = context.sparkColors;
    final messenger = ScaffoldMessenger.of(context);
    final didUpdate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangeEmailSheet(),
    );

    if (didUpdate == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Email update requested. Check your inbox to confirm.',
            style: AppTextStyles.secondary.copyWith(color: colors.textPrimary),
          ),
          backgroundColor: colors.bgCard,
        ),
      );
    }
  }

  Future<void> _showChangePasswordSheet(BuildContext context) async {
    final colors = context.sparkColors;
    final messenger = ScaffoldMessenger.of(context);
    final didUpdate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );

    if (didUpdate == true) {
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

  Future<void> _showDisconnectGoogleSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final colors = context.sparkColors;
    final messenger = ScaffoldMessenger.of(context);
    final shouldDisconnect = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disconnect Google sign-in',
                  style: AppTextStyles.primary.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'After disconnecting, this account will no longer accept Google login.',
                  style: AppTextStyles.secondary.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.border),
                          foregroundColor: colors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.primary.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Disconnect',
                          style: AppTextStyles.primary.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldDisconnect != true || !context.mounted) {
      return;
    }

    try {
      await withLoadingOverlay(
        context,
        label: 'Disconnecting Google',
        action: () =>
            ref.read(authControllerProvider).disconnectGoogleIdentity(),
      );
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Google sign-in disconnected.',
            style: AppTextStyles.secondary.copyWith(color: colors.textPrimary),
          ),
          backgroundColor: colors.bgCard,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _friendlyAccountError(error),
            style: AppTextStyles.secondary.copyWith(color: colors.textPrimary),
          ),
          backgroundColor: colors.bgCard,
        ),
      );
    }
  }

  Future<void> _showDeleteAccountCountdown(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final colors = context.sparkColors;
    int secondsLeft = 10;
    Timer? timer;
    bool timerStarted = false;
    bool isDeleting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            if (!timerStarted) {
              timerStarted = true;
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (secondsLeft <= 0) {
                  t.cancel();
                  return;
                }
                if (sheetContext.mounted) {
                  setSheetState(() => secondsLeft -= 1);
                }
              });
            }

            final canDelete = secondsLeft == 0;

            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete account',
                      style: AppTextStyles.primary.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This action is permanent. Wait $secondsLeft seconds to continue.',
                      style: AppTextStyles.secondary.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: colors.border),
                              foregroundColor: colors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTextStyles.primary.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: canDelete
                                ? (isDeleting
                                      ? null
                                      : () async {
                                          triggerHaptic(ref, HapticLevel.heavy);
                                          setSheetState(
                                            () => isDeleting = true,
                                          );
                                          try {
                                            await ref
                                                .read(notesProvider)
                                                .purgeRemoteDataForCurrentUser();
                                            await ref
                                                .read(authControllerProvider)
                                                .deleteCurrentAccount();
                                            await ref
                                                .read(notesProvider)
                                                .wipeAllLocalData();
                                            await ref
                                                .read(authControllerProvider)
                                                .signOutToGuest();

                                            if (sheetContext.mounted) {
                                              Navigator.of(sheetContext).pop();
                                            }
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Account deleted.',
                                                    style: AppTextStyles
                                                        .secondary
                                                        .copyWith(
                                                          color: colors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                  backgroundColor:
                                                      colors.bgCard,
                                                ),
                                              );
                                            }
                                          } catch (error) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Delete failed: $error',
                                                    style: AppTextStyles
                                                        .secondary
                                                        .copyWith(
                                                          color: colors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                  backgroundColor:
                                                      colors.bgCard,
                                                ),
                                              );
                                            }
                                            if (sheetContext.mounted) {
                                              setSheetState(
                                                () => isDeleting = false,
                                              );
                                            }
                                          }
                                        })
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.red,
                              disabledBackgroundColor: colors.red.withValues(
                                alpha: 0.35,
                              ),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white.withValues(
                                alpha: 0.7,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              canDelete
                                  ? (isDeleting
                                        ? 'Deleting...'
                                        : 'Delete account')
                                  : 'Delete in ${secondsLeft}s',
                              style: AppTextStyles.primary.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      timer?.cancel();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.sparkColors;
    final themePreference = ref.watch(themeProvider);
    final hapticsEnabled = ref.watch(hapticsProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final isGuest = user == null;
    final isGoogleLinked = user != null && _hasGoogleIdentity(user);

    final accountTitle = isGuest ? 'Guest mode' : 'Signed in';
    final accountSubtitle = isGuest
        ? 'Notes stay on this device until you sign in.'
        : _accountSubtitleForUser(user);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.flame, color: colors.flame, size: 48),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spark',
                          style: AppTextStyles.primary.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'General',
                style: AppTextStyles.primary.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _MenuGroup(
                children: [
                  _MenuItem(
                    icon: LucideIcons.moon,
                    label: 'Theme',
                    trailing: SizedBox(
                      height: 32,
                      child: Center(
                        child: _ThemeSelect(
                          value: themePreference,
                          onChanged: (value) {
                            ref.read(themeProvider.notifier).setTheme(value);
                          },
                          height: 32,
                        ),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: LucideIcons.vibrate,
                    label: 'Haptics',
                    trailing: SizedBox(
                      height: 32,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Switch.adaptive(
                          value: hapticsEnabled,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (value) {
                            triggerHaptic(ref, HapticLevel.selection);
                            ref
                                .read(hapticsProvider.notifier)
                                .setEnabled(value);
                          },
                        ),
                      ),
                    ),
                    onTap: () {
                      triggerHaptic(ref, HapticLevel.selection);
                      ref
                          .read(hapticsProvider.notifier)
                          .setEnabled(!hapticsEnabled);
                    },
                  ),
                  _MenuItem(
                    icon: LucideIcons.trash2,
                    label: 'Recycle bin',
                    onTap: () {
                      triggerHaptic(ref, HapticLevel.light);
                      Navigator.of(context).push(
                        Motion.fadeSlideRoute(page: const RecycleBinScreen()),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: LucideIcons.github,
                    label: 'GitHub repository',
                    onTap: () {
                      triggerHaptic(ref, HapticLevel.light);
                      _launchUrl(
                        context,
                        'https://github.com/ZadniproIon/spark',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Feedback',
                style: AppTextStyles.primary.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _MenuGroup(
                children: [
                  _MenuItem(
                    icon: LucideIcons.messageCircle,
                    label: 'Send feedback',
                    onTap: () {
                      triggerHaptic(ref, HapticLevel.light);
                      _sendFeedback(
                        context,
                        ref,
                        subject: 'Spark Feedback',
                        template:
                            'Hi! I wanted to share some feedback about Spark:',
                      );
                    },
                  ),
                  _MenuItem(
                    icon: LucideIcons.bug,
                    label: 'Report bug',
                    onTap: () {
                      triggerHaptic(ref, HapticLevel.light);
                      _sendFeedback(
                        context,
                        ref,
                        subject: 'Spark Bug Report',
                        template:
                            'Bug description:\n\nSteps to reproduce:\n1.\n2.\n3.\n\nExpected behavior:\nActual behavior:',
                      );
                    },
                  ),
                  _MenuItem(
                    icon: LucideIcons.star,
                    label: 'Request a feature',
                    onTap: () {
                      triggerHaptic(ref, HapticLevel.light);
                      _sendFeedback(
                        context,
                        ref,
                        subject: 'Spark Feature Request',
                        template: 'Feature idea:\n\nWhy it would be useful:',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Account',
                style: AppTextStyles.primary.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (isGuest) ...[
                _MenuGroup(
                  children: [
                    _MenuAccountSummary(
                      title: accountTitle,
                      subtitle: accountSubtitle,
                    ),
                    _MenuItem(
                      icon: LucideIcons.logIn,
                      label: 'Sign in to sync',
                      onTap: () {
                        triggerHaptic(ref, HapticLevel.medium);
                        showAuthSheet(context);
                      },
                    ),
                  ],
                ),
              ] else ...[
                _MenuGroup(
                  children: [
                    _MenuAccountSummary(
                      title: accountTitle,
                      subtitle: accountSubtitle,
                    ),
                    _MenuItem(
                      icon: LucideIcons.logOut,
                      label: 'Log out',
                      onTap: () async {
                        triggerHaptic(ref, HapticLevel.light);
                        try {
                          await withLoadingOverlay(
                            context,
                            label: 'Signing out',
                            action: () => ref
                                .read(authControllerProvider)
                                .signOutToGuest(),
                          );
                        } catch (_) {
                          // Sign-out errors are non-critical; auth state handles the fallback.
                        }
                      },
                    ),
                    _MenuItem(
                      icon: LucideIcons.mail,
                      label: 'Change email',
                      onTap: () {
                        triggerHaptic(ref, HapticLevel.light);
                        _showChangeEmailSheet(context);
                      },
                    ),
                    _MenuItem(
                      icon: LucideIcons.lock,
                      label: 'Change password',
                      onTap: () {
                        triggerHaptic(ref, HapticLevel.light);
                        _showChangePasswordSheet(context);
                      },
                    ),
                    if (isGoogleLinked)
                      _MenuItem(
                        icon: LucideIcons.shield,
                        label: 'Disconnect Google sign-in',
                        isDestructive: true,
                        onTap: () {
                          triggerHaptic(ref, HapticLevel.medium);
                          _showDisconnectGoogleSheet(context, ref);
                        },
                      ),
                    _MenuItem(
                      icon: LucideIcons.userX,
                      label: 'Delete account',
                      isDestructive: true,
                      onTap: () {
                        triggerHaptic(ref, HapticLevel.heavy);
                        _showDeleteAccountCountdown(context, ref);
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeEmailSheet extends ConsumerStatefulWidget {
  const _ChangeEmailSheet();

  @override
  ConsumerState<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<_ChangeEmailSheet> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
              Text(
                'Change email',
                style: AppTextStyles.section.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: TextField(
                  controller: _emailController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'New email',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: AppTextStyles.secondary.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  style: AppTextStyles.primary.copyWith(
                    color: colors.textPrimary,
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
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        final email = _emailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setState(
                            () => _error = 'Enter a valid email address.',
                          );
                          return;
                        }

                        setState(() {
                          _isSaving = true;
                          _error = null;
                        });
                        try {
                          await ref
                              .read(authControllerProvider)
                              .updateEmail(email: email);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (error) {
                          if (mounted) {
                            setState(
                              () => _error = _friendlyAccountError(error),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isSaving = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.flame,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _isSaving ? 'Saving...' : 'Save email',
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
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
              Text(
                'Change password',
                style: AppTextStyles.section.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _passwordController,
                        enabled: !_isSaving,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'New password',
                          border: InputBorder.none,
                          isDense: true,
                          hintStyle: AppTextStyles.secondary.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        style: AppTextStyles.primary.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                      icon: Icon(
                        _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _confirmController,
                        enabled: !_isSaving,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          hintText: 'Confirm new password',
                          border: InputBorder.none,
                          isDense: true,
                          hintStyle: AppTextStyles.secondary.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        style: AppTextStyles.primary.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              );
                            },
                      icon: Icon(
                        _obscureConfirm ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
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
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        final password = _passwordController.text;
                        final confirm = _confirmController.text;
                        if (password.length < 8) {
                          setState(
                            () => _error =
                                'Use at least 8 characters for password.',
                          );
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
                          await ref
                              .read(authControllerProvider)
                              .updatePassword(password: password);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (error) {
                          if (mounted) {
                            setState(
                              () => _error = _friendlyAccountError(error),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isSaving = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.flame,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _isSaving ? 'Saving...' : 'Save password',
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSelect extends StatelessWidget {
  const _ThemeSelect({
    required this.value,
    required this.onChanged,
    this.height = 32,
  });

  final ThemePreference value;
  final ValueChanged<ThemePreference> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ThemePreference>(
            value: value,
            isDense: true,
            icon: Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: colors.textSecondary,
            ),
            items: ThemePreference.values
                .map(
                  (pref) => DropdownMenuItem<ThemePreference>(
                    value: pref,
                    child: Text(
                      pref.label,
                      style: AppTextStyles.secondary.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    final color = isDestructive ? colors.red : colors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.primary.copyWith(color: color),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: colors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuAccountSummary extends StatelessWidget {
  const _MenuAccountSummary({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.primary.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.secondary.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, thickness: 1, color: colors.border),
          ],
        ],
      ),
    );
  }
}
