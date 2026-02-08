import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/auth_provider.dart';
import '../providers/haptics_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../utils/motion.dart';
import '../widgets/auth_sheet.dart';
import 'recycle_bin_screen.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

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
      osInfo = 'OS: Android ${android.version.release} (SDK ${android.version.sdkInt})';
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
            style: AppTextStyles.secondary.copyWith(
              color: colors.textPrimary,
            ),
          ),
          backgroundColor: colors.bgCard,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.sparkColors;
    final themePreference = ref.watch(themeProvider);
    final hapticsEnabled = ref.watch(hapticsProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final isGuest = user == null;

    final accountTitle = isGuest ? 'Guest mode' : 'Signed in';
    final accountSubtitle = isGuest
        ? 'Notes stay on this device until you sign in.'
        : (user.email ?? 'Google account');
    final accountPillLabel = isGuest ? 'Guest' : 'Synced';

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
                    Icon(
                      LucideIcons.flame,
                      color: colors.flame,
                      size: 48,
                    ),
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
                            ref.read(hapticsProvider.notifier).setEnabled(value);
                          },
                        ),
                      ),
                    ),
                    onTap: () {
                      triggerHaptic(ref, HapticLevel.selection);
                      ref.read(hapticsProvider.notifier).setEnabled(!hapticsEnabled);
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
                        template:
                            'Feature idea:\n\nWhy it would be useful:',
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            accountTitle,
                            style: AppTextStyles.primary.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            accountSubtitle,
                            style: AppTextStyles.secondary.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        accountPillLabel,
                        style: AppTextStyles.secondary.copyWith(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (isGuest) ...[
                _MenuGroup(
                  children: [
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
                    _MenuItem(
                      icon: LucideIcons.externalLink,
                      label: 'Manage Google account',
                      onTap: () {
                        triggerHaptic(ref, HapticLevel.light);
                        _launchUrl(context, 'https://myaccount.google.com/');
                      },
                    ),
                    _MenuItem(
                      icon: LucideIcons.logOut,
                      label: 'Log out',
                      onTap: () {
                        triggerHaptic(ref, HapticLevel.light);
                        ref.read(authControllerProvider).signOutToGuest();
                      },
                    ),
                    _MenuItem(
                      icon: LucideIcons.userX,
                      label: 'Delete account',
                      isDestructive: true,
                      onTap: () {
                        triggerHaptic(ref, HapticLevel.heavy);
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
                trailing ??
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

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.children,
  });

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
              Divider(
                height: 1,
                thickness: 1,
                color: colors.border,
              ),
          ],
        ],
      ),
    );
  }
}
