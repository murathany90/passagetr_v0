import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/admin_cms_controller.dart';
import '../../core/admin_console_models.dart';
import '../../core/admin_providers.dart';
import '../common/admin_page_parts.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  String _query = '';
  EntitlementPlan? _planFilter;

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(adminAccessProvider);
    final users = ref.watch(adminUsersProvider);

    return AdminShellFrame(
      destination: AdminDestination.users,
      title: 'Kullanici Yonetimi',
      subtitle:
          'Rol ve plan degisikliklerini yonet, developer hesaplarini koru.',
      accessContext: accessContext,
      body: AdminPanelCard(
        title: 'Kullanici Listesi',
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'E-posta ara',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<EntitlementPlan?>(
                    initialValue: _planFilter,
                    decoration: const InputDecoration(labelText: 'Plan'),
                    items: const [
                      DropdownMenuItem<EntitlementPlan?>(
                        value: null,
                        child: Text('Tumu'),
                      ),
                      DropdownMenuItem<EntitlementPlan?>(
                        value: EntitlementPlan.free,
                        child: Text('free'),
                      ),
                      DropdownMenuItem<EntitlementPlan?>(
                        value: EntitlementPlan.pro,
                        child: Text('pro'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _planFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            users.when(
              data: (items) {
                final filtered = items
                    .where((item) {
                      final matchesQuery =
                          _query.isEmpty ||
                          item.email.toLowerCase().contains(_query);
                      final matchesPlan =
                          _planFilter == null || item.plan == _planFilter;
                      return matchesQuery && matchesPlan;
                    })
                    .toList(growable: false);

                return Column(
                  children: [
                    for (final item in filtered) ...[
                      _AdminUserRow(
                        user: item,
                        allowDeveloperGrant: accessContext.canManageRoles,
                        onRoleChanged: item.role == AppRole.developer
                            ? null
                            : (role) => _updateUser(
                                context,
                                item.copyWith(role: role),
                              ),
                        onPlanChanged: (plan) =>
                            _updateUser(context, item.copyWith(plan: plan)),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUser(
    BuildContext context,
    AdminUserRecord updatedUser,
  ) async {
    final currentUsers = await ref.read(adminUsersProvider.future);
    if (!context.mounted) {
      return;
    }

    AdminUserRecord? currentUser;
    for (final item in currentUsers) {
      if (item.id == updatedUser.id) {
        currentUser = item;
        break;
      }
    }
    if (currentUser == null) {
      return;
    }

    if (currentUser.role == updatedUser.role &&
        currentUser.plan == updatedUser.plan) {
      return;
    }

    final confirmed = await _confirmUserAccessChange(
      context,
      currentUser: currentUser,
      updatedUser: updatedUser,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final result = await ref
        .read(adminUserAccessServiceProvider)
        .setUserAccess(
          userId: updatedUser.id,
          role: updatedUser.role,
          plan: updatedUser.plan,
        );
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);

    if (result case AppFailure<void>()) {
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    ref.read(adminUserOverridesProvider.notifier).updateUser(updatedUser);
    ref
        .read(adminAuditOverridesProvider.notifier)
        .push(
          AdminAuditRecord(
            id: 'user-${updatedUser.id}-${DateTime.now().millisecondsSinceEpoch}',
            title: 'user.updated',
            subtitle:
                '${updatedUser.email} -> role=${formatRoleLabel(updatedUser.role)}, plan=${updatedUser.plan.value}',
            timestampLabel: 'az once',
          ),
        );
    messenger.showSnackBar(
      const SnackBar(content: Text('Kullanici erisimi guncellendi.')),
    );
  }

  Future<bool> _confirmUserAccessChange(
    BuildContext context, {
    required AdminUserRecord currentUser,
    required AdminUserRecord updatedUser,
  }) async {
    final roleChanged = currentUser.role != updatedUser.role;
    final baseDescription =
        '${updatedUser.email} icin ${roleChanged ? 'rol' : 'plan'} degisikligi oturum yenileme veya yeniden login gerektirebilir.';

    final firstPass = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erisim degisikligini onayla'),
        content: Text(
          '$baseDescription\n\nMevcut: role=${formatRoleLabel(currentUser.role)}, plan=${currentUser.plan.value}\nYeni: role=${formatRoleLabel(updatedUser.role)}, plan=${updatedUser.plan.value}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (firstPass != true || updatedUser.role != AppRole.developer) {
      return firstPass ?? false;
    }
    if (!context.mounted) {
      return false;
    }

    final secondPass = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer rolunu tekrar onayla'),
        content: const Text(
          'Developer rolu yuksek yetkili bir roldur. Bu hesap admin panelinde kritik mutasyonlar yapabilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Developer Olarak Ata'),
          ),
        ],
      ),
    );
    return secondPass ?? false;
  }
}

class _AdminUserRow extends StatelessWidget {
  const _AdminUserRow({
    required this.user,
    required this.allowDeveloperGrant,
    required this.onRoleChanged,
    required this.onPlanChanged,
  });

  final AdminUserRecord user;
  final bool allowDeveloperGrant;
  final ValueChanged<AppRole>? onRoleChanged;
  final ValueChanged<EntitlementPlan> onPlanChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Durum: ${user.statusLabel} | Son seen: ${user.lastSeenLabel}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<AppRole>(
              initialValue: user.role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: [
                const DropdownMenuItem(
                  value: AppRole.user,
                  child: Text('user'),
                ),
                const DropdownMenuItem(
                  value: AppRole.admin,
                  child: Text('admin'),
                ),
                if (allowDeveloperGrant)
                  const DropdownMenuItem(
                    value: AppRole.developer,
                    child: Text('developer'),
                  ),
              ],
              onChanged: onRoleChanged == null
                  ? null
                  : (value) {
                      if (value != null) {
                        onRoleChanged!(value);
                      }
                    },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<EntitlementPlan>(
              initialValue: user.plan,
              decoration: const InputDecoration(labelText: 'Plan'),
              items: const [
                DropdownMenuItem(
                  value: EntitlementPlan.free,
                  child: Text('free'),
                ),
                DropdownMenuItem(
                  value: EntitlementPlan.pro,
                  child: Text('pro'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onPlanChanged(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
