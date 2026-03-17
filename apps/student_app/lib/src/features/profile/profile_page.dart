import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_access_controller.dart';
import '../../core/student_content_refresh_controller.dart';
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
    final contentRefreshState = ref.watch(
      studentContentRefreshControllerProvider,
    );
    final hasIdentifiedProfile = accessContext.hasIdentifiedProfile;
    final pageTitle = hasIdentifiedProfile ? 'Profil' : 'Giriş';
    final pageSubtitle = hasIdentifiedProfile
        ? 'Hesabını, görünüm tercihlerini ve üyelik ayarlarını buradan yönet.'
        : 'Misafir olarak içerikleri gezebilirsin. Giriş yaptığında profil ve hesap yönetimi burada açılır.';

    return StudentShellFrame(
      destination: StudentDestination.profile,
      title: pageTitle,
      subtitle: pageSubtitle,
      accessContext: accessContext,
      browserTitle: pageTitle,
      body: hasIdentifiedProfile
          ? _buildProfileBody(
              accessContext: accessContext,
              controller: controller,
              themeMode: themeMode,
              contentRefreshState: contentRefreshState,
            )
          : _buildGuestBody(
              accessContext: accessContext,
              config: config,
              controller: controller,
              themeMode: themeMode,
              contentRefreshState: contentRefreshState,
            ),
    );
  }

  Widget _buildProfileBody({
    required AccessContext accessContext,
    required StudentAccessController controller,
    required ThemeMode themeMode,
    required StudentContentRefreshState contentRefreshState,
  }) {
    final showReleaseInfoCard =
        MediaQuery.sizeOf(context).width < AppBreakpoints.shellWide;
    final displayName = _displayNameFor(accessContext);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileHeroCard(
          displayName: displayName,
          email: accessContext.email ?? 'Kayıtlı kullanıcı',
          onSettingsPressed: () => _openProfileSettingsSheet(
            accessContext: accessContext,
            controller: controller,
            themeMode: themeMode,
          ),
        ),
        const SizedBox(height: 12),
        _ProfileStreakBadge(),
        const SizedBox(height: 18),
        _ContributionHeatMap(),
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
          onLanguageChanged: _updateLanguage,
          showContentRefreshAction: !kIsWeb,
          contentRefreshState: contentRefreshState,
          onRefreshContentPressed: _refreshContentWithFeedback,
        ),
        if (showReleaseInfoCard) ...[
          const SizedBox(height: 18),
          _ReleaseInfoCard(
            onOpenChangelog: () => context.go(WorkspaceInfo.releaseNotesPath),
          ),
        ],
        const SizedBox(height: 18),
        _AccountManagementCard(
          accessContext: accessContext,
          displayName: displayName,
          onProfileSettingsPressed: () => _openProfileSettingsSheet(
            accessContext: accessContext,
            controller: controller,
            themeMode: themeMode,
          ),
          onSubscriptionPressed: () => context.go('/premium'),
          onManageAccountPressed: () => _openAccountManagementSheet(
            accessContext: accessContext,
            controller: controller,
          ),
          onRefreshPressed: () => _refreshSessionWithFeedback(controller),
          onSignOutPressed: () => _signOutWithFeedback(controller),
        ),
      ],
    );
  }

  Widget _buildGuestBody({
    required AccessContext accessContext,
    required AppConfig config,
    required StudentAccessController controller,
    required ThemeMode themeMode,
    required StudentContentRefreshState contentRefreshState,
  }) {
    final showReleaseInfoCard =
        MediaQuery.sizeOf(context).width < AppBreakpoints.shellWide;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GuestAccessCard(),
        const SizedBox(height: 18),
        _AuthAccessSheet(
          accessContext: accessContext,
          config: config,
          controller: controller,
          emailController: _emailController,
          passwordController: _passwordController,
          showCloseAction: false,
          closeOnSuccess: false,
        ),
        const SizedBox(height: 18),
        _AppSettingsCard(
          themeMode: themeMode,
          selectedLanguage: _selectedLanguage,
          onThemeChanged: (value) {
            ref.read(studentThemeModeProvider.notifier).state = value;
          },
          onLanguageChanged: _updateLanguage,
          showContentRefreshAction: !kIsWeb,
          contentRefreshState: contentRefreshState,
          onRefreshContentPressed: _refreshContentWithFeedback,
        ),
        if (showReleaseInfoCard) ...[
          const SizedBox(height: 18),
          _ReleaseInfoCard(
            onOpenChangelog: () => context.go(WorkspaceInfo.releaseNotesPath),
          ),
        ],
      ],
    );
  }

  Future<void> _openProfileSettingsSheet({
    required AccessContext accessContext,
    required StudentAccessController controller,
    required ThemeMode themeMode,
  }) async {
    final pageContext = context;

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
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                child: _ProfileSettingsSheet(
                  accessContext: accessContext,
                  controller: controller,
                  initialDisplayName: _displayNameFor(accessContext),
                  themeMode: themeMode,
                  selectedLanguage: _selectedLanguage,
                  onThemeChanged: (value) {
                    ref.read(studentThemeModeProvider.notifier).state = value;
                  },
                  onLanguageChanged: _updateLanguage,
                  showContentRefreshAction: !kIsWeb,
                  onRefreshContentPressed: _refreshContentWithFeedback,
                  onManageAccountPressed: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _openAccountManagementSheet(
                          accessContext: accessContext,
                          controller: controller,
                        );
                      }
                    });
                  },
                  onSubscriptionPressed: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (pageContext.mounted) {
                        pageContext.go('/premium');
                      }
                    });
                  },
                  onRefreshPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _refreshSessionWithFeedback(controller);
                  },
                  onSignOutPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _signOutWithFeedback(controller);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAccountManagementSheet({
    required AccessContext accessContext,
    required StudentAccessController controller,
  }) async {
    final pageContext = context;

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
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                child: _AccountManagementSheet(
                  accessContext: accessContext,
                  displayName: _displayNameFor(accessContext),
                  onEditProfilePressed: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _openProfileSettingsSheet(
                          accessContext: accessContext,
                          controller: controller,
                          themeMode: ref.read(studentThemeModeProvider),
                        );
                      }
                    });
                  },
                  onSubscriptionPressed: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (pageContext.mounted) {
                        pageContext.go('/premium');
                      }
                    });
                  },
                  onRefreshPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _refreshSessionWithFeedback(controller);
                  },
                  onSignOutPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _signOutWithFeedback(controller);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshSessionWithFeedback(
    StudentAccessController controller,
  ) async {
    final result = await controller.refreshSession();
    if (!mounted) {
      return;
    }

    _showMessage(switch (result) {
      AppSuccess<AuthSession>() => 'Oturum ve claim bilgileri yenilendi.',
      AppFailure<AuthSession>() => result.message,
    });
  }

  Future<void> _signOutWithFeedback(StudentAccessController controller) async {
    final result = await controller.signOut();
    if (!mounted) {
      return;
    }

    _showMessage(switch (result) {
      AppSuccess<void>() => 'Oturum kapatıldı.',
      AppFailure<void>() => result.message,
    });
  }

  Future<void> _refreshContentWithFeedback() async {
    final result = await ref
        .read(studentContentRefreshControllerProvider.notifier)
        .refreshContent();
    if (!mounted) {
      return;
    }

    final state = ref.read(studentContentRefreshControllerProvider);
    final fallbackMessage = switch (result) {
      AppSuccess<void>() => 'Icerik yenilendi.',
      AppFailure<void>() => 'Icerik simdi yenilenemedi.',
    };
    _showMessage(state.message ?? fallbackMessage);
  }

  void _updateLanguage(String? value) {
    if (value == null) {
      return;
    }

    setState(() {
      _selectedLanguage = value;
    });
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

    return accessContext.isAnonymous ? 'Misafir' : 'Öğrenci';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GuestAccessCard extends StatelessWidget {
  const _GuestAccessCard();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Misafir Modu',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Public icerikleri gezebilirsin. Profil, hesap yonetimi ve kayitli ilerleme icin asagidaki bolumden giris yapabilir veya yeni bir free hesap olusturabilirsin.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
          ),
        ],
      ),
    );
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
              key: const ValueKey<String>('profile_settings_button'),
              tooltip: 'Ayarlar',
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
      return 'M';
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
    required this.showContentRefreshAction,
    required this.contentRefreshState,
    required this.onRefreshContentPressed,
  });

  final ThemeMode themeMode;
  final String selectedLanguage;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String?> onLanguageChanged;
  final bool showContentRefreshAction;
  final StudentContentRefreshState contentRefreshState;
  final Future<void> Function() onRefreshContentPressed;

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
          if (showContentRefreshAction) ...[
            const SizedBox(height: 20),
            Text('Icerik', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const ValueKey<String>('profile_refresh_content_button'),
                onPressed: contentRefreshState.isLoading
                    ? null
                    : () {
                        onRefreshContentPressed();
                      },
                icon: contentRefreshState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  contentRefreshState.isLoading
                      ? 'Icerik yenileniyor...'
                      : 'Icerigi yenile',
                ),
              ),
            ),
            if (contentRefreshState.message != null) ...[
              const SizedBox(height: 10),
              Text(
                contentRefreshState.message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: switch (contentRefreshState.status) {
                    StudentContentRefreshStatus.success => tokens.success,
                    StudentContentRefreshStatus.error => Theme.of(
                      context,
                    ).colorScheme.error,
                    _ => tokens.secondaryText,
                  },
                  fontWeight:
                      contentRefreshState.status ==
                          StudentContentRefreshStatus.loading
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReleaseInfoCard extends StatelessWidget {
  const _ReleaseInfoCard({required this.onOpenChangelog});

  final VoidCallback onOpenChangelog;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final currentRelease = releaseCatalog.firstWhere(
      (entry) => entry.isCurrent,
      orElse: () => releaseCatalog.first,
    );

    return StudentSurfaceCard(
      key: const ValueKey<String>('profile_release_info_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SURUM',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            WorkspaceInfo.appVersion,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Build ${WorkspaceInfo.buildNumber}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            currentRelease.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            currentRelease.summary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey<String>('profile_release_notes_button'),
              onPressed: onOpenChangelog,
              icon: const Icon(Icons.update_rounded),
              label: const Text('Surum Notlari'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSettingsSheet extends ConsumerStatefulWidget {
  const _ProfileSettingsSheet({
    required this.accessContext,
    required this.controller,
    required this.initialDisplayName,
    required this.themeMode,
    required this.selectedLanguage,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.showContentRefreshAction,
    required this.onRefreshContentPressed,
    required this.onManageAccountPressed,
    required this.onSubscriptionPressed,
    required this.onRefreshPressed,
    required this.onSignOutPressed,
  });

  final AccessContext accessContext;
  final StudentAccessController controller;
  final String initialDisplayName;
  final ThemeMode themeMode;
  final String selectedLanguage;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String?> onLanguageChanged;
  final bool showContentRefreshAction;
  final Future<void> Function() onRefreshContentPressed;
  final VoidCallback onManageAccountPressed;
  final VoidCallback onSubscriptionPressed;
  final Future<void> Function() onRefreshPressed;
  final Future<void> Function() onSignOutPressed;

  @override
  ConsumerState<_ProfileSettingsSheet> createState() =>
      _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends ConsumerState<_ProfileSettingsSheet> {
  late final TextEditingController _displayNameController;
  bool _isSavingDisplayName = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.initialDisplayName,
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    final normalizedDisplayName = _displayNameController.text.trim();
    if (normalizedDisplayName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı en az 2 karakter olmalı.')),
      );
      return;
    }

    if (normalizedDisplayName == widget.initialDisplayName.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı zaten güncel.')),
      );
      return;
    }

    setState(() {
      _isSavingDisplayName = true;
    });

    final result = await widget.controller.updateDisplayName(
      displayName: normalizedDisplayName,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingDisplayName = false;
    });

    final message = switch (result) {
      AppSuccess<AuthSession>() => 'Kullanıcı adı güncellendi.',
      AppFailure<AuthSession>() => result.message,
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profil Ayarları',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Bu panelden kullanıcı adını güncelleyebilir, tema ve dil tercihlerini değiştirebilirsin.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StudentSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROFİL',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.secondaryText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const ValueKey<String>('profile_display_name_field'),
                controller: _displayNameController,
                enabled: !_isSavingDisplayName,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı adı',
                  hintText: 'Profilde görünecek ad',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey<String>(
                    'profile_save_display_name_button',
                  ),
                  onPressed: _isSavingDisplayName ? null : _saveDisplayName,
                  icon: _isSavingDisplayName
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSavingDisplayName
                        ? 'Kaydediliyor...'
                        : 'Kullanıcı Adını Kaydet',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AppSettingsCard(
          themeMode: widget.themeMode,
          selectedLanguage: widget.selectedLanguage,
          onThemeChanged: widget.onThemeChanged,
          onLanguageChanged: widget.onLanguageChanged,
          showContentRefreshAction: widget.showContentRefreshAction,
          contentRefreshState: ref.watch(
            studentContentRefreshControllerProvider,
          ),
          onRefreshContentPressed: widget.onRefreshContentPressed,
        ),
        const SizedBox(height: 16),
        _SettingsQuickActionsCard(
          accessContext: widget.accessContext,
          onManageAccountPressed: widget.onManageAccountPressed,
          onSubscriptionPressed: widget.onSubscriptionPressed,
          onRefreshPressed: widget.onRefreshPressed,
          onSignOutPressed: widget.onSignOutPressed,
        ),
      ],
    );
  }
}

class _SettingsQuickActionsCard extends StatelessWidget {
  const _SettingsQuickActionsCard({
    required this.accessContext,
    required this.onManageAccountPressed,
    required this.onSubscriptionPressed,
    required this.onRefreshPressed,
    required this.onSignOutPressed,
  });

  final AccessContext accessContext;
  final VoidCallback onManageAccountPressed;
  final VoidCallback onSubscriptionPressed;
  final Future<void> Function() onRefreshPressed;
  final Future<void> Function() onSignOutPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HIZLI İŞLEMLER',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                key: const ValueKey<String>('settings_manage_account_button'),
                onPressed: onManageAccountPressed,
                icon: const Icon(Icons.manage_accounts_rounded),
                label: Text(
                  accessContext.isAnonymous ? 'Giriş Yap' : 'Hesabı Yönet',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onSubscriptionPressed,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Planı Gör'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  onRefreshPressed();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Oturumu Yenile'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  onSignOutPressed();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Çıkış Yap'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountManagementCard extends StatelessWidget {
  const _AccountManagementCard({
    required this.accessContext,
    required this.displayName,
    required this.onProfileSettingsPressed,
    required this.onSubscriptionPressed,
    required this.onManageAccountPressed,
    required this.onRefreshPressed,
    required this.onSignOutPressed,
  });

  final AccessContext accessContext;
  final String displayName;
  final VoidCallback onProfileSettingsPressed;
  final VoidCallback onSubscriptionPressed;
  final VoidCallback onManageAccountPressed;
  final Future<void> Function() onRefreshPressed;
  final Future<void> Function() onSignOutPressed;

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
            title: 'Profil Bilgileri',
            subtitle: 'Kullanıcı adı: $displayName',
            trailing: OutlinedButton.icon(
              onPressed: onProfileSettingsPressed,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Düzenle'),
            ),
          ),
          const SizedBox(height: 14),
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
            subtitle:
                'Aktif hesap: ${accessContext.email ?? 'Kayıtlı kullanıcı'}',
            trailing: FilledButton.icon(
              key: const ValueKey<String>('profile_manage_account_button'),
              onPressed: onManageAccountPressed,
              icon: const Icon(Icons.manage_accounts_rounded),
              label: const Text('Hesabı Yönet'),
            ),
          ),
          const SizedBox(height: 14),
          _AccountActionRow(
            title: 'Oturum Durumu',
            subtitle: 'Bu cihazdaki etkin oturumu yenile veya doğrula.',
            trailing: FilledButton.tonal(
              onPressed: () {
                onRefreshPressed();
              },
              child: const Text('Yenile'),
            ),
          ),
          const SizedBox(height: 14),
          _AccountActionRow(
            title: 'Oturumu Sonlandır',
            subtitle: 'Bu cihazdaki etkin oturumu kapat.',
            trailing: FilledButton.icon(
              onPressed: () {
                onSignOutPressed();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Çıkış Yap'),
            ),
          ),
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

class _AccountManagementSheet extends StatelessWidget {
  const _AccountManagementSheet({
    required this.accessContext,
    required this.displayName,
    required this.onEditProfilePressed,
    required this.onSubscriptionPressed,
    required this.onRefreshPressed,
    required this.onSignOutPressed,
  });

  final AccessContext accessContext;
  final String displayName;
  final VoidCallback onEditProfilePressed;
  final VoidCallback onSubscriptionPressed;
  final Future<void> Function() onRefreshPressed;
  final Future<void> Function() onSignOutPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final planLabel = accessContext.canViewPremium ? 'PRO' : 'FREE';

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hesap Yönetimi',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Profil bilgilerini kontrol et, plan durumunu gör ve oturum işlemlerini buradan yönet.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: 18),
          _AccountActionRow(
            title: 'Kullanıcı Adı',
            subtitle: displayName,
            trailing: OutlinedButton.icon(
              onPressed: onEditProfilePressed,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Düzenle'),
            ),
          ),
          const SizedBox(height: 14),
          _AccountActionRow(
            title: 'E-posta',
            subtitle: accessContext.email ?? 'Kayıtlı kullanıcı',
            trailing: const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          _AccountActionRow(
            title: 'Plan',
            subtitle: planLabel,
            trailing: OutlinedButton(
              onPressed: onSubscriptionPressed,
              child: const Text('Planı Gör'),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  onRefreshPressed();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Oturumu Yenile'),
              ),
              FilledButton.icon(
                onPressed: () {
                  onSignOutPressed();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Çıkış Yap'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _AuthSheetAction { signIn, signUp, resend }

class _AuthAccessSheet extends StatefulWidget {
  const _AuthAccessSheet({
    required this.accessContext,
    required this.config,
    required this.controller,
    required this.emailController,
    required this.passwordController,
    this.showCloseAction = true,
    this.closeOnSuccess = true,
  });

  final AccessContext accessContext;
  final AppConfig config;
  final StudentAccessController controller;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool showCloseAction;
  final bool closeOnSuccess;

  @override
  State<_AuthAccessSheet> createState() => _AuthAccessSheetState();
}

class _AuthAccessSheetState extends State<_AuthAccessSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  _AuthSheetAction? _busyAction;
  String? _pendingConfirmationEmail;

  bool get _isBusy => _busyAction != null;

  Future<void> _runAction(_AuthSheetAction action) async {
    if (_requiresCredentials(action) &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _busyAction = action;
    });

    switch (action) {
      case _AuthSheetAction.signIn:
        await _handleSignIn();
        break;
      case _AuthSheetAction.signUp:
        await _handleSignUp();
        break;
      case _AuthSheetAction.resend:
        await _handleResend();
        break;
    }
  }

  bool _requiresCredentials(_AuthSheetAction action) {
    return action == _AuthSheetAction.signIn ||
        action == _AuthSheetAction.signUp;
  }

  Future<void> _handleSignIn() async {
    final resolvedResult = await widget.controller.signInWithEmail(
      email: widget.emailController.text.trim(),
      password: widget.passwordController.text,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _busyAction = null;
      if (resolvedResult is AppSuccess<AuthSession> &&
          resolvedResult.value.isAuthenticated) {
        _pendingConfirmationEmail = null;
      }
    });

    final message = switch (resolvedResult) {
      AppSuccess<AuthSession>() => 'Giris basarili.',
      AppFailure<AuthSession>() => resolvedResult.message,
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (resolvedResult is AppSuccess<AuthSession> &&
        widget.closeOnSuccess &&
        resolvedResult.value.isAuthenticated &&
        context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSignUp() async {
    final email = widget.emailController.text.trim();
    final resolvedResult = await widget.controller.signUpWithEmail(
      email: email,
      password: widget.passwordController.text,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _busyAction = null;
      if (resolvedResult is AppSuccess<AuthSession> &&
          !resolvedResult.value.isAuthenticated) {
        _pendingConfirmationEmail = email;
      } else if (resolvedResult is AppSuccess<AuthSession>) {
        _pendingConfirmationEmail = null;
      }
    });

    final message = switch (resolvedResult) {
      AppSuccess<AuthSession>() =>
        resolvedResult.value.isAuthenticated
            ? 'Kayit tamamlandi. Profilin hazir.'
            : 'Hesap olusturuldu. E-posta adresini dogrulayip sonra giris yap.',
      AppFailure<AuthSession>() => resolvedResult.message,
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (resolvedResult is AppSuccess<AuthSession> &&
        widget.closeOnSuccess &&
        resolvedResult.value.isAuthenticated &&
        context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleResend() async {
    final email = (_pendingConfirmationEmail ?? widget.emailController.text)
        .trim();
    final resolvedResult = await widget.controller.resendSignUpConfirmation(
      email: email,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _busyAction = null;
      if (resolvedResult is AppSuccess<void>) {
        _pendingConfirmationEmail = email;
      }
    });

    final message = switch (resolvedResult) {
      AppSuccess<void>() => 'Dogrulama maili yeniden gonderildi.',
      AppFailure<void>() => resolvedResult.message,
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateEmail(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'E-posta zorunlu.';
    }
    if (!normalized.contains('@') || !normalized.contains('.')) {
      return 'Gecerli bir e-posta gir.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final normalized = value ?? '';
    if (normalized.isEmpty) {
      return 'Sifre zorunlu.';
    }
    if (normalized.length < 8) {
      return 'Sifre en az 8 karakter olmali.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hesap erisimi',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (widget.showCloseAction)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.config.supabaseEnabled
                  ? 'E-posta ile giris yapabilir veya yeni bir free hesap olusturabilirsin. Kayit sonrasi mail dogrulamasi gerekir.'
                  : 'Supabase baglantisi tanimli degil. Bu build yalnizca preview auth yuzeyi gosterir.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
            ),
            if (_pendingConfirmationEmail != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.accentSoft.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dogrulama bekleniyor',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_pendingConfirmationEmail adresine bir dogrulama maili gonderildi. Maildeki linke tiklayip sonra giris yap.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'auth_resend_confirmation_button',
                      ),
                      onPressed: _isBusy
                          ? null
                          : () => _runAction(_AuthSheetAction.resend),
                      icon: _busyAction == _AuthSheetAction.resend
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mark_email_unread_outlined),
                      label: const Text('Dogrulama Mailini Yeniden Gonder'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: widget.emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isBusy,
              validator: _validateEmail,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: widget.passwordController,
              obscureText: true,
              enabled: !_isBusy,
              validator: _validatePassword,
              decoration: const InputDecoration(labelText: 'Sifre'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  key: const ValueKey<String>('auth_sign_in_button'),
                  onPressed: _isBusy
                      ? null
                      : () => _runAction(_AuthSheetAction.signIn),
                  icon: _busyAction == _AuthSheetAction.signIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: const Text('Giris Yap'),
                ),
                FilledButton.tonal(
                  key: const ValueKey<String>('auth_sign_up_button'),
                  onPressed: _isBusy
                      ? null
                      : () => _runAction(_AuthSheetAction.signUp),
                  child: _busyAction == _AuthSheetAction.signUp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kayit Ol'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.accessContext.hasIdentifiedProfile
                  ? 'Mevcut durum: ${widget.accessContext.email ?? 'Kayitli kullanici'}'
                  : 'Mevcut durum: Oturumsuz ziyaretci',
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

class _ProfileStreakBadge extends ConsumerWidget {
  const _ProfileStreakBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final streakDays = ref.watch(studentStreakDaysProvider);

    return StudentSurfaceCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tokens.hero, const Color(0xFFFF720F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streakDays günlük seri',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streakDays > 0
                      ? 'Harika gidiyorsun! Seriyi bozma.'
                      : 'Bugün bir aktivite tamamla ve seriyi başlat!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionHeatMap extends ConsumerWidget {
  const _ContributionHeatMap();

  static const _cols = 12;
  static const _rows = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final weeklyTrend = ref.watch(studentWeeklyTrendProvider);

    // Build a simple _cols × _rows grid from the 7-element weekly trend.
    // The current week's data is placed in the last column.
    final cells = List<double>.filled(_cols * _rows, 0);
    for (var dayIndex = 0;
        dayIndex < weeklyTrend.length && dayIndex < _rows;
        dayIndex++) {
      cells[(_cols - 1) * _rows + dayIndex] = weeklyTrend[dayIndex];
    }

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aktivite Haritası',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Son 12 haftalık aktivite yoğunluğu',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final totalGap = (_cols - 1) * 3.0;
              final cellSize = (constraints.maxWidth - totalGap) / _cols;
              final clampedSize = cellSize.clamp(8.0, 22.0);

              return Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (var row = 0; row < _rows; row++)
                    for (var col = 0; col < _cols; col++)
                      _HeatCell(
                        size: clampedSize,
                        intensity: cells[col * _rows + row],
                        isToday: col == _cols - 1 &&
                            row == DateTime.now().weekday - 1,
                        emptyColor: tokens.surfaceMuted,
                        accentColor: tokens.accent,
                      ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Az', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 6),
              for (final v in [0.0, 0.25, 0.5, 0.75, 1.0]) ...[
                _HeatCell(
                  size: 12,
                  intensity: v,
                  emptyColor: tokens.surfaceMuted,
                  accentColor: tokens.accent,
                ),
                const SizedBox(width: 3),
              ],
              Text('Çok', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.size,
    required this.intensity,
    required this.emptyColor,
    required this.accentColor,
    this.isToday = false,
  });

  final double size;
  final double intensity;
  final Color emptyColor;
  final Color accentColor;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final clamped = intensity.clamp(0.0, 1.0);
    final color = clamped == 0
        ? emptyColor
        : Color.lerp(
            accentColor.withValues(alpha: 0.2),
            accentColor,
            clamped,
          )!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: isToday ? Border.all(color: accentColor, width: 1.5) : null,
      ),
    );
  }
}
