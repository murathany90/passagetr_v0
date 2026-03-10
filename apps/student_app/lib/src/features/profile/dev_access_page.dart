import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_access_controller.dart';
import '../../core/student_providers.dart';
import '../common/page_parts.dart';

class StudentDevAccessPage extends ConsumerStatefulWidget {
  const StudentDevAccessPage({super.key});

  @override
  ConsumerState<StudentDevAccessPage> createState() =>
      _StudentDevAccessPageState();
}

class _StudentDevAccessPageState extends ConsumerState<StudentDevAccessPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: _kDevAccessPresets[2].email);
    _passwordController = TextEditingController(text: _kPhase1TestPassword);
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

    return StudentDetailFrame(
      destination: StudentDestination.profile,
      accessContext: accessContext,
      browserTitle: 'Dev Access',
      header: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Profile geri don',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Geliştirici erişimi',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Seed hesapları, auth claim yenileme ve preview erişim kontrolleri yalnızca burada tutulur.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _DevAccessPanel(
        accessContext: accessContext,
        config: config,
        controller: controller,
        emailController: _emailController,
        passwordController: _passwordController,
        onPresetSelected: (preset) {
          _emailController.text = preset.email;
          _passwordController.text = preset.password;
        },
      ),
    );
  }
}

class _DevAccessPanel extends StatelessWidget {
  const _DevAccessPanel({
    required this.accessContext,
    required this.config,
    required this.controller,
    required this.emailController,
    required this.passwordController,
    required this.onPresetSelected,
  });

  final AccessContext accessContext;
  final AppConfig config;
  final StudentAccessController controller;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final ValueChanged<_TestAccountPreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEV ACCESS PANEL',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.secondaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            config.supabaseEnabled
                ? 'Supabase bağlantısı aktif. Gerçek auth istekleri bu panelden tetiklenebilir.'
                : 'Supabase bağlantısı tanımlı değil. Yalnız preview erişim kontrolleri kullanılabilir.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kDevAccessPresets
                .map(
                  (preset) => ActionChip(
                    label: Text(preset.label),
                    onPressed: () => onPresetSelected(preset),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          _RoleSelector(
            value: accessContext.role,
            onChanged: controller.setRole,
          ),
          const SizedBox(height: 16),
          _PlanSelector(
            value: accessContext.plan,
            onChanged: controller.setPlan,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: accessContext.isAnonymous,
            onChanged: controller.setAnonymous,
            title: const Text('Anonim oturum'),
            subtitle: const Text('Preview auth ve yükseltme akışı için kullanılır.'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
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
              FilledButton(
                onPressed: () async {
                  final result = await controller.signInAnonymously();
                  if (!context.mounted) {
                    return;
                  }
                  _showAuthSessionResult(
                    context,
                    result,
                    'Anonim oturum başlatıldı.',
                  );
                },
                child: const Text('Anonim Başlat'),
              ),
              FilledButton.tonal(
                onPressed: accessContext.isAuthenticated
                    ? () async {
                        final result = await controller.refreshSession();
                        if (!context.mounted) {
                          return;
                        }
                        _showAuthSessionResult(
                          context,
                          result,
                          'Oturum ve claim bilgileri yenilendi.',
                        );
                      }
                    : null,
                child: const Text('Oturumu Yenile'),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final result = await controller.signInWithEmail(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  _showAuthSessionResult(context, result, 'Giriş başarılı.');
                },
                child: const Text('Giriş Yap'),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final result = await controller.signUpWithEmail(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  _showAuthSessionResult(
                    context,
                    result,
                    'Kayıt isteği gönderildi.',
                  );
                },
                child: const Text('Kayıt Ol'),
              ),
              OutlinedButton(
                onPressed: accessContext.isAnonymous
                    ? () async {
                        final result = await controller.upgradeAnonymousWithEmail(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        _showAuthSessionResult(
                          context,
                          result,
                          'Anonim hesap yükseltildi.',
                        );
                      }
                    : null,
                child: const Text('Anonim Hesabı Yükselt'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final result = await controller.signOut();
                  if (!context.mounted) {
                    return;
                  }
                  final message = switch (result) {
                    AppSuccess<void>() => 'Oturum kapatıldı.',
                    AppFailure<void>() => result.message,
                  };
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                },
                child: const Text('Çıkış Yap'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.value, required this.onChanged});

  final AppRole value;
  final ValueChanged<AppRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AppRole>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Rol preview'),
      items: AppRole.values
          .map(
            (role) =>
                DropdownMenuItem<AppRole>(value: role, child: Text(role.value)),
          )
          .toList(),
      onChanged: (role) {
        if (role != null) {
          onChanged(role);
        }
      },
    );
  }
}

class _PlanSelector extends StatelessWidget {
  const _PlanSelector({required this.value, required this.onChanged});

  final EntitlementPlan value;
  final ValueChanged<EntitlementPlan> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<EntitlementPlan>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Plan preview'),
      items: EntitlementPlan.values
          .map(
            (plan) => DropdownMenuItem<EntitlementPlan>(
              value: plan,
              child: Text(plan.value),
            ),
          )
          .toList(),
      onChanged: (plan) {
        if (plan != null) {
          onChanged(plan);
        }
      },
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

class _TestAccountPreset {
  const _TestAccountPreset({required this.label, required this.email});

  final String label;
  final String email;

  String get password => _kPhase1TestPassword;
}

const String _kPhase1TestPassword = 'PassageTR#2026!';
const List<_TestAccountPreset> _kDevAccessPresets = <_TestAccountPreset>[
  _TestAccountPreset(label: 'Free', email: 'phase1.free@passagetr.dev'),
  _TestAccountPreset(label: 'PRO', email: 'phase1.pro@passagetr.dev'),
  _TestAccountPreset(label: 'Admin', email: 'phase1.admin@passagetr.dev'),
  _TestAccountPreset(
    label: 'Developer',
    email: 'phase1.developer@passagetr.dev',
  ),
];
