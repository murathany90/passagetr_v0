import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/admin_console_models.dart';
import '../../core/admin_providers.dart';
import '../common/admin_page_parts.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final _maintenanceMessageController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _auditRecipientsController = TextEditingController();

  @override
  void dispose() {
    _maintenanceMessageController.dispose();
    _supportEmailController.dispose();
    _auditRecipientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(adminAccessProvider);
    final config = ref.watch(adminAppConfigProvider);
    final auditFeed = ref.watch(adminAuditFeedProvider);
    final aiCoverPoolStatus = ref.watch(adminAiCoverPoolStatusProvider);
    final state = ref.watch(adminSettingsStateProvider);
    final controller = ref.read(adminSettingsStateProvider.notifier);

    ref.listen<AdminSettingsState>(adminSettingsStateProvider, (
      previous,
      next,
    ) {
      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
        controller.clearTransientMessages();
      } else if (previous?.noticeMessage != next.noticeMessage &&
          next.noticeMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.noticeMessage!)));
        controller.clearTransientMessages();
      }
    });

    _syncControllers(state.draft);

    return DefaultTabController(
      length: 5,
      child: AdminShellFrame(
        destination: AdminDestination.settings,
        title: 'Ayarlar ve Audit',
        subtitle:
            'Kalici product config, guvenlik ve veri yonetimi ayarlari bu panelde tutulur.',
        accessContext: accessContext,
        headerAction: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            TextButton(
              onPressed: state.isLoading || !state.isDirty
                  ? null
                  : controller.resetDraft,
              child: const Text('Reset'),
            ),
            FilledButton.icon(
              onPressed: state.isLoading || state.isSaving || !state.isDirty
                  ? null
                  : () async {
                      await controller.save();
                      if (!mounted) {
                        return;
                      }
                      ref.invalidate(adminAuditFeedProvider);
                      ref.invalidate(adminDashboardSnapshotProvider);
                      ref.invalidate(adminAiCoverPoolStatusProvider);
                    },
              icon: const Icon(Icons.save_rounded),
              label: Text(state.isSaving ? 'Kaydediliyor...' : 'Kaydet'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isLoading || state.isSaving) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
            ],
            Container(
              decoration: BoxDecoration(
                color: AppThemeTokens.of(context).surface,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(8),
              child: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Genel'),
                  Tab(text: 'Bildirimler'),
                  Tab(text: 'Guvenlik'),
                  Tab(text: 'Veri Yonetimi'),
                  Tab(text: 'AI Cover'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
                final editorPanel = AdminPanelCard(
                  title: 'Product Config',
                  trailing: state.isDirty
                      ? const _InfoChip(label: 'Kaydedilmemis degisiklik')
                      : const _InfoChip(label: 'Kaydedildi'),
                  child: SizedBox(
                    height: 620,
                    child: TabBarView(
                      children: [
                        _GeneralSettingsTab(
                          snapshot: state.draft,
                          maintenanceMessageController:
                              _maintenanceMessageController,
                          supportEmailController: _supportEmailController,
                          onChanged: controller.updateDraft,
                        ),
                        _NotificationSettingsTab(
                          snapshot: state.draft,
                          auditRecipientsController: _auditRecipientsController,
                          onChanged: controller.updateDraft,
                        ),
                        _SecuritySettingsTab(
                          snapshot: state.draft,
                          onChanged: controller.updateDraft,
                        ),
                        _DataManagementSettingsTab(
                          snapshot: state.draft,
                          onChanged: controller.updateDraft,
                        ),
                        _AiCoverSettingsTab(
                          snapshot: state.draft,
                          poolStatus: aiCoverPoolStatus,
                          onChanged: controller.updateDraft,
                        ),
                      ],
                    ),
                  ),
                );

                final sidePanel = Column(
                  children: [
                    AdminPanelCard(
                      title: 'Sistem Ozeti',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingRow(
                            label: 'Environment',
                            value: config.environment.value,
                          ),
                          _SettingRow(
                            label: 'Platform',
                            value: config.platformMode.value,
                          ),
                          _SettingRow(
                            label: 'Supabase',
                            value: config.supabaseEnabled ? 'bagli' : 'preview',
                          ),
                          _SettingRow(
                            label: 'Branch',
                            value: config.branchName,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AdminPanelCard(
                      title: 'Audit Akisi',
                      child: auditFeed.when(
                        data: (feed) {
                          if (!feed.hasRecords) {
                            return AdminEmptyState(
                              title: feed.isUnavailable
                                  ? 'Audit akisi kullanilamiyor'
                                  : 'Henuz audit kaydi yok',
                              message:
                                  feed.message ??
                                  'Ilk yonetim islemi burada listelenecek.',
                              icon: feed.isUnavailable
                                  ? Icons.lock_outline_rounded
                                  : Icons.history_toggle_off_rounded,
                            );
                          }
                          return Column(
                            children: [
                              for (final item in feed.records.take(8)) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.title),
                                  subtitle: Text(item.subtitle),
                                  trailing: Text(item.timestampLabel),
                                ),
                                const Divider(height: 1),
                              ],
                            ],
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => Text(error.toString()),
                      ),
                    ),
                  ],
                );

                if (!isWide) {
                  return Column(
                    children: [
                      editorPanel,
                      const SizedBox(height: 16),
                      sidePanel,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: editorPanel),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: sidePanel),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _syncControllers(AdminSettingsSnapshot snapshot) {
    _setControllerValue(
      _maintenanceMessageController,
      snapshot.general.maintenanceMessage,
    );
    _setControllerValue(_supportEmailController, snapshot.general.supportEmail);
    _setControllerValue(
      _auditRecipientsController,
      snapshot.notifications.auditDigestRecipients.join(', '),
    );
  }

  void _setControllerValue(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _GeneralSettingsTab extends StatelessWidget {
  const _GeneralSettingsTab({
    required this.snapshot,
    required this.maintenanceMessageController,
    required this.supportEmailController,
    required this.onChanged,
  });

  final AdminSettingsSnapshot snapshot;
  final TextEditingController maintenanceMessageController;
  final TextEditingController supportEmailController;
  final ValueChanged<AdminSettingsSnapshot> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SwitchListTile(
          value: snapshot.general.maintenanceMode,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              general: snapshot.general.copyWith(maintenanceMode: value),
            ),
          ),
          title: const Text('Maintenance mode'),
          subtitle: const Text(
            'Admin disi yuzeyler gecici olarak bakim moduna girsin.',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: maintenanceMessageController,
          decoration: const InputDecoration(labelText: 'Maintenance message'),
          maxLines: 3,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              general: snapshot.general.copyWith(
                maintenanceMessage: value.trim(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: supportEmailController,
          decoration: const InputDecoration(labelText: 'Support email'),
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              general: snapshot.general.copyWith(supportEmail: value.trim()),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationSettingsTab extends StatelessWidget {
  const _NotificationSettingsTab({
    required this.snapshot,
    required this.auditRecipientsController,
    required this.onChanged,
  });

  final AdminSettingsSnapshot snapshot;
  final TextEditingController auditRecipientsController;
  final ValueChanged<AdminSettingsSnapshot> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SwitchListTile(
          value: snapshot.notifications.notifyOnBulkUserUpdates,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              notifications: snapshot.notifications.copyWith(
                notifyOnBulkUserUpdates: value,
              ),
            ),
          ),
          title: const Text('Bulk user updates'),
          subtitle: const Text(
            'Toplu kullanici mutasyonlari icin bildirim uret.',
          ),
        ),
        SwitchListTile(
          value: snapshot.notifications.notifyOnContentPublish,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              notifications: snapshot.notifications.copyWith(
                notifyOnContentPublish: value,
              ),
            ),
          ),
          title: const Text('Content publish'),
          subtitle: const Text('Yayinlanan icerikler icin bildirim uret.'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: auditRecipientsController,
          decoration: const InputDecoration(
            labelText: 'Audit digest recipients',
            helperText: 'Virgulle ayir: ops@passagetr.dev, owner@passagetr.dev',
          ),
          maxLines: 2,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              notifications: snapshot.notifications.copyWith(
                auditDigestRecipients: value
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecuritySettingsTab extends StatelessWidget {
  const _SecuritySettingsTab({required this.snapshot, required this.onChanged});

  final AdminSettingsSnapshot snapshot;
  final ValueChanged<AdminSettingsSnapshot> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _NumberField(
          label: 'Session idle timeout (minutes)',
          value: snapshot.security.sessionIdleTimeoutMinutes,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              security: snapshot.security.copyWith(
                sessionIdleTimeoutMinutes: value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Invite expiry (hours)',
          value: snapshot.security.inviteExpiryHours,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              security: snapshot.security.copyWith(inviteExpiryHours: value),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: snapshot.security.reauthRequiredForRoleChanges,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              security: snapshot.security.copyWith(
                reauthRequiredForRoleChanges: value,
              ),
            ),
          ),
          title: const Text('Reauth required for role changes'),
          subtitle: const Text(
            'Rol degisikliklerinde ek onay diyaloğu zorlansin.',
          ),
        ),
      ],
    );
  }
}

class _DataManagementSettingsTab extends StatelessWidget {
  const _DataManagementSettingsTab({
    required this.snapshot,
    required this.onChanged,
  });

  final AdminSettingsSnapshot snapshot;
  final ValueChanged<AdminSettingsSnapshot> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _NumberField(
          label: 'Default list page size',
          value: snapshot.dataManagement.defaultListPageSize,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              dataManagement: snapshot.dataManagement.copyWith(
                defaultListPageSize: value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: snapshot.dataManagement.csvImportDuplicateStrategy,
          decoration: const InputDecoration(
            labelText: 'CSV duplicate strategy',
          ),
          items: const [
            DropdownMenuItem(value: 'upsert', child: Text('upsert')),
            DropdownMenuItem(value: 'skip', child: Text('skip')),
            DropdownMenuItem(value: 'error', child: Text('error')),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            onChanged(
              snapshot.copyWith(
                dataManagement: snapshot.dataManagement.copyWith(
                  csvImportDuplicateStrategy: value,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: snapshot.dataManagement.defaultPublishStateForImports,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              dataManagement: snapshot.dataManagement.copyWith(
                defaultPublishStateForImports: value,
              ),
            ),
          ),
          title: const Text('Publish imported content by default'),
          subtitle: const Text(
            'CSV ve toplu import islerinde ilk publish durumu.',
          ),
        ),
      ],
    );
  }
}

class _AiCoverSettingsTab extends StatelessWidget {
  const _AiCoverSettingsTab({
    required this.snapshot,
    required this.poolStatus,
    required this.onChanged,
  });

  final AdminSettingsSnapshot snapshot;
  final AsyncValue<AdminAiCoverPoolStatus> poolStatus;
  final ValueChanged<AdminSettingsSnapshot> onChanged;

  @override
  Widget build(BuildContext context) {
    final modelConfigs = snapshot.aiCover.sortedModels;
    final usageByKey = switch (poolStatus.valueOrNull) {
      AdminAiCoverPoolStatus() => {
        for (final item in poolStatus.valueOrNull!.models)
          '${item.provider}::${item.model}': item,
      },
      _ => const <String, AdminAiCoverModelUsageStatus>{},
    };

    return ListView(
      children: [
        SwitchListTile(
          value: snapshot.aiCover.localCapsEnabled,
          onChanged: (value) => onChanged(
            snapshot.copyWith(
              aiCover: snapshot.aiCover.copyWith(localCapsEnabled: value),
            ),
          ),
          title: const Text('Yerel cap kontrolu aktif'),
          subtitle: const Text(
            'Gunluk istek sayisi uygulama tarafinda da sinirlansin.',
          ),
        ),
        const SizedBox(height: 8),
        switch (poolStatus) {
          AsyncLoading<AdminAiCoverPoolStatus>() => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
          AsyncError<AdminAiCoverPoolStatus>(error: final error) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Kullanim durumu okunamadi: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          _ => const SizedBox.shrink(),
        },
        for (var index = 0; index < modelConfigs.length; index++) ...[
          Builder(
            builder: (context) {
              final config = modelConfigs[index];
              final usage = usageByKey['${config.provider}::${config.modelId}'];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adminAiModelLabel(config.modelId),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(
                                    label:
                                        config.provider ==
                                            adminAiProviderImageRouter
                                        ? 'ImageRouter'
                                        : 'Hugging Face',
                                  ),
                                  _InfoChip(
                                    label:
                                        'Bugun ${usage?.attemptCount ?? 0}/${config.dailyCap}',
                                  ),
                                  _InfoChip(
                                    label:
                                        'Basarili ${usage?.successCount ?? 0}',
                                  ),
                                  _InfoChip(
                                    label: 'Hata ${usage?.failedCount ?? 0}',
                                  ),
                                  _InfoChip(
                                    label:
                                        'Rate limit ${usage?.rateLimitedCount ?? 0}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: index > 0
                              ? () => onChanged(
                                  snapshot.copyWith(
                                    aiCover: snapshot.aiCover.copyWith(
                                      models: _moveAiCoverModel(
                                        modelConfigs,
                                        index,
                                        index - 1,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                          tooltip: 'Yukarı taşı',
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        IconButton(
                          onPressed: index < modelConfigs.length - 1
                              ? () => onChanged(
                                  snapshot.copyWith(
                                    aiCover: snapshot.aiCover.copyWith(
                                      models: _moveAiCoverModel(
                                        modelConfigs,
                                        index,
                                        index + 1,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                          tooltip: 'Aşağı taşı',
                          icon: const Icon(Icons.arrow_downward_rounded),
                        ),
                        Switch(
                          value: config.enabled,
                          onChanged: (value) => onChanged(
                            snapshot.copyWith(
                              aiCover: snapshot.aiCover.copyWith(
                                models: _replaceAiCoverModel(
                                  modelConfigs,
                                  config.copyWith(enabled: value),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              'daily-cap-${config.provider}-${config.modelId}',
                            ),
                            initialValue: config.dailyCap.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Daily cap',
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value.trim());
                              if (parsed == null) {
                                return;
                              }
                              onChanged(
                                snapshot.copyWith(
                                  aiCover: snapshot.aiCover.copyWith(
                                    models: _replaceAiCoverModel(
                                      modelConfigs,
                                      config.copyWith(dailyCap: parsed),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              'lifetime-cap-${config.provider}-${config.modelId}',
                            ),
                            initialValue: config.lifetimeCap?.toString() ?? '',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Lifetime cap (opsiyonel)',
                            ),
                            onChanged: (value) {
                              final trimmed = value.trim();
                              onChanged(
                                snapshot.copyWith(
                                  aiCover: snapshot.aiCover.copyWith(
                                    models: _replaceAiCoverModel(
                                      modelConfigs,
                                      trimmed.isEmpty
                                          ? config.copyWith(
                                              clearLifetimeCap: true,
                                            )
                                          : config.copyWith(
                                              lifetimeCap: int.tryParse(
                                                trimmed,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: (value) =>
          widget.onChanged(int.tryParse(value.trim()) ?? widget.value),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

List<AdminAiCoverModelConfig> _replaceAiCoverModel(
  List<AdminAiCoverModelConfig> items,
  AdminAiCoverModelConfig next,
) {
  return items
      .map(
        (item) => item.provider == next.provider && item.modelId == next.modelId
            ? next
            : item,
      )
      .toList(growable: false);
}

List<AdminAiCoverModelConfig> _moveAiCoverModel(
  List<AdminAiCoverModelConfig> items,
  int fromIndex,
  int toIndex,
) {
  final reordered = List<AdminAiCoverModelConfig>.from(items);
  final item = reordered.removeAt(fromIndex);
  reordered.insert(toIndex, item);
  return List<AdminAiCoverModelConfig>.generate(
    reordered.length,
    (index) => reordered[index].copyWith(priority: index + 1),
    growable: false,
  );
}
