import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/admin_providers.dart';

enum AdminDestination { dashboard, users, readings, words, grammar, settings }

class AdminShellFrame extends StatelessWidget {
  const AdminShellFrame({
    super.key,
    required this.destination,
    required this.title,
    required this.subtitle,
    required this.accessContext,
    required this.body,
    this.headerAction,
  });

  final AdminDestination destination;
  final String title;
  final String subtitle;
  final AccessContext accessContext;
  final Widget body;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.appBackground,
      body: SafeArea(
        child: Row(
          children: [
            _AdminSidebar(
              destination: destination,
              accessContext: accessContext,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.adminConsoleMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displaySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: tokens.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          if (headerAction != null) ...[
                            const SizedBox(width: 16),
                            headerAction!,
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _AdminPill(label: 'role=${accessContext.role.value}'),
                          _AdminPill(label: 'plan=${accessContext.plan.value}'),
                          const _AdminPill(label: 'console=admin'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      body,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({required this.destination, required this.accessContext});

  final AdminDestination destination;
  final AccessContext accessContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final items =
        <
          ({
            AdminDestination destination,
            String label,
            IconData icon,
            String route,
          })
        >[
          (
            destination: AdminDestination.dashboard,
            label: 'Dashboard',
            icon: Icons.space_dashboard_outlined,
            route: '/',
          ),
          (
            destination: AdminDestination.users,
            label: 'Kullanıcılar',
            icon: Icons.group_outlined,
            route: '/users',
          ),
          (
            destination: AdminDestination.readings,
            label: 'Okumalar',
            icon: Icons.menu_book_outlined,
            route: '/content/readings',
          ),
          (
            destination: AdminDestination.words,
            label: 'Kelimeler',
            icon: Icons.dashboard_customize_outlined,
            route: '/content/words',
          ),
          (
            destination: AdminDestination.grammar,
            label: 'Gramer',
            icon: Icons.rule_folder_outlined,
            route: '/content/grammar',
          ),
          (
            destination: AdminDestination.settings,
            label: 'Ayarlar',
            icon: Icons.settings_outlined,
            route: '/settings',
          ),
        ];

    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(right: BorderSide(color: tokens.surfaceBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[tokens.hero, tokens.badgeOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PASSAGETR CMS',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  accessContext.email ?? 'Admin console',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final item in items) ...[
                    _AdminNavTile(
                      label: item.label,
                      icon: item.icon,
                      isSelected: destination == item.destination,
                      onTap: () => context.go(item.route),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(adminAccessProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}

class _AdminNavTile extends StatelessWidget {
  const _AdminNavTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accentSoft.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? tokens.accent : tokens.secondaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isSelected ? tokens.accent : tokens.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPill extends StatelessWidget {
  const _AdminPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.surfaceBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.secondaryText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminSummaryCard extends StatelessWidget {
  const AdminSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
          ),
        ],
      ),
    );
  }
}

class AdminPanelCard extends StatelessWidget {
  const AdminPanelCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (trailing != null) ...[trailing!],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: 'phase1.admin@passagetr.dev',
    );
    _passwordController = TextEditingController(text: 'PassageTR#2026!');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final config = ref.watch(adminAppConfigProvider);
    final controller = ref.read(adminAccessProvider.notifier);

    return Scaffold(
      backgroundColor: tokens.appBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.adminAuthMaxWidth,
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 640,
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[tokens.hero, tokens.badgeOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PASSAGETR\nAdmin Console',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Kullanıcılar, içerik operasyonları ve audit görünümü tek web konsolunda.',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: AdminPanelCard(
                  title: 'Yönetici Girişi',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.supabaseEnabled
                            ? 'Supabase bağlantısı aktif. Admin claim olan kullanıcı ile giriş yap.'
                            : 'Supabase env eksik. Preview admin shell kullanılacak.',
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'E-posta'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Şifre'),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final result = await controller.signInWithEmail(
                                email: _emailController.text.trim(),
                                password: _passwordController.text,
                              );
                              if (!mounted) {
                                return;
                              }
                              final message = switch (result) {
                                AppSuccess<AuthSession>() =>
                                  'Giriş tamamlandı. Admin claim varsa dashboard açılır.',
                                AppFailure<AuthSession>() => result.message,
                              };
                              messenger.showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            },
                            child: const Text('Admin Girişi'),
                          ),
                          FilledButton.tonal(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final result = await controller.refreshSession();
                              if (!mounted) {
                                return;
                              }
                              final message = switch (result) {
                                AppSuccess<AuthSession>() =>
                                  'Claimler yenilendi.',
                                AppFailure<AuthSession>() => result.message,
                              };
                              messenger.showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            },
                            child: const Text('Claimleri Yenile'),
                          ),
                        ],
                      ),
                    ],
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
