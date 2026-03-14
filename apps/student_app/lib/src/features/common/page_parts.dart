import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';

enum StudentDestination {
  home,
  words,
  readings,
  grammar,
  profile,
  changelog,
  admin,
}

class StudentAppShell extends ConsumerWidget {
  const StudentAppShell({super.key, required this.child, required this.state});

  final Widget child;
  final GoRouterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(studentAccessProvider);
    final tokens = AppThemeTokens.of(context);

    final path = state.uri.path;
    final StudentDestination destination;

    if (path.startsWith('/words')) {
      destination = StudentDestination.words;
    } else if (path.startsWith('/readings')) {
      destination = StudentDestination.readings;
    } else if (path.startsWith('/grammar')) {
      destination = StudentDestination.grammar;
    } else if (path.startsWith('/changelog')) {
      destination = StudentDestination.changelog;
    } else if (path.startsWith('/profile') ||
        path.startsWith('/premium') ||
        path.startsWith('/dev-access')) {
      destination = StudentDestination.profile;
    } else if (path.startsWith('/admin')) {
      destination = StudentDestination.admin;
    } else {
      destination = StudentDestination.home;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.shellWide;
        return Scaffold(
          backgroundColor: tokens.appBackground,
          body: SafeArea(
            bottom: !isWide,
            child: isWide
                ? Row(
                    children: [
                      _StudentSidebar(
                        destination: destination,
                        accessContext: accessContext,
                      ),
                      Expanded(child: child),
                    ],
                  )
                : child,
          ),
          bottomNavigationBar: isWide
              ? null
              : _StudentBottomNavigationBar(
                  destination: destination,
                  accessContext: accessContext,
                ),
        );
      },
    );
  }
}

class StudentShellFrame extends StatelessWidget {
  const StudentShellFrame({
    super.key,
    required this.destination,
    required this.title,
    required this.subtitle,
    required this.accessContext,
    required this.body,
    this.headerAction,
    this.browserTitle,
  });

  final StudentDestination destination;
  final String title;
  final String subtitle;
  final AccessContext accessContext;
  final Widget body;
  final Widget? headerAction;
  final String? browserTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final resolvedBrowserTitle = browserTitle ?? title;

    return Title(
      title: 'PASSAGETR | $resolvedBrowserTitle',
      color: tokens.accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.shellWide;

          final content = Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 36 : 20,
                24,
                isWide ? 36 : 20,
                isWide ? 36 : 112,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? tokens.contentMaxWidth : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (headerAction != null && isWide)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: headerAction,
                        ),
                      ),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    body,
                  ],
                ),
              ),
            ),
          );

          return SafeArea(bottom: !isWide, child: content);
        },
      ),
    );
  }
}

class StudentDetailFrame extends StatelessWidget {
  const StudentDetailFrame({
    super.key,
    required this.destination,
    required this.accessContext,
    required this.header,
    required this.body,
    this.maxWidth = AppBreakpoints.studentDetailMaxWidth,
    this.browserTitle,
  });

  final StudentDestination destination;
  final AccessContext accessContext;
  final Widget header;
  final Widget body;
  final double maxWidth;
  final String? browserTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final resolvedBrowserTitle =
        browserTitle ?? _browserTitleForDestination(destination);

    return Title(
      title: 'PASSAGETR | $resolvedBrowserTitle',
      color: tokens.accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.shellWide;

          final content = Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 32 : 16,
                isWide ? 24 : 12,
                isWide ? 32 : 16,
                isWide ? 36 : 112,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? maxWidth : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header, const SizedBox(height: 20), body],
                ),
              ),
            ),
          );

          return SafeArea(bottom: !isWide, child: content);
        },
      ),
    );
  }
}

class StudentSurfaceCard extends StatelessWidget {
  const StudentSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.minHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final resolvedPadding = padding.resolve(Directionality.of(context));

    final content = Container(
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight!),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: tokens.surfaceShadow,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: resolvedPadding,
        child: minHeight == null
            ? child
            : ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, minHeight! - resolvedPadding.vertical),
                ),
                child: child,
              ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class StudentSearchField extends StatelessWidget {
  const StudentSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
      ),
    );
  }
}

class StudentSectionTitle extends StatelessWidget {
  const StudentSectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        ?trailing,
      ],
    );
  }
}

