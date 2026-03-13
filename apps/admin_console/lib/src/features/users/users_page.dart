import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
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
  bool _isInviteBusy = false;
  bool _isBulkBusy = false;
  AdminInviteRequest? _lastInviteRequest;
  AdminInviteResult? _lastInviteResult;

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(adminAccessProvider);
    final query = ref.watch(adminUserListQueryProvider);
    final usersPage = ref.watch(adminUsersPageProvider);
    final selectedIds = ref.watch(adminSelectedUserIdsProvider);

    return AdminShellFrame(
      destination: AdminDestination.users,
      title: 'Kullanici Yonetimi',
      subtitle:
          'Paginated liste, bulk rol-plan mutasyonlari ve invite akisi bu panelden yonetilir.',
      accessContext: accessContext,
      headerAction: FilledButton.icon(
        onPressed: _isInviteBusy ? null : () => _openInviteDialog(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_isInviteBusy ? 'Gonderiliyor...' : 'Yeni Kullanici Ekle'),
      ),
      body: Column(
        children: [
          AdminPanelCard(
            title: 'Filtreler',
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'E-posta veya isim ara',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => ref
                          .read(adminUserListQueryProvider.notifier)
                          .updateQuery(value.trim()),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth < 560
                                ? constraints.maxWidth
                                : 220,
                            child: DropdownButtonFormField<AppRole?>(
                              initialValue: query.role,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Rol',
                              ),
                              items: const [
                                DropdownMenuItem<AppRole?>(
                                  value: null,
                                  child: Text('Tum roller'),
                                ),
                                DropdownMenuItem<AppRole?>(
                                  value: AppRole.user,
                                  child: Text('user'),
                                ),
                                DropdownMenuItem<AppRole?>(
                                  value: AppRole.admin,
                                  child: Text('admin'),
                                ),
                                DropdownMenuItem<AppRole?>(
                                  value: AppRole.developer,
                                  child: Text('developer'),
                                ),
                              ],
                              onChanged: (value) => ref
                                  .read(adminUserListQueryProvider.notifier)
                                  .updateRole(value),
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth < 560
                                ? constraints.maxWidth
                                : 220,
                            child: DropdownButtonFormField<EntitlementPlan?>(
                              initialValue: query.plan,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Plan',
                              ),
                              items: const [
                                DropdownMenuItem<EntitlementPlan?>(
                                  value: null,
                                  child: Text('Tum planlar'),
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
                              onChanged: (value) => ref
                                  .read(adminUserListQueryProvider.notifier)
                                  .updatePlan(value),
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth < 560
                                ? constraints.maxWidth
                                : 220,
                            child:
                                DropdownButtonFormField<AdminUserStatusFilter?>(
                                  initialValue: query.status,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Durum',
                                  ),
                                  items: const [
                                    DropdownMenuItem<AdminUserStatusFilter?>(
                                      value: null,
                                      child: Text('Tum durumlar'),
                                    ),
                                    DropdownMenuItem<AdminUserStatusFilter?>(
                                      value: AdminUserStatusFilter.active,
                                      child: Text('active'),
                                    ),
                                    DropdownMenuItem<AdminUserStatusFilter?>(
                                      value: AdminUserStatusFilter.anonymous,
                                      child: Text('anonymous'),
                                    ),
                                    DropdownMenuItem<AdminUserStatusFilter?>(
                                      value: AdminUserStatusFilter.staff,
                                      child: Text('staff'),
                                    ),
                                  ],
                                  onChanged: (value) => ref
                                      .read(adminUserListQueryProvider.notifier)
                                      .updateStatus(value),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_lastInviteResult != null) ...[
            const SizedBox(height: 16),
            _buildInviteStatusCard(context),
          ],
          const SizedBox(height: 16),
          usersPage.when(
            data: (page) => _buildUsersTable(
              context,
              accessContext: accessContext,
              query: query,
              page: page,
              selectedIds: selectedIds,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => AdminPanelCard(
              title: 'Kullanici Listesi',
              child: Text(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteStatusCard(BuildContext context) {
    final result = _lastInviteResult!;
    final isAccepted = result.accepted;
    final title = isAccepted
        ? 'Son Davet Kuyruga Alindi'
        : 'Son Davet Reddedildi';
    final message = isAccepted
        ? '${result.email} icin davet Supabase mail kuyru guna alindi. Mail teslimati SMTP/Auth ayarlarina baglidir.'
        : result.errorMessage ??
              'Davet islenemedi. Supabase Auth mailer ve redirect ayarlarini kontrol edin.';

    return AdminPanelCard(
      title: title,
      trailing: _InfoChip(
        label: isAccepted
            ? 'accepted / retry=${result.retryCount}'
            : 'rejected / retry=${result.retryCount}',
      ),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          if (_lastInviteRequest != null)
            FilledButton.tonalIcon(
              onPressed: _isInviteBusy ? null : () => _retryLastInvite(context),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                _isInviteBusy ? 'Yeniden deneniyor...' : 'Retry Invite',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersTable(
    BuildContext context, {
    required AccessContext accessContext,
    required AdminUserListQuery query,
    required AdminPage<AdminUserListItem> page,
    required Set<String> selectedIds,
  }) {
    final currentPageIds = page.items
        .map((item) => item.id)
        .toList(growable: false);
    final allCurrentSelected =
        currentPageIds.isNotEmpty && currentPageIds.every(selectedIds.contains);
    final selectionCount = selectedIds.length;

    return AdminPanelCard(
      title: 'Kullanici Listesi',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _InfoChip(label: '${page.totalCount} toplam'),
          _InfoChip(
            label:
                '${page.offset + 1}-${page.offset + page.items.length} arasi',
          ),
        ],
      ),
      child: Column(
        children: [
          if (selectionCount > 0) ...[
            _BulkActionBar(
              selectionCount: selectionCount,
              allowDeveloperGrant: accessContext.canManageRoles,
              isBusy: _isBulkBusy,
              onClear: () =>
                  ref.read(adminSelectedUserIdsProvider.notifier).clear(),
              onApplyRole: (role) => _applyBulkUpdate(
                context,
                AdminBulkUserUpdate(
                  userIds: selectedIds.toList(growable: false),
                  role: role,
                ),
              ),
              onApplyPlan: (plan) => _applyBulkUpdate(
                context,
                AdminBulkUserUpdate(
                  userIds: selectedIds.toList(growable: false),
                  plan: plan,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Checkbox(
                value: allCurrentSelected,
                onChanged: page.items.isEmpty
                    ? null
                    : (value) => ref
                          .read(adminSelectedUserIdsProvider.notifier)
                          .toggleAll(currentPageIds, selected: value ?? false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Secili sayfayi toplu guncelle',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (page.items.isEmpty)
            const AdminEmptyState(
              title: 'Kullanici bulunamadi',
              message:
                  'Secili filtrelerle eslesen bir kullanici yok. Filtreleri sifirlayip tekrar deneyin.',
              icon: Icons.group_off_rounded,
            )
          else
            for (final item in page.items) ...[
              _AdminUserListRow(
                user: item,
                isSelected: selectedIds.contains(item.id),
                allowDeveloperGrant: accessContext.canManageRoles,
                onSelected: () => ref
                    .read(adminSelectedUserIdsProvider.notifier)
                    .toggle(item.id),
                onEdit: () => _openEditDialog(context, user: item),
                onDelete: () => _deleteUser(context, user: item),
                onApplyUpdate: ({AppRole? role, EntitlementPlan? plan}) {
                  return _applySingleUpdate(
                    context,
                    user: item,
                    nextRole: role ?? item.role,
                    nextPlan: plan ?? item.plan,
                  );
                },
              ),
              const Divider(height: 1),
            ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Sayfa boyutu: ${query.limit}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: page.hasPreviousPage
                    ? () => ref
                          .read(adminUserListQueryProvider.notifier)
                          .previousPage()
                    : null,
                child: const Text('Onceki'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: page.hasNextPage
                    ? () => ref
                          .read(adminUserListQueryProvider.notifier)
                          .nextPage()
                    : null,
                child: const Text('Sonraki'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openInviteDialog(BuildContext context) async {
    final draft = await showDialog<_InviteDraft>(
      context: context,
      builder: (context) => const _InviteUserDialog(),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    if (!await _confirmRoleMutation(
      context,
      nextRole: draft.role,
      subjectLabel: draft.email,
      currentRole: null,
      currentPlan: null,
      nextPlan: draft.plan,
    )) {
      return;
    }

    setState(() {
      _isInviteBusy = true;
    });
    final repository = ref.read(adminUserManagementRepositoryProvider);
    final settings = ref.read(adminActiveSettingsProvider);
    final request = AdminInviteRequest(
      email: draft.email,
      role: draft.role,
      plan: draft.plan,
      inviteExpiryHours: settings.security.inviteExpiryHours,
    );
    final result = await repository.inviteUser(request);
    if (mounted) {
      setState(() {
        _isInviteBusy = false;
        _lastInviteRequest = request;
        _lastInviteResult = switch (result) {
          AppSuccess<AdminInviteResult>() => result.value,
          AppFailure<AdminInviteResult>() => AdminInviteResult(
            accepted: false,
            email: request.email,
            role: request.role,
            plan: request.plan,
            errorMessage: result.message,
          ),
        };
      });
    }
    if (!context.mounted) {
      return;
    }
    _showInviteSnackBar(context, result);
    if (result case AppSuccess<AdminInviteResult>()) {
      if (result.value.accepted && result.value.invitedUserId != null) {
        ref
            .read(adminUserListOverridesProvider.notifier)
            .upsert(
              AdminUserListItem(
                id: result.value.invitedUserId!,
                email: result.value.email,
                displayName: '',
                role: result.value.role,
                plan: result.value.plan,
                statusLabel: result.value.role == AppRole.user
                    ? 'active'
                    : 'staff',
                lastSeenAt: null,
                updatedAt: DateTime.now(),
              ),
            );
      }
      ref.invalidate(adminUsersPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }
  }

  Future<void> _retryLastInvite(BuildContext context) async {
    final request = _lastInviteRequest;
    if (request == null) {
      return;
    }

    setState(() {
      _isInviteBusy = true;
    });
    final repository = ref.read(adminUserManagementRepositoryProvider);
    final result = await repository.retryInvite(request);
    if (mounted) {
      setState(() {
        _isInviteBusy = false;
        _lastInviteResult = switch (result) {
          AppSuccess<AdminInviteResult>() => result.value,
          AppFailure<AdminInviteResult>() => AdminInviteResult(
            accepted: false,
            email: request.email,
            role: request.role,
            plan: request.plan,
            retryCount: (_lastInviteResult?.retryCount ?? 0) + 1,
            errorMessage: result.message,
          ),
        };
      });
    }
    if (!context.mounted) {
      return;
    }
    _showInviteSnackBar(context, result);
    if (result case AppSuccess<AdminInviteResult>()) {
      if (result.value.accepted && result.value.invitedUserId != null) {
        ref
            .read(adminUserListOverridesProvider.notifier)
            .upsert(
              AdminUserListItem(
                id: result.value.invitedUserId!,
                email: result.value.email,
                displayName: '',
                role: result.value.role,
                plan: result.value.plan,
                statusLabel: result.value.role == AppRole.user
                    ? 'active'
                    : 'staff',
                lastSeenAt: null,
                updatedAt: DateTime.now(),
              ),
            );
      }
      ref.invalidate(adminUsersPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
    }
  }

  Future<void> _applySingleUpdate(
    BuildContext context, {
    required AdminUserListItem user,
    required AppRole nextRole,
    required EntitlementPlan nextPlan,
  }) async {
    if (user.role == nextRole && user.plan == nextPlan) {
      return;
    }
    if (!await _confirmRoleMutation(
      context,
      nextRole: nextRole,
      subjectLabel: user.email,
      currentRole: user.role,
      currentPlan: user.plan,
      nextPlan: nextPlan,
    )) {
      return;
    }

    final repository = ref.read(adminUserManagementRepositoryProvider);
    final result = await repository.setUserAccess(
      userId: user.id,
      role: nextRole,
      plan: nextPlan,
    );
    if (!context.mounted) {
      return;
    }
    _showResultSnackBar(
      context,
      result,
      successMessage: 'Kullanici erisimi guncellendi.',
    );
    if (result is AppSuccess<void>) {
      ref
          .read(adminUserListOverridesProvider.notifier)
          .upsert(
            user.copyWith(
              role: nextRole,
              plan: nextPlan,
              updatedAt: DateTime.now(),
            ),
          );
      ref.invalidate(adminUsersPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
      ref.read(adminSelectedUserIdsProvider.notifier).removeAll([user.id]);
      ref
          .read(adminAuditOverridesProvider.notifier)
          .push(
            AdminAuditRecord(
              id: 'user-${user.id}-${DateTime.now().millisecondsSinceEpoch}',
              title: 'admin.user_access.updated',
              subtitle:
                  '${user.email} -> role=${formatRoleLabel(nextRole)}, plan=${nextPlan.value}',
              timestampLabel: 'az once',
            ),
          );
    }
  }

  Future<void> _openEditDialog(
    BuildContext context, {
    required AdminUserListItem user,
  }) async {
    final draft = await showDialog<_UserEditDraft>(
      context: context,
      builder: (context) => _EditUserDialog(
        user: user,
        allowDeveloperGrant: ref.read(adminAccessProvider).canManageRoles,
      ),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    if (!await _confirmRoleMutation(
      context,
      nextRole: draft.role,
      subjectLabel: draft.email,
      currentRole: user.role,
      currentPlan: user.plan,
      nextPlan: draft.plan,
    )) {
      return;
    }

    final repository = ref.read(adminUserManagementRepositoryProvider);
    final result = await repository.updateUser(
      AdminUserUpdateRequest(
        userId: user.id,
        email: draft.email,
        displayName: draft.displayName,
        role: draft.role,
        plan: draft.plan,
      ),
    );
    if (!context.mounted) {
      return;
    }

    switch (result) {
      case AppSuccess<AdminUserListItem>():
        ref.read(adminDeletedUserIdsProvider.notifier).remove(user.id);
        ref.read(adminUserListOverridesProvider.notifier).upsert(result.value);
        ref.invalidate(adminUsersPageProvider);
        ref.invalidate(adminDashboardSnapshotProvider);
        ref.invalidate(adminAuditFeedProvider);
        ref
            .read(adminAuditOverridesProvider.notifier)
            .push(
              AdminAuditRecord(
                id: 'user-edit-${user.id}-${DateTime.now().millisecondsSinceEpoch}',
                title: 'admin.user.updated',
                subtitle:
                    '${result.value.email} -> role=${formatRoleLabel(result.value.role)}, plan=${result.value.plan.value}',
                timestampLabel: 'az once',
              ),
            );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kullanici guncellendi.')));
      case AppFailure<AdminUserListItem>():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _deleteUser(
    BuildContext context, {
    required AdminUserListItem user,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullaniciyi sil'),
        content: Text(
          '${user.email} kalici olarak silinecek. Auth hesabi, profil, rol ve plan kayitlari kaldirilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kullaniciyi Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final repository = ref.read(adminUserManagementRepositoryProvider);
    final result = await repository.deleteUser(userId: user.id);
    if (!context.mounted) {
      return;
    }

    if (result is AppSuccess<void>) {
      ref.read(adminDeletedUserIdsProvider.notifier).add(user.id);
      ref.read(adminUserListOverridesProvider.notifier).remove(user.id);
      ref.read(adminSelectedUserIdsProvider.notifier).removeAll([user.id]);
      ref.invalidate(adminUsersPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
      ref
          .read(adminAuditOverridesProvider.notifier)
          .push(
            AdminAuditRecord(
              id: 'user-delete-${user.id}-${DateTime.now().millisecondsSinceEpoch}',
              title: 'admin.user.deleted',
              subtitle: user.email,
              timestampLabel: 'az once',
            ),
          );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kullanici silindi.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text((result as AppFailure<void>).message)),
    );
  }

  Future<void> _applyBulkUpdate(
    BuildContext context,
    AdminBulkUserUpdate update,
  ) async {
    if (update.userIds.isEmpty) {
      return;
    }
    final roleLabel = update.role == null ? '-' : formatRoleLabel(update.role!);
    final planLabel = update.plan?.value ?? '-';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplu erisim guncelle'),
        content: Text(
          '${update.userIds.length} kullanici icin role=$roleLabel, plan=$planLabel uygulanacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (update.role == AppRole.developer &&
        !await _confirmDeveloperAssignment(context)) {
      return;
    }

    setState(() {
      _isBulkBusy = true;
    });
    final repository = ref.read(adminUserManagementRepositoryProvider);
    final result = await repository.bulkSetUserAccess(update);
    if (mounted) {
      setState(() {
        _isBulkBusy = false;
      });
    }
    if (!context.mounted) {
      return;
    }
    _showResultSnackBar(
      context,
      result,
      successMessage: 'Toplu kullanici guncellemesi tamamlandi.',
    );
    if (result is AppSuccess<void>) {
      final currentPage = ref.read(adminUsersPageProvider).valueOrNull;
      if (currentPage != null) {
        ref
            .read(adminUserListOverridesProvider.notifier)
            .upsertAll(
              currentPage.items
                  .where((item) => update.userIds.contains(item.id))
                  .map(
                    (item) => item.copyWith(
                      role: update.role ?? item.role,
                      plan: update.plan ?? item.plan,
                      updatedAt: DateTime.now(),
                    ),
                  ),
            );
      }
      ref.invalidate(adminUsersPageProvider);
      ref.invalidate(adminDashboardSnapshotProvider);
      ref.invalidate(adminAuditFeedProvider);
      ref.read(adminSelectedUserIdsProvider.notifier).clear();
      ref
          .read(adminAuditOverridesProvider.notifier)
          .push(
            AdminAuditRecord(
              id: 'bulk-users-${DateTime.now().millisecondsSinceEpoch}',
              title: 'admin.user_access.bulk_updated',
              subtitle:
                  '${update.userIds.length} hesap -> role=${update.role?.value ?? '-'}, plan=${update.plan?.value ?? '-'}',
              timestampLabel: 'az once',
            ),
          );
    }
  }

  Future<bool> _confirmRoleMutation(
    BuildContext context, {
    required AppRole nextRole,
    required String subjectLabel,
    required EntitlementPlan nextPlan,
    AppRole? currentRole,
    EntitlementPlan? currentPlan,
  }) async {
    final requiresReauth = ref
        .read(adminActiveSettingsProvider)
        .security
        .reauthRequiredForRoleChanges;
    if (requiresReauth || currentRole != null || currentPlan != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erisim degisikligini onayla'),
          content: Text(
            '$subjectLabel icin role=${formatRoleLabel(nextRole)}, plan=${nextPlan.value} uygulanacak.',
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
      if (confirmed != true) {
        return false;
      }
    }

    if (nextRole != AppRole.developer) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    return _confirmDeveloperAssignment(context);
  }

  Future<bool> _confirmDeveloperAssignment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer rolunu tekrar onayla'),
        content: const Text(
          'Developer rolu yuksek yetkili bir roldur ve sadece developer tarafindan atanmalidir.',
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
    return confirmed ?? false;
  }

  void _showResultSnackBar(
    BuildContext context,
    AppResult<void> result, {
    required String successMessage,
  }) {
    final message = switch (result) {
      AppSuccess<void>() => successMessage,
      AppFailure<void>() => result.message,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showInviteSnackBar(
    BuildContext context,
    AppResult<AdminInviteResult> result,
  ) {
    final message = switch (result) {
      AppSuccess<AdminInviteResult>() =>
        result.value.accepted
            ? 'Davet Supabase tarafinda kuyruga alindi.'
            : (result.value.errorMessage ?? 'Davet reddedildi.'),
      AppFailure<AdminInviteResult>() => result.message,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectionCount,
    required this.allowDeveloperGrant,
    required this.isBusy,
    required this.onClear,
    required this.onApplyRole,
    required this.onApplyPlan,
  });

  final int selectionCount;
  final bool allowDeveloperGrant;
  final bool isBusy;
  final VoidCallback onClear;
  final ValueChanged<AppRole> onApplyRole;
  final ValueChanged<EntitlementPlan> onApplyPlan;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$selectionCount kullanici secildi'),
        FilledButton.tonal(
          onPressed: isBusy ? null : () => onApplyRole(AppRole.user),
          child: const Text('Role user'),
        ),
        FilledButton.tonal(
          onPressed: isBusy ? null : () => onApplyRole(AppRole.admin),
          child: const Text('Role admin'),
        ),
        if (allowDeveloperGrant)
          FilledButton.tonal(
            onPressed: isBusy ? null : () => onApplyRole(AppRole.developer),
            child: const Text('Role developer'),
          ),
        FilledButton.tonal(
          onPressed: isBusy ? null : () => onApplyPlan(EntitlementPlan.free),
          child: const Text('Plan free'),
        ),
        FilledButton.tonal(
          onPressed: isBusy ? null : () => onApplyPlan(EntitlementPlan.pro),
          child: const Text('Plan pro'),
        ),
        TextButton(
          onPressed: isBusy ? null : onClear,
          child: const Text('Temizle'),
        ),
      ],
    );
  }
}

class _AdminUserListRow extends StatelessWidget {
  const _AdminUserListRow({
    required this.user,
    required this.isSelected,
    required this.allowDeveloperGrant,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
    required this.onApplyUpdate,
  });

  final AdminUserListItem user;
  final bool isSelected;
  final bool allowDeveloperGrant;
  final VoidCallback onSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function({AppRole? role, EntitlementPlan? plan})
  onApplyUpdate;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: isSelected, onChanged: (_) => onSelected()),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (user.displayName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(user.displayName),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(label: 'durum ${user.statusLabel}'),
                    _InfoChip(label: 'rol ${formatRoleLabel(user.role)}'),
                    _InfoChip(label: 'plan ${user.plan.value}'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.lastSeenAt == null
                      ? 'Son aktivite yok'
                      : 'Son aktivite ${_formatDate(user.lastSeenAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                ),
                const SizedBox(height: 4),
                Text(
                  user.updatedAt == null
                      ? 'Guncellenmedi'
                      : 'Guncelleme ${_formatDate(user.updatedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) {
              if (!allowDeveloperGrant && user.role == AppRole.developer) {
                return const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    enabled: false,
                    value: 'blocked',
                    child: Text('Developer hesabi'),
                  ),
                ];
              }

              return <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Duzenle'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Kullaniciyi sil'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'role:user',
                  child: Text('Role user'),
                ),
                const PopupMenuItem<String>(
                  value: 'role:admin',
                  child: Text('Role admin'),
                ),
                if (allowDeveloperGrant)
                  const PopupMenuItem<String>(
                    value: 'role:developer',
                    child: Text('Role developer'),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'plan:free',
                  child: Text('Plan free'),
                ),
                const PopupMenuItem<String>(
                  value: 'plan:pro',
                  child: Text('Plan pro'),
                ),
              ];
            },
            onSelected: (value) {
              switch (value) {
                case 'blocked':
                  return;
                case 'edit':
                  onEdit();
                case 'delete':
                  onDelete();
                case 'role:user':
                  onApplyUpdate(role: AppRole.user);
                case 'role:admin':
                  onApplyUpdate(role: AppRole.admin);
                case 'role:developer':
                  onApplyUpdate(role: AppRole.developer);
                case 'plan:free':
                  onApplyUpdate(plan: EntitlementPlan.free);
                case 'plan:pro':
                  onApplyUpdate(plan: EntitlementPlan.pro);
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.more_vert_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteUserDialog extends StatefulWidget {
  const _InviteUserDialog();

  @override
  State<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<_InviteUserDialog> {
  late final TextEditingController _emailController;
  AppRole _role = AppRole.user;
  EntitlementPlan _plan = EntitlementPlan.free;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Kullanici Daveti'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AppRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: AppRole.user, child: Text('user')),
                DropdownMenuItem(value: AppRole.admin, child: Text('admin')),
                DropdownMenuItem(
                  value: AppRole.developer,
                  child: Text('developer'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _role = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<EntitlementPlan>(
              initialValue: _plan,
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
                if (value == null) {
                  return;
                }
                setState(() {
                  _plan = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () {
            final email = _emailController.text.trim();
            if (email.isEmpty) {
              return;
            }
            Navigator.of(
              context,
            ).pop(_InviteDraft(email: email, role: _role, plan: _plan));
          },
          child: const Text('Davet Gonder'),
        ),
      ],
    );
  }
}

class _InviteDraft {
  const _InviteDraft({
    required this.email,
    required this.role,
    required this.plan,
  });

  final String email;
  final AppRole role;
  final EntitlementPlan plan;
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({
    required this.user,
    required this.allowDeveloperGrant,
  });

  final AdminUserListItem user;
  final bool allowDeveloperGrant;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _displayNameController;
  late AppRole _role;
  late EntitlementPlan _plan;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user.email);
    _displayNameController = TextEditingController(
      text: widget.user.displayName,
    );
    _role = widget.user.role;
    _plan = widget.user.plan;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kullaniciyi Duzenle'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: 'Gorunen ad'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AppRole>(
              initialValue: _role,
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
                if (widget.allowDeveloperGrant ||
                    widget.user.role == AppRole.developer)
                  const DropdownMenuItem(
                    value: AppRole.developer,
                    child: Text('developer'),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _role = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<EntitlementPlan>(
              initialValue: _plan,
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
                if (value == null) {
                  return;
                }
                setState(() {
                  _plan = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: () {
            final email = _emailController.text.trim();
            if (email.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              _UserEditDraft(
                email: email,
                displayName: _displayNameController.text.trim(),
                role: _role,
                plan: _plan,
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _UserEditDraft {
  const _UserEditDraft({
    required this.email,
    required this.displayName,
    required this.role,
    required this.plan,
  });

  final String email;
  final String displayName;
  final AppRole role;
  final EntitlementPlan plan;
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}
