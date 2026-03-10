import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_access_controller.dart';
import '../../core/student_providers.dart';
import '../common/page_parts.dart';

class StudentProfilePage extends ConsumerStatefulWidget {
  const StudentProfilePage({super.key});

  @override
  ConsumerState<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends ConsumerState<StudentProfilePage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  String _selectedLanguage = 'Türkçe';

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final config = ref.watch(studentAppConfigProvider);
    final controller = ref.read(studentAccessProvider.notifier);
    final themeMode = ref.watch(studentThemeModeProvider);

    return StudentShellFrame(
      destination: StudentDestination.profile,
      title: 'Profil',
      subtitle:
          'Hesabını, görünüm tercihlerini ve üyelik ayarlarını buradan yönet.',
      accessContext: accessContext,
      browserTitle: 'Profil',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeroCard(
            displayName: _displayNameFor(accessContext),
            email: accessContext.email ?? 'ahmet.yilmaz@example.com',
            onSettingsPressed: () {
              _showMessage('Ayar detayları sonraki fazda açılacak.');
            },
          ),
          const SizedBox(height: 18),
          _ProBanner(
            isPremium: accessContext.canViewPremium,
            onUpgradePressed: () => context.go('/premium'),
          ),
          const SizedBox(height: 18),
          _AppSettingsCard(
            themeMode: themeMode,
            selectedLanguage: _selectedLanguage,
            onThemeChanged: (value) {
              ref.read(studentThemeModeProvider.notifier).state = value;
            },
            onLanguageChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedLanguage = value;
              });
            },
          ),
          const SizedBox(height: 18),
          _AccountManagementCard(
            accessContext: accessContext,
            onSubscriptionPressed: () => context.go('/premium'),
            onAccessPressed: () {
              _openAuthAccessSheet(
                accessContext: accessContext,
                config: config,
                controller: controller,
              );
            },
            onRefreshPressed: accessContext.isAuthenticated
                ? () async {
                    final result = await controller.refreshSession();
                    if (!mounted) {
                      return;
                    }
                    _showMessage(switch (result) {
                      AppSuccess<AuthSession>() =>
                        'Oturum ve claim bilgileri yenilendi.',
                      AppFailure<AuthSession>() => result.message,
                    });
                  }
                : null,
            onSignOutPressed: accessContext.isAuthenticated
                ? () async {
                    final result = await controller.signOut();
                    if (!mounted) {
                      return;
                    }
                    final message = switch (result) {
                      AppSuccess<void>() => 'Oturum kapatıldı.',
                      AppFailure<void>() => result.message,
                    };
                    _showMessage(message);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _openAuthAccessSheet({
    required AccessContext accessContext,
    required AppConfig config,
    required StudentAccessController controller,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: _AuthAccessSheet(
            accessContext: accessContext,
            config: config,
            emailController: _emailController,
            passwordController: _passwordController,
            onAnonymousPressed: () => _runAuthSessionAction(
              sheetContext: sheetContext,
              action: controller.signInAnonymously,
              successMessage: 'Anonim oturum başlatıldı.',
            ),
            onRefreshPressed: accessContext.isAuthenticated
                ? () => _runAuthSessionAction(
                    sheetContext: sheetContext,
                    action: controller.refreshSession,
                    successMessage: 'Oturum ve claim bilgileri yenilendi.',
                  )
                : null,
            onSignInPressed: () => _runAuthSessionAction(
              sheetContext: sheetContext,
              action: () => controller.signInWithEmail(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              ),
              successMessage: 'Giriş başarılı.',
            ),
            onSignUpPressed: () => _runAuthSessionAction(
              sheetContext: sheetContext,
              action: () => controller.signUpWithEmail(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              ),
              successMessage: 'Kayıt isteği gönderildi.',
            ),
            onUpgradePressed: accessContext.isAnonymous
                ? () => _runAuthSessionAction(
                    sheetContext: sheetContext,
                    action: () => controller.upgradeAnonymousWithEmail(
                      email: _emailController.text.trim(),
                      password: _passwordController.text,
                    ),
                    successMessage: 'Anonim hesap yükseltildi.',
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<void> _runAuthSessionAction({
    required BuildContext sheetContext,
    required Future<AppResult<AuthSession>> Function() action,
    required String successMessage,
  }) async {
    final result = await action();
    if (!mounted) {
      return;
    }

    _showAuthSessionResult(context, result, successMessage);
    if (result is AppSuccess<AuthSession> && sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
  }

  String _displayNameFor(AccessContext accessContext) {
    final rawDisplayName = accessContext.session.user?.displayName?.trim();
    if (rawDisplayName != null && rawDisplayName.isNotEmpty) {
      return rawDisplayName;
    }

    final email = accessContext.email?.trim();
    if (email != null && email.contains('@')) {
      final localPart = email.split('@').first.replaceAll('.', ' ');
      return localPart
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
    }

    return 'Ahmet Yılmaz';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.displayName,
    required this.email,
    required this.onSettingsPressed,
  });

  final String displayName;
  final String email;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: onSettingsPressed,
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
          Row(
            children: [
              Container(
                width: 88,
                height: 88,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.hero, width: 3),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.surfaceMuted,
                  ),
                  child: Center(
                    child: Text(
                      _initialsOf(displayName),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: tokens.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initialsOf(String value) {
    final parts = value
        .split(' ')
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) {
      return 'AY';
    }

    return parts.map((part) => part.substring(0, 1).toUpperCase()).join();
  }
}

class _ProBanner extends StatelessWidget {
  const _ProBanner({required this.isPremium, required this.onUpgradePressed});

  final bool isPremium;
  final VoidCallback onUpgradePressed;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PASSAGETR PRO',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sınırsız okuma, premium gramer modülleri ve gelişmiş öğrenme akışları burada açılır.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            FilledButton.tonal(
              onPressed: onUpgradePressed,
              child: Text(isPremium ? 'PRO Aktif' : 'Hemen Yükselt'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppSettingsCard extends StatelessWidget {
  const _AppSettingsCard({
    required this.themeMode,
    required this.selectedLanguage,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  final ThemeMode themeMode;
  final String selectedLanguage;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String?> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UYGULAMA AYARLARI',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Text('Tema', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
                ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
              ],
              selected: <ThemeMode>{themeMode},
              onSelectionChanged: (selection) {
                onThemeChanged(selection.first);
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('Dil', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedLanguage,
            decoration: const InputDecoration(labelText: 'Uygulama dili'),
            items: const [
              DropdownMenuItem(value: 'Türkçe', child: Text('Türkçe')),
              DropdownMenuItem(value: 'English', child: Text('English')),
            ],
            onChanged: onLanguageChanged,
          ),
        ],
      ),
    );
  }
}

class _AccountManagementCard extends StatelessWidget {
  const _AccountManagementCard({
    required this.accessContext,
    required this.onSubscriptionPressed,
    required this.onAccessPressed,
    required this.onRefreshPressed,
    required this.onSignOutPressed,
  });

  final AccessContext accessContext;
  final VoidCallback onSubscriptionPressed;
  final VoidCallback onAccessPressed;
  final VoidCallback? onRefreshPressed;
  final VoidCallback? onSignOutPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final planLabel = accessContext.canViewPremium ? 'PRO' : 'FREE';

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HESAP YÖNETİMİ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _AccountActionRow(
            title: 'Abonelik Yönetimi',
            subtitle: 'Mevcut plan: $planLabel',
            trailing: OutlinedButton(
              onPressed: onSubscriptionPressed,
              child: const Text('Planı Gör'),
            ),
          ),
          const SizedBox(height: 14),
          _AccountActionRow(
            title: 'Hesap Erişimi',
            subtitle: accessContext.isAnonymous
                ? 'Anonim oturumdasın. E-posta ile giriş yapabilir veya yeni hesap oluşturabilirsin.'
                : 'Aktif hesap: ${accessContext.email ?? 'Kayıtlı kullanıcı'}',
            trailing: FilledButton.icon(
              onPressed: onAccessPressed,
              icon: const Icon(Icons.manage_accounts_rounded),
              label: Text(
                accessContext.isAnonymous ? 'Giriş Yap' : 'Hesabı Yönet',
              ),
            ),
          ),
          if (accessContext.isAuthenticated) ...[
            const SizedBox(height: 14),
            _AccountActionRow(
              title: 'Oturum Durumu',
              subtitle: 'Bu cihazdaki etkin oturumu yenile veya doğrula.',
              trailing: FilledButton.tonal(
                onPressed: onRefreshPressed,
                child: const Text('Yenile'),
              ),
            ),
            const SizedBox(height: 14),
            _AccountActionRow(
              title: 'Oturumu Sonlandır',
              subtitle: 'Bu cihazdaki etkin oturum kapatılır.',
              trailing: FilledButton.icon(
                onPressed: onSignOutPressed,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Çıkış Yap'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountActionRow extends StatelessWidget {
  const _AccountActionRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < AppBreakpoints.compact;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
              ),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            trailing,
          ],
        );
      },
    );
  }
}

class _AuthAccessSheet extends StatelessWidget {
  const _AuthAccessSheet({
    required this.accessContext,
    required this.config,
    required this.emailController,
    required this.passwordController,
    required this.onAnonymousPressed,
    required this.onRefreshPressed,
    required this.onSignInPressed,
    required this.onSignUpPressed,
    required this.onUpgradePressed,
  });

  final AccessContext accessContext;
  final AppConfig config;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onAnonymousPressed;
  final VoidCallback? onRefreshPressed;
  final VoidCallback onSignInPressed;
  final VoidCallback onSignUpPressed;
  final VoidCallback? onUpgradePressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hesap erişimi',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              config.supabaseEnabled
                  ? 'Supabase bağlantısı aktif. E-posta ile giriş yapabilir, kayıt olabilir veya anonim oturum başlatabilirsin.'
                  : 'Supabase bağlantısı tanımlı değil. Bu build yalnız preview auth yüzeyi gösterir.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onSignInPressed,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Giriş Yap'),
                ),
                OutlinedButton(
                  onPressed: onAnonymousPressed,
                  child: const Text('Anonim Başlat'),
                ),
                FilledButton.tonal(
                  onPressed: onSignUpPressed,
                  child: const Text('Kayıt Ol'),
                ),
                if (onUpgradePressed != null)
                  OutlinedButton(
                    onPressed: onUpgradePressed,
                    child: const Text('Anonim Hesabı Yükselt'),
                  ),
                if (onRefreshPressed != null)
                  FilledButton.tonal(
                    onPressed: onRefreshPressed,
                    child: const Text('Oturumu Yenile'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              accessContext.isAnonymous
                  ? 'Mevcut durum: Anonim oturum'
                  : 'Mevcut durum: ${accessContext.email ?? 'Kayıtlı kullanıcı'}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

void _showAuthSessionResult(
  BuildContext context,
  AppResult<AuthSession> result,
  String successMessage,
) {
  final message = switch (result) {
    AppSuccess<AuthSession>() => successMessage,
    AppFailure<AuthSession>() => result.message,
  };

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
