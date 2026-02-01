import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/theme_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.sparkColors;
    final themePreference = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.flame,
                      color: colors.flame,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spark',
                          style: AppTextStyles.title.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version 1.0',
                          style: AppTextStyles.secondary.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'General',
                style: AppTextStyles.section.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                icon: LucideIcons.moon,
                label: 'Theme',
                trailing: _ThemeSelect(
                  value: themePreference,
                  onChanged: (value) {
                    ref.read(themeProvider.notifier).setTheme(value);
                  },
                ),
              ),
              _MenuItem(
                icon: LucideIcons.trash2,
                label: 'Recycle bin',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RecycleBinScreen()),
                  );
                },
              ),
              _MenuItem(
                icon: LucideIcons.github,
                label: 'GitHub repository',
                onTap: () => _launchUrl(
                  context,
                  'https://github.com/ZadniproIon/spark',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Feedback',
                style: AppTextStyles.section.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                icon: LucideIcons.messageCircle,
                label: 'Send feedback',
                onTap: () {},
              ),
              _MenuItem(
                icon: LucideIcons.bug,
                label: 'Report bug',
                onTap: () {},
              ),
              _MenuItem(
                icon: LucideIcons.star,
                label: 'Request a feature',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              Text(
                'Account',
                style: AppTextStyles.section.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                icon: LucideIcons.atSign,
                label: 'Change email',
                onTap: () {},
              ),
              _MenuItem(
                icon: LucideIcons.lock,
                label: 'Change password',
                onTap: () {},
              ),
              _MenuItem(
                icon: LucideIcons.logOut,
                label: 'Log out',
                onTap: () {},
              ),
              _MenuItem(
                icon: LucideIcons.userX,
                label: 'Delete account',
                isDestructive: true,
                onTap: () {},
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
  });

  final ThemePreference value;
  final ValueChanged<ThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color, size: 18),
        title: Text(
          label,
          style: AppTextStyles.primary.copyWith(color: color),
        ),
        trailing: trailing ?? Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
