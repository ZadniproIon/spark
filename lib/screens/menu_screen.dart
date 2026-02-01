import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/text_styles.dart';
import '../widgets/icon_button.dart';
import 'recycle_bin_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            children: [
              Row(
                children: [
                  SparkIconButton(
                    icon: LucideIcons.arrowLeft,
                    onPressed: () => Navigator.of(context).pop(),
                    showShadow: true,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.bgCard,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [AppShadows.shadow1],
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.flame,
                      color: AppColors.flame,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Spark', style: AppTextStyles.title),
                        const SizedBox(height: 2),
                        Text('Version 1.0', style: AppTextStyles.secondary),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('General', style: AppTextStyles.section),
              const SizedBox(height: 12),
              _MenuItem(
                icon: LucideIcons.moon,
                label: 'Theme',
                trailing: Switch(
                  value: false,
                  onChanged: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Theme toggle coming soon')),
                    );
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
                onTap: () => _launchUrl(context, 'https://github.com/example/spark'),
              ),
              const SizedBox(height: 24),
              Text('Feedback', style: AppTextStyles.section),
              const SizedBox(height: 12),
              _MenuItem(
                icon: LucideIcons.messageCircle,
                label: 'Send feedback',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feedback flow coming soon')),
                  );
                },
              ),
              _MenuItem(
                icon: LucideIcons.bug,
                label: 'Report bug',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bug report flow coming soon')),
                  );
                },
              ),
              _MenuItem(
                icon: LucideIcons.star,
                label: 'Request a feature',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feature requests coming soon')),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Account', style: AppTextStyles.section),
              const SizedBox(height: 12),
              _MenuItem(
                icon: LucideIcons.atSign,
                label: 'Change email',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Change email coming soon')),
                  );
                },
              ),
              _MenuItem(
                icon: LucideIcons.lock,
                label: 'Change password',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Change password coming soon')),
                  );
                },
              ),
              _MenuItem(
                icon: LucideIcons.logOut,
                label: 'Log out',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logout coming soon')),
                  );
                },
              ),
              _MenuItem(
                icon: LucideIcons.userX,
                label: 'Delete account',
                isDestructive: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete account coming soon')),
                  );
                },
              ),
            ],
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
    final color = isDestructive ? AppColors.red : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.shadow1],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color, size: 18),
        title: Text(
          label,
          style: AppTextStyles.primary.copyWith(color: color),
        ),
        trailing: trailing ?? const Icon(LucideIcons.chevronRight, size: 18),
      ),
    );
  }
}