class StudentProgressBar extends StatelessWidget {
  const StudentProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.backgroundColor,
  });

  final double value;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color:
                  backgroundColor ?? tokens.accentSoft.withValues(alpha: 0.65),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentPackCard extends StatelessWidget {
  const StudentPackCard({
    super.key,
    required this.title,
    required this.wordCount,
    required this.progressPercent,
    required this.accentColor,
    this.onTap,
  });

  final String title;
  final int wordCount;
  final int progressPercent;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      onTap: onTap,
      minHeight: 190,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KELIME',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.secondaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wordCount.toString(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Text(
            'İlerleme',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StudentProgressBar(
                  value: progressPercent / 100,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '%$progressPercent',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
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
    return StudentSurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class LockedPage extends StatelessWidget {
  const LockedPage({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Title(
      title: 'PASSAGETR | $title',
      color: tokens.accent,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class PremiumPreviewPage extends StatelessWidget {
  const PremiumPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Premium preview alanı')));
  }
}

class AdminConsoleLauncherPage extends StatelessWidget {
  const AdminConsoleLauncherPage({
    super.key,
    required this.adminConsoleUrl,
    required this.onOpenAdminConsole,
  });

  final String adminConsoleUrl;
  final Future<bool> Function() onOpenAdminConsole;

  @override
  Widget build(BuildContext context) {
    final hasUrl = adminConsoleUrl.trim().isNotEmpty;
    final tokens = AppThemeTokens.of(context);

    Future<void> handleOpenAdminConsole() async {
      final opened = await onOpenAdminConsole();
      if (!context.mounted || opened) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin console adresi acilamadi.')),
      );
    }

    return Title(
      title: 'PASSAGETR | Admin Launcher',
      color: tokens.accent,
      child: Scaffold(
        appBar: AppBar(title: const Text('Admin launcher')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StudentSurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gerçek admin paneli ayrı web uygulamasında açılır.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasUrl
                          ? 'Aşağıdaki adres yeni sekmede açılacak:'
                          : 'Admin console adresi tanımlı değil.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (hasUrl) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        adminConsoleUrl,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: hasUrl ? handleOpenAdminConsole : null,
                        child: const Text('Admin console uygulamasını aç'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminLauncherPage extends StatelessWidget {
  const AdminLauncherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin launcher')),
      body: Center(
        child: FilledButton(
          onPressed: () {},
          child: const Text('apps/admin_console uygulamasını aç'),
        ),
      ),
    );
  }
}

class _StudentSidebar extends ConsumerWidget {
  const _StudentSidebar({
    required this.destination,
    required this.accessContext,
  });

  final StudentDestination destination;
  final AccessContext accessContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final destinations = _sidebarDestinations(accessContext);
    final accountItem = _accountDestination(accessContext);

    return Container(
      width: tokens.railWidth,
      decoration: BoxDecoration(
        color: tokens.railBackground,
        border: Border(right: BorderSide(color: tokens.surfaceBorder)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 22),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text(
              'PT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (final item in destinations)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SidebarButton(
                item: item,
                selected: destination == item.destination,
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                _SidebarButton(
                  item: accountItem,
                  selected: destination == accountItem.destination,
                ),
                if (accessContext.hasIdentifiedProfile) ...[
                  const SizedBox(height: 8),
                  _SidebarActionButton(
                    label: 'Çıkış Yap',
                    icon: Icons.logout_rounded,
                    onPressed: () async {
                      final result = await ref
                          .read(studentAccessProvider.notifier)
                          .signOut();
                      if (!context.mounted) {
                        return;
                      }

                      final message = switch (result) {
                        AppSuccess<void>() => 'Oturum kapatıldı.',
                        AppFailure<void>() => result.message,
                      };

                      if (result is AppSuccess<void>) {
                        context.go('/');
                      }

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    },
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
            child: SizedBox(
              width: tokens.railWidth - 20,
              key: const ValueKey<String>('sidebar_version_chip'),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                onPressed: () => context.go(WorkspaceInfo.releaseNotesPath),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(WorkspaceInfo.appVersion, maxLines: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarActionButton extends StatelessWidget {
  const _SidebarActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        unawaited(onPressed());
      },
      child: Ink(
        width: 76,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.surfaceMuted.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.surfaceBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tokens.secondaryText, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({required this.item, required this.selected});

  final _StudentNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final background = selected ? tokens.accent : Colors.transparent;
    final foreground = selected ? Colors.white : tokens.secondaryText;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _navigate(context, item.destination),
      child: Ink(
        width: 76,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: foreground, size: 26),
            const SizedBox(height: 8),
            Text(item.label, textAlign: TextAlign.center, style: labelStyle),
          ],
        ),
      ),
    );
  }
}

class _StudentBottomNavigationBar extends StatelessWidget {
  const _StudentBottomNavigationBar({
    required this.destination,
    required this.accessContext,
  });

  final StudentDestination destination;
  final AccessContext accessContext;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final items = _bottomDestinations(accessContext);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: tokens.mobileNavBackground,
          border: Border(top: BorderSide(color: tokens.surfaceBorder)),
          boxShadow: [
            BoxShadow(
              color: tokens.surfaceShadow,
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: _BottomNavButton(
                  item: item,
                  selected: destination == item.destination,
                  onTap: () => _navigate(context, item.destination),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _StudentNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: selected ? tokens.accent : tokens.secondaryText,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected
                  ? tokens.accentSoft.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
            child: Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 24,
                    color: selected ? tokens.accent : tokens.secondaryText,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
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

class _StudentNavItem {
  const _StudentNavItem({
    required this.destination,
    required this.label,
    required this.icon,
  });

  final StudentDestination destination;
  final String label;
  final IconData icon;
}

List<_StudentNavItem> _bottomDestinations(AccessContext accessContext) {
  return <_StudentNavItem>[
    const _StudentNavItem(
      destination: StudentDestination.home,
      label: 'Ana Sayfa',
      icon: Icons.home_outlined,
    ),
    const _StudentNavItem(
      destination: StudentDestination.words,
      label: 'Kelimeler',
      icon: Icons.dashboard_outlined,
    ),
    const _StudentNavItem(
      destination: StudentDestination.readings,
      label: 'Okuma',
      icon: Icons.menu_book_outlined,
    ),
    const _StudentNavItem(
      destination: StudentDestination.grammar,
      label: 'Gramer',
      icon: Icons.style_outlined,
    ),
    _accountDestination(accessContext),
  ];
}

List<_StudentNavItem> _sidebarDestinations(AccessContext accessContext) {
  final items = <_StudentNavItem>[
    const _StudentNavItem(
      destination: StudentDestination.home,
      label: 'Ana Sayfa',
      icon: Icons.home_outlined,
    ),
    const _StudentNavItem(
      destination: StudentDestination.words,
      label: 'Kelimeler',
      icon: Icons.dashboard_outlined,
    ),
    const _StudentNavItem(
      destination: StudentDestination.readings,
      label: 'Okuma',
      icon: Icons.menu_book_outlined,
    ),
    const _StudentNavItem(
      destination: StudentDestination.grammar,
      label: 'Gramer',
      icon: Icons.style_outlined,
    ),
  ];

  if (accessContext.canAccessAdmin) {
    items.add(
      const _StudentNavItem(
        destination: StudentDestination.admin,
        label: 'Admin',
        icon: Icons.admin_panel_settings_outlined,
      ),
    );
  }

  return items;
}

_StudentNavItem _accountDestination(AccessContext accessContext) {
  if (accessContext.hasIdentifiedProfile) {
    return const _StudentNavItem(
      destination: StudentDestination.profile,
      label: 'Profil',
      icon: Icons.person_outline_rounded,
    );
  }

  return const _StudentNavItem(
    destination: StudentDestination.profile,
    label: 'Giriş',
    icon: Icons.login_rounded,
  );
}

void _navigate(BuildContext context, StudentDestination destination) {
  final route = switch (destination) {
    StudentDestination.home => '/',
    StudentDestination.words => '/words',
    StudentDestination.readings => '/readings',
    StudentDestination.grammar => '/grammar',
    StudentDestination.profile => '/profile',
    StudentDestination.changelog => WorkspaceInfo.releaseNotesPath,
    StudentDestination.admin => '/admin',
  };

  context.go(route);
}

String _browserTitleForDestination(StudentDestination destination) {
  return switch (destination) {
    StudentDestination.home => 'Ana Sayfa',
    StudentDestination.words => 'Kelimeler',
    StudentDestination.readings => 'Okuma',
    StudentDestination.grammar => 'Gramer',
    StudentDestination.profile => 'Profil',
    StudentDestination.changelog => 'Surum Notlari',
    StudentDestination.admin => 'Admin Launcher',
  };
}
