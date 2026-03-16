import 'package:shared_core/shared_core.dart';

import 'admin_ai_reading_contracts.dart';

enum AdminUserStatusFilter { all, active, anonymous, staff }

extension AdminUserStatusFilterX on AdminUserStatusFilter {
  String get value => switch (this) {
    AdminUserStatusFilter.all => 'all',
    AdminUserStatusFilter.active => 'active',
    AdminUserStatusFilter.anonymous => 'anonymous',
    AdminUserStatusFilter.staff => 'staff',
  };

  static AdminUserStatusFilter? fromValue(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    for (final item in AdminUserStatusFilter.values) {
      if (item.value == value) {
        return item;
      }
    }
    return null;
  }
}

class AdminPage<T> {
  const AdminPage({
    required this.items,
    required this.totalCount,
    required this.offset,
    required this.limit,
  });

  final List<T> items;
  final int totalCount;
  final int offset;
  final int limit;

  bool get hasPreviousPage => offset > 0;
  bool get hasNextPage => offset + items.length < totalCount;
}

class AdminUserListQuery {
  const AdminUserListQuery({
    this.query = '',
    this.role,
    this.plan,
    this.status,
    this.offset = 0,
    this.limit = 50,
  });

  final String query;
  final AppRole? role;
  final EntitlementPlan? plan;
  final AdminUserStatusFilter? status;
  final int offset;
  final int limit;

  AdminUserListQuery copyWith({
    String? query,
    AppRole? role,
    EntitlementPlan? plan,
    AdminUserStatusFilter? status,
    int? offset,
    int? limit,
    bool clearRole = false,
    bool clearPlan = false,
    bool clearStatus = false,
  }) {
    return AdminUserListQuery(
      query: query ?? this.query,
      role: clearRole ? null : role ?? this.role,
      plan: clearPlan ? null : plan ?? this.plan,
      status: clearStatus ? null : status ?? this.status,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

class AdminUserListItem {
  const AdminUserListItem({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.plan,
    required this.statusLabel,
    required this.lastSeenAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final AppRole role;
  final EntitlementPlan plan;
  final String statusLabel;
  final DateTime? lastSeenAt;
  final DateTime? updatedAt;

  AdminUserListItem copyWith({
    String? email,
    String? displayName,
    AppRole? role,
    EntitlementPlan? plan,
    String? statusLabel,
    DateTime? lastSeenAt,
    DateTime? updatedAt,
  }) {
    return AdminUserListItem(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      plan: plan ?? this.plan,
      statusLabel: statusLabel ?? this.statusLabel,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AdminBulkUserUpdate {
  const AdminBulkUserUpdate({required this.userIds, this.role, this.plan});

  final List<String> userIds;
  final AppRole? role;
  final EntitlementPlan? plan;
}

enum AdminBulkUserDeleteItemStatus { deleted, skipped, failed }

extension AdminBulkUserDeleteItemStatusX on AdminBulkUserDeleteItemStatus {
  String get value => switch (this) {
    AdminBulkUserDeleteItemStatus.deleted => 'deleted',
    AdminBulkUserDeleteItemStatus.skipped => 'skipped',
    AdminBulkUserDeleteItemStatus.failed => 'failed',
  };

  static AdminBulkUserDeleteItemStatus fromValue(String? value) {
    for (final item in AdminBulkUserDeleteItemStatus.values) {
      if (item.value == value) {
        return item;
      }
    }
    return AdminBulkUserDeleteItemStatus.failed;
  }
}

class AdminBulkUserDeleteItemResult {
  const AdminBulkUserDeleteItemResult({
    required this.userId,
    required this.status,
    this.message,
  });

  final String userId;
  final AdminBulkUserDeleteItemStatus status;
  final String? message;

  bool get isDeleted => status == AdminBulkUserDeleteItemStatus.deleted;

  factory AdminBulkUserDeleteItemResult.fromJson(Map<String, dynamic> json) {
    return AdminBulkUserDeleteItemResult(
      userId: json['user_id']?.toString() ?? '',
      status: AdminBulkUserDeleteItemStatusX.fromValue(
        json['status']?.toString(),
      ),
      message: json['message']?.toString(),
    );
  }
}

class AdminBulkUserDeleteResult {
  const AdminBulkUserDeleteResult({
    required this.requestedCount,
    required this.deletedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.results,
  });

  final int requestedCount;
  final int deletedCount;
  final int skippedCount;
  final int failedCount;
  final List<AdminBulkUserDeleteItemResult> results;

  List<String> get deletedUserIds => results
      .where((item) => item.status == AdminBulkUserDeleteItemStatus.deleted)
      .map((item) => item.userId)
      .toList(growable: false);

  factory AdminBulkUserDeleteResult.fromJson(Map<String, dynamic> json) {
    final resultsJson = json['results'];
    final parsedResults = resultsJson is List
        ? resultsJson
              .whereType<Map>()
              .map(
                (item) => AdminBulkUserDeleteItemResult.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
        : const <AdminBulkUserDeleteItemResult>[];

    return AdminBulkUserDeleteResult(
      requestedCount:
          (json['requested_count'] as num?)?.toInt() ?? parsedResults.length,
      deletedCount:
          (json['deleted_count'] as num?)?.toInt() ??
          parsedResults
              .where(
                (item) => item.status == AdminBulkUserDeleteItemStatus.deleted,
              )
              .length,
      skippedCount:
          (json['skipped_count'] as num?)?.toInt() ??
          parsedResults
              .where(
                (item) => item.status == AdminBulkUserDeleteItemStatus.skipped,
              )
              .length,
      failedCount:
          (json['failed_count'] as num?)?.toInt() ??
          parsedResults
              .where(
                (item) => item.status == AdminBulkUserDeleteItemStatus.failed,
              )
              .length,
      results: parsedResults,
    );
  }
}

class AdminInviteRequest {
  const AdminInviteRequest({
    required this.email,
    required this.role,
    required this.plan,
    required this.inviteExpiryHours,
  });

  final String email;
  final AppRole role;
  final EntitlementPlan plan;
  final int inviteExpiryHours;
}

class AdminUserUpdateRequest {
  const AdminUserUpdateRequest({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.plan,
  });

  final String userId;
  final String email;
  final String displayName;
  final AppRole role;
  final EntitlementPlan plan;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'email': email,
    'display_name': displayName,
    'role': role.value,
    'plan': plan.value,
  };
}

class AdminGeneralSettings {
  const AdminGeneralSettings({
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
    this.supportEmail = '',
  });

  final bool maintenanceMode;
  final String maintenanceMessage;
  final String supportEmail;

  AdminGeneralSettings copyWith({
    bool? maintenanceMode,
    String? maintenanceMessage,
    String? supportEmail,
  }) {
    return AdminGeneralSettings(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      supportEmail: supportEmail ?? this.supportEmail,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'maintenance_mode': maintenanceMode,
    'maintenance_message': maintenanceMessage,
    'support_email': supportEmail,
  };

  factory AdminGeneralSettings.fromJson(Map<String, dynamic>? json) {
    return AdminGeneralSettings(
      maintenanceMode: json?['maintenance_mode'] as bool? ?? false,
      maintenanceMessage: json?['maintenance_message']?.toString() ?? '',
      supportEmail: json?['support_email']?.toString() ?? '',
    );
  }
}

class AdminNotificationSettings {
  const AdminNotificationSettings({
    this.notifyOnBulkUserUpdates = true,
    this.notifyOnContentPublish = true,
    this.auditDigestRecipients = const <String>[],
  });

  final bool notifyOnBulkUserUpdates;
  final bool notifyOnContentPublish;
  final List<String> auditDigestRecipients;

  AdminNotificationSettings copyWith({
    bool? notifyOnBulkUserUpdates,
    bool? notifyOnContentPublish,
    List<String>? auditDigestRecipients,
  }) {
    return AdminNotificationSettings(
      notifyOnBulkUserUpdates:
          notifyOnBulkUserUpdates ?? this.notifyOnBulkUserUpdates,
      notifyOnContentPublish:
          notifyOnContentPublish ?? this.notifyOnContentPublish,
      auditDigestRecipients:
          auditDigestRecipients ?? this.auditDigestRecipients,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'notify_on_bulk_user_updates': notifyOnBulkUserUpdates,
    'notify_on_content_publish': notifyOnContentPublish,
    'audit_digest_recipients': auditDigestRecipients,
  };

  factory AdminNotificationSettings.fromJson(Map<String, dynamic>? json) {
    final rawRecipients = json?['audit_digest_recipients'];
    return AdminNotificationSettings(
      notifyOnBulkUserUpdates:
          json?['notify_on_bulk_user_updates'] as bool? ?? true,
      notifyOnContentPublish:
          json?['notify_on_content_publish'] as bool? ?? true,
      auditDigestRecipients: switch (rawRecipients) {
        List<dynamic>() =>
          rawRecipients
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
        _ => const <String>[],
      },
    );
  }
}

class AdminSecuritySettings {
  const AdminSecuritySettings({
    this.sessionIdleTimeoutMinutes = 30,
    this.inviteExpiryHours = 48,
    this.reauthRequiredForRoleChanges = true,
  });

  final int sessionIdleTimeoutMinutes;
  final int inviteExpiryHours;
  final bool reauthRequiredForRoleChanges;

  AdminSecuritySettings copyWith({
    int? sessionIdleTimeoutMinutes,
    int? inviteExpiryHours,
    bool? reauthRequiredForRoleChanges,
  }) {
    return AdminSecuritySettings(
      sessionIdleTimeoutMinutes:
          sessionIdleTimeoutMinutes ?? this.sessionIdleTimeoutMinutes,
      inviteExpiryHours: inviteExpiryHours ?? this.inviteExpiryHours,
      reauthRequiredForRoleChanges:
          reauthRequiredForRoleChanges ?? this.reauthRequiredForRoleChanges,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'session_idle_timeout_minutes': sessionIdleTimeoutMinutes,
    'invite_expiry_hours': inviteExpiryHours,
    'reauth_required_for_role_changes': reauthRequiredForRoleChanges,
  };

  factory AdminSecuritySettings.fromJson(Map<String, dynamic>? json) {
    return AdminSecuritySettings(
      sessionIdleTimeoutMinutes:
          (json?['session_idle_timeout_minutes'] as num?)?.toInt() ?? 30,
      inviteExpiryHours: (json?['invite_expiry_hours'] as num?)?.toInt() ?? 48,
      reauthRequiredForRoleChanges:
          json?['reauth_required_for_role_changes'] as bool? ?? true,
    );
  }
}

class AdminDataManagementSettings {
  const AdminDataManagementSettings({
    this.defaultListPageSize = 50,
    this.csvImportDuplicateStrategy = 'upsert',
    this.defaultPublishStateForImports = true,
  });

  final int defaultListPageSize;
  final String csvImportDuplicateStrategy;
  final bool defaultPublishStateForImports;

  AdminDataManagementSettings copyWith({
    int? defaultListPageSize,
    String? csvImportDuplicateStrategy,
    bool? defaultPublishStateForImports,
  }) {
    return AdminDataManagementSettings(
      defaultListPageSize: defaultListPageSize ?? this.defaultListPageSize,
      csvImportDuplicateStrategy:
          csvImportDuplicateStrategy ?? this.csvImportDuplicateStrategy,
      defaultPublishStateForImports:
          defaultPublishStateForImports ?? this.defaultPublishStateForImports,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'default_list_page_size': defaultListPageSize,
    'csv_import_duplicate_strategy': csvImportDuplicateStrategy,
    'default_publish_state_for_imports': defaultPublishStateForImports,
  };

  factory AdminDataManagementSettings.fromJson(Map<String, dynamic>? json) {
    return AdminDataManagementSettings(
      defaultListPageSize:
          (json?['default_list_page_size'] as num?)?.toInt() ?? 50,
      csvImportDuplicateStrategy:
          json?['csv_import_duplicate_strategy']?.toString() ?? 'upsert',
      defaultPublishStateForImports:
          json?['default_publish_state_for_imports'] as bool? ?? true,
    );
  }
}

class AdminAiCoverModelConfig {
  const AdminAiCoverModelConfig({
    required this.provider,
    required this.modelId,
    this.enabled = true,
    this.dailyCap = adminAiImageRouterDefaultDailyCap,
    this.lifetimeCap,
    this.priority = 0,
  });

  final String provider;
  final String modelId;
  final bool enabled;
  final int dailyCap;
  final int? lifetimeCap;
  final int priority;

  AdminAiCoverModelConfig copyWith({
    String? provider,
    String? modelId,
    bool? enabled,
    int? dailyCap,
    int? lifetimeCap,
    int? priority,
    bool clearLifetimeCap = false,
  }) {
    return AdminAiCoverModelConfig(
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      enabled: enabled ?? this.enabled,
      dailyCap: dailyCap ?? this.dailyCap,
      lifetimeCap: clearLifetimeCap ? null : lifetimeCap ?? this.lifetimeCap,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'provider': provider,
    'model_id': modelId,
    'enabled': enabled,
    'daily_cap': dailyCap,
    'lifetime_cap': lifetimeCap,
    'priority': priority,
  };

  factory AdminAiCoverModelConfig.fromJson(Map<String, dynamic>? json) {
    final provider = _adminConsoleAiCoverProviderFromValue(json?['provider']) ??
        adminAiProviderImageRouter;
    final modelId = json?['model_id']?.toString() ?? '';
    final fallbackDailyCap = provider == adminAiProviderHuggingFace
        ? adminAiHuggingFaceDefaultDailyCap
        : adminAiImageRouterDefaultDailyCap;
    final fallbackLifetimeCap =
        provider == adminAiProviderImageRouter &&
            modelId == 'openai/gpt-image-1.5:free'
        ? adminAiImageRouterOpenAiLifetimeCap
        : null;

    return AdminAiCoverModelConfig(
      provider: provider,
      modelId: modelId,
      enabled: json?['enabled'] as bool? ?? true,
      dailyCap: (json?['daily_cap'] as num?)?.toInt() ?? fallbackDailyCap,
      lifetimeCap:
          (json?['lifetime_cap'] as num?)?.toInt() ?? fallbackLifetimeCap,
      priority: (json?['priority'] as num?)?.toInt() ?? 0,
    );
  }
}

String? _adminConsoleAiCoverProviderFromValue(Object? value) {
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  if (
      normalized == adminAiProviderImageRouter ||
      normalized == adminAiProviderHuggingFace ||
      normalized == adminAiProviderCoverAuto ||
      normalized == adminAiProviderGemini ||
      normalized == adminAiProviderOpenRouter) {
    return normalized;
  }
  return null;
}

List<AdminAiCoverModelConfig> adminDefaultAiCoverModelConfigs() {
  final items = <AdminAiCoverModelConfig>[];
  var priority = 1;
  for (final modelId in adminAiImageRouterCoverModels) {
    items.add(
      AdminAiCoverModelConfig(
        provider: adminAiProviderImageRouter,
        modelId: modelId,
        dailyCap: adminAiImageRouterDefaultDailyCap,
        lifetimeCap: modelId == 'openai/gpt-image-1.5:free'
            ? adminAiImageRouterOpenAiLifetimeCap
            : null,
        priority: priority++,
      ),
    );
  }
  for (final modelId in adminAiHuggingFaceCoverModels) {
    items.add(
      AdminAiCoverModelConfig(
        provider: adminAiProviderHuggingFace,
        modelId: modelId,
        dailyCap: adminAiHuggingFaceDefaultDailyCap,
        priority: priority++,
      ),
    );
  }
  return items;
}

class AdminAiCoverSettings {
  const AdminAiCoverSettings({
    this.localCapsEnabled = true,
    this.models = const <AdminAiCoverModelConfig>[],
  });

  final bool localCapsEnabled;
  final List<AdminAiCoverModelConfig> models;

  List<AdminAiCoverModelConfig> get sortedModels => List<AdminAiCoverModelConfig>.from(
    models.isEmpty ? adminDefaultAiCoverModelConfigs() : models,
  )..sort((left, right) {
    final byPriority = left.priority.compareTo(right.priority);
    if (byPriority != 0) {
      return byPriority;
    }
    return adminAiModelLabel(left.modelId).compareTo(
      adminAiModelLabel(right.modelId),
    );
  });

  AdminAiCoverSettings copyWith({
    bool? localCapsEnabled,
    List<AdminAiCoverModelConfig>? models,
  }) {
    return AdminAiCoverSettings(
      localCapsEnabled: localCapsEnabled ?? this.localCapsEnabled,
      models: models ?? this.models,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'local_caps_enabled': localCapsEnabled,
    'models': sortedModels.map((item) => item.toJson()).toList(growable: false),
  };

  factory AdminAiCoverSettings.fromJson(Map<String, dynamic>? json) {
    final rawModels = json?['models'];
    final parsedModels = switch (rawModels) {
      List<dynamic>() => rawModels
          .whereType<Map>()
          .map(
            (item) => AdminAiCoverModelConfig.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      _ => adminDefaultAiCoverModelConfigs(),
    };
    return AdminAiCoverSettings(
      localCapsEnabled: json?['local_caps_enabled'] as bool? ?? true,
      models: parsedModels,
    );
  }
}

class AdminSettingsSnapshot {
  const AdminSettingsSnapshot({
    this.general = const AdminGeneralSettings(),
    this.notifications = const AdminNotificationSettings(),
    this.security = const AdminSecuritySettings(),
    this.dataManagement = const AdminDataManagementSettings(),
    this.aiCover = const AdminAiCoverSettings(),
  });

  final AdminGeneralSettings general;
  final AdminNotificationSettings notifications;
  final AdminSecuritySettings security;
  final AdminDataManagementSettings dataManagement;
  final AdminAiCoverSettings aiCover;

  AdminSettingsSnapshot copyWith({
    AdminGeneralSettings? general,
    AdminNotificationSettings? notifications,
    AdminSecuritySettings? security,
    AdminDataManagementSettings? dataManagement,
    AdminAiCoverSettings? aiCover,
  }) {
    return AdminSettingsSnapshot(
      general: general ?? this.general,
      notifications: notifications ?? this.notifications,
      security: security ?? this.security,
      dataManagement: dataManagement ?? this.dataManagement,
      aiCover: aiCover ?? this.aiCover,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'general': general.toJson(),
    'notifications': notifications.toJson(),
    'security': security.toJson(),
    'data_management': dataManagement.toJson(),
    'ai_cover': aiCover.toJson(),
  };

  factory AdminSettingsSnapshot.fromJson(Map<String, dynamic>? json) {
    return AdminSettingsSnapshot(
      general: AdminGeneralSettings.fromJson(
        json?['general'] as Map<String, dynamic>?,
      ),
      notifications: AdminNotificationSettings.fromJson(
        json?['notifications'] as Map<String, dynamic>?,
      ),
      security: AdminSecuritySettings.fromJson(
        json?['security'] as Map<String, dynamic>?,
      ),
      dataManagement: AdminDataManagementSettings.fromJson(
        json?['data_management'] as Map<String, dynamic>?,
      ),
      aiCover: AdminAiCoverSettings.fromJson(
        json?['ai_cover'] as Map<String, dynamic>?,
      ),
    );
  }
}

class AdminTrendPoint {
  const AdminTrendPoint({required this.label, required this.value});

  final String label;
  final double value;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'value': value,
  };

  factory AdminTrendPoint.fromJson(Map<String, dynamic>? json) {
    return AdminTrendPoint(
      label: json?['label']?.toString() ?? '',
      value: (json?['value'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminDashboardMetric {
  const AdminDashboardMetric({required this.total, required this.delta});

  final int total;
  final int delta;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total': total,
    'delta': delta,
  };

  factory AdminDashboardMetric.fromJson(Map<String, dynamic>? json) {
    return AdminDashboardMetric(
      total: (json?['total'] as num?)?.toInt() ?? 0,
      delta: (json?['delta'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminDashboardInventoryMetric {
  const AdminDashboardInventoryMetric({
    required this.total,
    required this.publishedCount,
  });

  final int total;
  final int publishedCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total': total,
    'published_count': publishedCount,
  };

  factory AdminDashboardInventoryMetric.fromJson(Map<String, dynamic>? json) {
    return AdminDashboardInventoryMetric(
      total: (json?['total'] as num?)?.toInt() ?? 0,
      publishedCount: (json?['published_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminDashboardCoverageMetric {
  const AdminDashboardCoverageMetric({
    required this.total,
    required this.readyCount,
    required this.missingCount,
  });

  final int total;
  final int readyCount;
  final int missingCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total': total,
    'ready_count': readyCount,
    'missing_count': missingCount,
  };

  factory AdminDashboardCoverageMetric.fromJson(Map<String, dynamic>? json) {
    return AdminDashboardCoverageMetric(
      total: (json?['total'] as num?)?.toInt() ?? 0,
      readyCount: (json?['ready_count'] as num?)?.toInt() ?? 0,
      missingCount: (json?['missing_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminDashboardSnapshot {
  const AdminDashboardSnapshot({
    required this.windowDays,
    required this.userCount,
    required this.proUserCount,
    required this.readingInventory,
    required this.wordInventory,
    required this.grammarInventory,
    required this.miniTestCoverage,
    required this.coverCoverage,
    required this.linkedWordCoverage,
    required this.dictionaryMatchCoverage,
    required this.dictionaryEntryCount,
    required this.auditCount,
    required this.contentTrend,
    required this.maintenanceMode,
  });

  final int windowDays;
  final AdminDashboardMetric userCount;
  final AdminDashboardMetric proUserCount;
  final AdminDashboardInventoryMetric readingInventory;
  final AdminDashboardInventoryMetric wordInventory;
  final AdminDashboardInventoryMetric grammarInventory;
  final AdminDashboardCoverageMetric miniTestCoverage;
  final AdminDashboardCoverageMetric coverCoverage;
  final AdminDashboardCoverageMetric linkedWordCoverage;
  final AdminDashboardCoverageMetric dictionaryMatchCoverage;
  final int dictionaryEntryCount;
  final AdminDashboardMetric auditCount;
  final List<AdminTrendPoint> contentTrend;
  final bool maintenanceMode;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'window_days': windowDays,
    'user_count': userCount.toJson(),
    'pro_user_count': proUserCount.toJson(),
    'reading_inventory': readingInventory.toJson(),
    'word_inventory': wordInventory.toJson(),
    'grammar_inventory': grammarInventory.toJson(),
    'mini_test_coverage': miniTestCoverage.toJson(),
    'cover_coverage': coverCoverage.toJson(),
    'linked_word_coverage': linkedWordCoverage.toJson(),
    'dictionary_match_coverage': dictionaryMatchCoverage.toJson(),
    'dictionary_entry_count': dictionaryEntryCount,
    'audit_count': auditCount.toJson(),
    'content_trend': contentTrend
        .map((item) => item.toJson())
        .toList(growable: false),
    'maintenance_mode': maintenanceMode,
  };

  factory AdminDashboardSnapshot.fromJson(Map<String, dynamic>? json) {
    final rawTrend = json?['content_trend'] ?? json?['user_trend'];
    final legacyReadingMetric = AdminDashboardMetric.fromJson(
      json?['reading_count'] as Map<String, dynamic>?,
    );
    final legacyWordMetric = AdminDashboardMetric.fromJson(
      json?['word_count'] as Map<String, dynamic>?,
    );
    final legacyGrammarMetric = AdminDashboardMetric.fromJson(
      json?['grammar_count'] as Map<String, dynamic>?,
    );
    return AdminDashboardSnapshot(
      windowDays: (json?['window_days'] as num?)?.toInt() ?? 7,
      userCount: AdminDashboardMetric.fromJson(
        json?['user_count'] as Map<String, dynamic>?,
      ),
      proUserCount: AdminDashboardMetric.fromJson(
        json?['pro_user_count'] as Map<String, dynamic>?,
      ),
      readingInventory: AdminDashboardInventoryMetric.fromJson(
        (json?['reading_inventory'] as Map<String, dynamic>?) ??
            <String, dynamic>{
              'total': legacyReadingMetric.total,
              'published_count': legacyReadingMetric.total,
            },
      ),
      wordInventory: AdminDashboardInventoryMetric.fromJson(
        (json?['word_inventory'] as Map<String, dynamic>?) ??
            <String, dynamic>{
              'total': legacyWordMetric.total,
              'published_count': legacyWordMetric.total,
            },
      ),
      grammarInventory: AdminDashboardInventoryMetric.fromJson(
        (json?['grammar_inventory'] as Map<String, dynamic>?) ??
            <String, dynamic>{
              'total': legacyGrammarMetric.total,
              'published_count': legacyGrammarMetric.total,
            },
      ),
      miniTestCoverage: AdminDashboardCoverageMetric.fromJson(
        json?['mini_test_coverage'] as Map<String, dynamic>?,
      ),
      coverCoverage: AdminDashboardCoverageMetric.fromJson(
        json?['cover_coverage'] as Map<String, dynamic>?,
      ),
      linkedWordCoverage: AdminDashboardCoverageMetric.fromJson(
        json?['linked_word_coverage'] as Map<String, dynamic>?,
      ),
      dictionaryMatchCoverage: AdminDashboardCoverageMetric.fromJson(
        json?['dictionary_match_coverage'] as Map<String, dynamic>?,
      ),
      dictionaryEntryCount:
          (json?['dictionary_entry_count'] as num?)?.toInt() ?? 0,
      auditCount: AdminDashboardMetric.fromJson(
        json?['audit_count'] as Map<String, dynamic>?,
      ),
      contentTrend: switch (rawTrend) {
        List<dynamic>() =>
          rawTrend
              .whereType<Map<String, dynamic>>()
              .map(AdminTrendPoint.fromJson)
              .toList(growable: false),
        _ => const <AdminTrendPoint>[],
      },
      maintenanceMode: json?['maintenance_mode'] as bool? ?? false,
    );
  }
}

class AdminInviteResult {
  const AdminInviteResult({
    required this.accepted,
    required this.email,
    required this.role,
    required this.plan,
    this.invitedUserId,
    this.errorCode,
    this.errorMessage,
    this.retryCount = 0,
  });

  final bool accepted;
  final String email;
  final AppRole role;
  final EntitlementPlan plan;
  final String? invitedUserId;
  final String? errorCode;
  final String? errorMessage;
  final int retryCount;

  bool get rejected => !accepted;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accepted': accepted,
    'email': email,
    'role': role.value,
    'plan': plan.value,
    'invited_user_id': invitedUserId,
    'error_code': errorCode,
    'error_message': errorMessage,
    'retry_count': retryCount,
  };

  factory AdminInviteResult.fromJson(Map<String, dynamic>? json) {
    return AdminInviteResult(
      accepted: json?['accepted'] as bool? ?? false,
      email: json?['email']?.toString() ?? '',
      role: _roleFromValue(json?['role']?.toString()),
      plan: _planFromValue(json?['plan']?.toString()),
      invitedUserId: _emptyStringAsNull(json?['invited_user_id']?.toString()),
      errorCode: _emptyStringAsNull(json?['error_code']?.toString()),
      errorMessage: _emptyStringAsNull(json?['error_message']?.toString()),
      retryCount: (json?['retry_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminMutationState {
  const AdminMutationState({
    this.isPending = false,
    this.lastError,
    this.updatedAt,
  });

  final bool isPending;
  final String? lastError;
  final DateTime? updatedAt;

  AdminMutationState copyWith({
    bool? isPending,
    String? lastError,
    DateTime? updatedAt,
    bool clearError = false,
  }) {
    return AdminMutationState(
      isPending: isPending ?? this.isPending,
      lastError: clearError ? null : lastError ?? this.lastError,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AdminContentMetadata {
  const AdminContentMetadata({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.createdByEmail,
    this.updatedByEmail,
  });

  final String? id;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdByEmail;
  final String? updatedByEmail;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'created_by_email': createdByEmail,
    'updated_by_email': updatedByEmail,
  };

  factory AdminContentMetadata.fromJson(Map<String, dynamic>? json) {
    return AdminContentMetadata(
      id: _emptyStringAsNull(json?['id']?.toString()),
      createdAt: _dateTimeFromValue(json?['created_at']),
      updatedAt: _dateTimeFromValue(json?['updated_at']),
      createdByEmail: _emptyStringAsNull(json?['created_by_email']?.toString()),
      updatedByEmail: _emptyStringAsNull(json?['updated_by_email']?.toString()),
    );
  }
}

class AdminPackDetail {
  const AdminPackDetail({
    this.metadata = const AdminContentMetadata(),
    this.name = '',
    this.fromLang = 'en',
    this.toLang = 'tr',
    this.isPro = false,
    this.isPublished = true,
    this.publishAt,
    this.unpublishAt,
    this.wordCount = 0,
    this.readingCount = 0,
  });

  final AdminContentMetadata metadata;
  final String name;
  final String fromLang;
  final String toLang;
  final bool isPro;
  final bool isPublished;
  final DateTime? publishAt;
  final DateTime? unpublishAt;
  final int wordCount;
  final int readingCount;

  AdminPackDetail copyWith({
    AdminContentMetadata? metadata,
    String? name,
    String? fromLang,
    String? toLang,
    bool? isPro,
    bool? isPublished,
    DateTime? publishAt,
    DateTime? unpublishAt,
    int? wordCount,
    int? readingCount,
    bool clearPublishAt = false,
    bool clearUnpublishAt = false,
  }) {
    return AdminPackDetail(
      metadata: metadata ?? this.metadata,
      name: name ?? this.name,
      fromLang: fromLang ?? this.fromLang,
      toLang: toLang ?? this.toLang,
      isPro: isPro ?? this.isPro,
      isPublished: isPublished ?? this.isPublished,
      publishAt: clearPublishAt ? null : publishAt ?? this.publishAt,
      unpublishAt: clearUnpublishAt ? null : unpublishAt ?? this.unpublishAt,
      wordCount: wordCount ?? this.wordCount,
      readingCount: readingCount ?? this.readingCount,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': metadata.id,
    'name': name,
    'from_lang': fromLang,
    'to_lang': toLang,
    'is_pro': isPro,
    'is_published': isPublished,
    'publish_at': publishAt?.toIso8601String(),
    'unpublish_at': unpublishAt?.toIso8601String(),
  };

  factory AdminPackDetail.fromJson(Map<String, dynamic>? json) {
    return AdminPackDetail(
      metadata: AdminContentMetadata.fromJson(json),
      name: json?['name']?.toString() ?? '',
      fromLang: json?['from_lang']?.toString() ?? 'en',
      toLang: json?['to_lang']?.toString() ?? 'tr',
      isPro: json?['is_pro'] as bool? ?? false,
      isPublished: json?['is_published'] as bool? ?? true,
      publishAt: _dateTimeFromValue(json?['publish_at']),
      unpublishAt: _dateTimeFromValue(json?['unpublish_at']),
      wordCount: (json?['word_count'] as num?)?.toInt() ?? 0,
      readingCount: (json?['reading_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminWordDetail {
  const AdminWordDetail({
    this.metadata = const AdminContentMetadata(),
    this.packId,
    this.enWord = '',
    this.trMeaning = '',
    this.pos = 'n.',
    this.posRaw,
    this.exampleEn = '',
    this.exampleTr,
    this.synonymsRaw,
    this.antonymsRaw,
    this.level,
    this.tagsRaw,
    this.notes,
    this.isPro = false,
    this.isPublished = true,
    this.publishAt,
    this.unpublishAt,
  });

  final AdminContentMetadata metadata;
  final String? packId;
  final String enWord;
  final String trMeaning;
  final String pos;
  final String? posRaw;
  final String exampleEn;
  final String? exampleTr;
  final String? synonymsRaw;
  final String? antonymsRaw;
  final String? level;
  final String? tagsRaw;
  final String? notes;
  final bool isPro;
  final bool isPublished;
  final DateTime? publishAt;
  final DateTime? unpublishAt;

  AdminWordDetail copyWith({
    AdminContentMetadata? metadata,
    String? packId,
    String? enWord,
    String? trMeaning,
    String? pos,
    String? posRaw,
    String? exampleEn,
    String? exampleTr,
    String? synonymsRaw,
    String? antonymsRaw,
    String? level,
    String? tagsRaw,
    String? notes,
    bool? isPro,
    bool? isPublished,
    DateTime? publishAt,
    DateTime? unpublishAt,
    bool clearPackId = false,
    bool clearPosRaw = false,
    bool clearExampleTr = false,
    bool clearSynonymsRaw = false,
    bool clearAntonymsRaw = false,
    bool clearLevel = false,
    bool clearTagsRaw = false,
    bool clearNotes = false,
    bool clearPublishAt = false,
    bool clearUnpublishAt = false,
  }) {
    return AdminWordDetail(
      metadata: metadata ?? this.metadata,
      packId: clearPackId ? null : packId ?? this.packId,
      enWord: enWord ?? this.enWord,
      trMeaning: trMeaning ?? this.trMeaning,
      pos: pos ?? this.pos,
      posRaw: clearPosRaw ? null : posRaw ?? this.posRaw,
      exampleEn: exampleEn ?? this.exampleEn,
      exampleTr: clearExampleTr ? null : exampleTr ?? this.exampleTr,
      synonymsRaw: clearSynonymsRaw ? null : synonymsRaw ?? this.synonymsRaw,
      antonymsRaw: clearAntonymsRaw ? null : antonymsRaw ?? this.antonymsRaw,
      level: clearLevel ? null : level ?? this.level,
      tagsRaw: clearTagsRaw ? null : tagsRaw ?? this.tagsRaw,
      notes: clearNotes ? null : notes ?? this.notes,
      isPro: isPro ?? this.isPro,
      isPublished: isPublished ?? this.isPublished,
      publishAt: clearPublishAt ? null : publishAt ?? this.publishAt,
      unpublishAt: clearUnpublishAt ? null : unpublishAt ?? this.unpublishAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': metadata.id,
    'pack_id': packId,
    'en_word': enWord,
    'tr_meaning': trMeaning,
    'pos': pos,
    'pos_raw': posRaw,
    'example_en': exampleEn,
    'example_tr': exampleTr,
    'synonyms_raw': synonymsRaw,
    'antonyms_raw': antonymsRaw,
    'level': level,
    'tags_raw': tagsRaw,
    'notes': notes,
    'is_pro': isPro,
    'is_published': isPublished,
    'publish_at': publishAt?.toIso8601String(),
    'unpublish_at': unpublishAt?.toIso8601String(),
  };

  factory AdminWordDetail.fromJson(Map<String, dynamic>? json) {
    return AdminWordDetail(
      metadata: AdminContentMetadata.fromJson(json),
      packId: _emptyStringAsNull(json?['pack_id']?.toString()),
      enWord: json?['en_word']?.toString() ?? '',
      trMeaning: json?['tr_meaning']?.toString() ?? '',
      pos: json?['pos']?.toString() ?? 'n.',
      posRaw: _emptyStringAsNull(json?['pos_raw']?.toString()),
      exampleEn: json?['example_en']?.toString() ?? '',
      exampleTr: _emptyStringAsNull(json?['example_tr']?.toString()),
      synonymsRaw: _emptyStringAsNull(json?['synonyms_raw']?.toString()),
      antonymsRaw: _emptyStringAsNull(json?['antonyms_raw']?.toString()),
      level: _emptyStringAsNull(json?['level']?.toString()),
      tagsRaw: _emptyStringAsNull(json?['tags_raw']?.toString()),
      notes: _emptyStringAsNull(json?['notes']?.toString()),
      isPro: json?['is_pro'] as bool? ?? false,
      isPublished: json?['is_published'] as bool? ?? true,
      publishAt: _dateTimeFromValue(json?['publish_at']),
      unpublishAt: _dateTimeFromValue(json?['unpublish_at']),
    );
  }
}

const List<String> adminAllowedWordPosValues = <String>[
  'n.',
  'v.',
  'adj.',
  'adv.',
  'prep.',
  'conj.',
  'det.',
  'modal',
  'NP',
  'phr. v.',
];

const String adminAllowedWordPosValuesLabel =
    'n., v., adj., adv., prep., conj., det., modal, NP, phr. v.';

String? normalizeAdminWordPos(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final rawParts = trimmed
      .split(RegExp(r'\s*(?:;|,|/|\|)\s*'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (rawParts.isEmpty) {
    return null;
  }

  final normalizedParts = <String>[];
  for (final rawPart in rawParts) {
    final normalizedPart = _normalizeAdminWordPosToken(rawPart);
    if (normalizedPart == null) {
      return null;
    }
    normalizedParts.add(normalizedPart);
  }
  return normalizedParts.join(';');
}

String? _normalizeAdminWordPosToken(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed == 'NP') {
    return 'NP';
  }

  final collapsed = trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '');
  return switch (collapsed) {
    'n' || 'noun' || 'nouns' || 'substantive' => 'n.',
    'v' || 'verb' || 'verbs' => 'v.',
    'adj' || 'adjective' || 'adjectives' => 'adj.',
    'adv' || 'adverb' || 'adverbs' => 'adv.',
    'prep' || 'preposition' || 'prepositions' => 'prep.',
    'conj' || 'conjunction' || 'conjunctions' => 'conj.',
    'det' || 'determiner' || 'determiners' || 'article' || 'articles' => 'det.',
    'modal' || 'modalverb' || 'modalverbs' => 'modal',
    'np' || 'propernoun' || 'propernouns' => 'NP',
    'phrv' || 'phrasal' || 'phrasalverb' || 'phrasalverbs' => 'phr. v.',
    _ => null,
  };
}

class AdminReadingWordLinkInput {
  const AdminReadingWordLinkInput({
    required this.wordId,
    required this.enWord,
    required this.trMeaning,
  });

  final String wordId;
  final String enWord;
  final String trMeaning;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'word_id': wordId,
    'en_word': enWord,
    'tr_meaning': trMeaning,
  };

  factory AdminReadingWordLinkInput.fromJson(Map<String, dynamic>? json) {
    return AdminReadingWordLinkInput(
      wordId: json?['word_id']?.toString() ?? '',
      enWord: json?['en_word']?.toString() ?? '',
      trMeaning: json?['tr_meaning']?.toString() ?? '',
    );
  }
}

class AdminReadingSentenceTranslationInput {
  const AdminReadingSentenceTranslationInput({
    this.id,
    this.provider = 'manual',
    this.targetLang = 'tr',
    this.translatedText = '',
  });

  final String? id;
  final String provider;
  final String targetLang;
  final String translatedText;

  AdminReadingSentenceTranslationInput copyWith({
    String? id,
    String? provider,
    String? targetLang,
    String? translatedText,
    bool clearId = false,
  }) {
    return AdminReadingSentenceTranslationInput(
      id: clearId ? null : id ?? this.id,
      provider: provider ?? this.provider,
      targetLang: targetLang ?? this.targetLang,
      translatedText: translatedText ?? this.translatedText,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'provider': provider,
    'target_lang': targetLang,
    'translated_text': translatedText,
  };

  factory AdminReadingSentenceTranslationInput.fromJson(
    Map<String, dynamic>? json,
  ) {
    return AdminReadingSentenceTranslationInput(
      id: _emptyStringAsNull(json?['id']?.toString()),
      provider: json?['provider']?.toString() ?? 'manual',
      targetLang: json?['target_lang']?.toString() ?? 'tr',
      translatedText: json?['translated_text']?.toString() ?? '',
    );
  }
}

class AdminReadingSentenceInput {
  const AdminReadingSentenceInput({
    this.id,
    required this.idx,
    required this.sentenceEn,
    this.sentenceTr,
    this.translations = const <AdminReadingSentenceTranslationInput>[],
  });

  final String? id;
  final int idx;
  final String sentenceEn;
  final String? sentenceTr;
  final List<AdminReadingSentenceTranslationInput> translations;

  AdminReadingSentenceInput copyWith({
    String? id,
    int? idx,
    String? sentenceEn,
    String? sentenceTr,
    List<AdminReadingSentenceTranslationInput>? translations,
    bool clearId = false,
    bool clearSentenceTr = false,
  }) {
    return AdminReadingSentenceInput(
      id: clearId ? null : id ?? this.id,
      idx: idx ?? this.idx,
      sentenceEn: sentenceEn ?? this.sentenceEn,
      sentenceTr: clearSentenceTr ? null : sentenceTr ?? this.sentenceTr,
      translations: translations ?? this.translations,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'idx': idx,
    'sentence_en': sentenceEn,
    'sentence_tr': sentenceTr,
    'translations': translations
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  factory AdminReadingSentenceInput.fromJson(Map<String, dynamic>? json) {
    final rawTranslations = json?['translations'];
    return AdminReadingSentenceInput(
      id: _emptyStringAsNull(json?['id']?.toString()),
      idx: (json?['idx'] as num?)?.toInt() ?? 1,
      sentenceEn: json?['sentence_en']?.toString() ?? '',
      sentenceTr: _emptyStringAsNull(json?['sentence_tr']?.toString()),
      translations: switch (rawTranslations) {
        List<dynamic>() =>
          rawTranslations
              .whereType<Map>()
              .map(
                (item) => AdminReadingSentenceTranslationInput.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminReadingSentenceTranslationInput>[],
      },
    );
  }
}

class AdminReadingDetail {
  const AdminReadingDetail({
    this.metadata = const AdminContentMetadata(),
    this.packId,
    this.title = '',
    this.level,
    this.category,
    this.tagsRaw,
    this.isPro = false,
    this.isPublished = true,
    this.publishAt,
    this.unpublishAt,
    this.sentences = const <AdminReadingSentenceInput>[],
    this.linkedWords = const <AdminReadingWordLinkInput>[],
    this.questions = const <AdminReadingQuestionInput>[],
    this.aiGenerated = false,
    this.aiGenerationMeta,
    this.cover = const AdminReadingCoverAsset(),
  });

  final AdminContentMetadata metadata;
  final String? packId;
  final String title;
  final String? level;
  final String? category;
  final String? tagsRaw;
  final bool isPro;
  final bool isPublished;
  final DateTime? publishAt;
  final DateTime? unpublishAt;
  final List<AdminReadingSentenceInput> sentences;
  final List<AdminReadingWordLinkInput> linkedWords;
  final List<AdminReadingQuestionInput> questions;
  final bool aiGenerated;
  final AdminAiGenerationMeta? aiGenerationMeta;
  final AdminReadingCoverAsset cover;

  AdminReadingDetail copyWith({
    AdminContentMetadata? metadata,
    String? packId,
    String? title,
    String? level,
    String? category,
    String? tagsRaw,
    bool? isPro,
    bool? isPublished,
    DateTime? publishAt,
    DateTime? unpublishAt,
    List<AdminReadingSentenceInput>? sentences,
    List<AdminReadingWordLinkInput>? linkedWords,
    List<AdminReadingQuestionInput>? questions,
    bool? aiGenerated,
    AdminAiGenerationMeta? aiGenerationMeta,
    AdminReadingCoverAsset? cover,
    bool clearPackId = false,
    bool clearLevel = false,
    bool clearCategory = false,
    bool clearTagsRaw = false,
    bool clearPublishAt = false,
    bool clearUnpublishAt = false,
    bool clearAiGenerationMeta = false,
  }) {
    return AdminReadingDetail(
      metadata: metadata ?? this.metadata,
      packId: clearPackId ? null : packId ?? this.packId,
      title: title ?? this.title,
      level: clearLevel ? null : level ?? this.level,
      category: clearCategory ? null : category ?? this.category,
      tagsRaw: clearTagsRaw ? null : tagsRaw ?? this.tagsRaw,
      isPro: isPro ?? this.isPro,
      isPublished: isPublished ?? this.isPublished,
      publishAt: clearPublishAt ? null : publishAt ?? this.publishAt,
      unpublishAt: clearUnpublishAt ? null : unpublishAt ?? this.unpublishAt,
      sentences: sentences ?? this.sentences,
      linkedWords: linkedWords ?? this.linkedWords,
      questions: questions ?? this.questions,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      aiGenerationMeta: clearAiGenerationMeta
          ? null
          : aiGenerationMeta ?? this.aiGenerationMeta,
      cover: cover ?? this.cover,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': metadata.id,
    'pack_id': packId,
    'title': title,
    'level': level,
    'category': category,
    'tags_raw': tagsRaw,
    'is_pro': isPro,
    'is_published': isPublished,
    'publish_at': publishAt?.toIso8601String(),
    'unpublish_at': unpublishAt?.toIso8601String(),
    'sentences': sentences.map((item) => item.toJson()).toList(growable: false),
    'linked_words': linkedWords
        .map((item) => item.toJson())
        .toList(growable: false),
    'questions': questions.map((item) => item.toJson()).toList(growable: false),
    'ai_generated': aiGenerated,
    'ai_generation_meta': aiGenerationMeta?.toJson(),
    'cover_media_asset_id': cover.mediaAssetId,
    'cover_bucket_name': cover.bucketName,
    'cover_storage_path': cover.storagePath,
    'cover_alt_text': cover.altText,
    'cover_generation_meta': cover.generationMeta,
  };

  factory AdminReadingDetail.fromJson(Map<String, dynamic>? json) {
    final rawSentences = json?['sentences'];
    final rawLinkedWords = json?['linked_words'];
    final rawQuestions = json?['questions'];
    return AdminReadingDetail(
      metadata: AdminContentMetadata.fromJson(json),
      packId: _emptyStringAsNull(json?['pack_id']?.toString()),
      title: json?['title']?.toString() ?? '',
      level: _emptyStringAsNull(json?['level']?.toString()),
      category: _emptyStringAsNull(json?['category']?.toString()),
      tagsRaw: _emptyStringAsNull(json?['tags_raw']?.toString()),
      isPro: json?['is_pro'] as bool? ?? false,
      isPublished: json?['is_published'] as bool? ?? true,
      publishAt: _dateTimeFromValue(json?['publish_at']),
      unpublishAt: _dateTimeFromValue(json?['unpublish_at']),
      sentences: switch (rawSentences) {
        List<dynamic>() =>
          rawSentences
              .whereType<Map>()
              .map(
                (item) => AdminReadingSentenceInput.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminReadingSentenceInput>[],
      },
      linkedWords: switch (rawLinkedWords) {
        List<dynamic>() =>
          rawLinkedWords
              .whereType<Map>()
              .map(
                (item) => AdminReadingWordLinkInput.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminReadingWordLinkInput>[],
      },
      questions: switch (rawQuestions) {
        List<dynamic>() =>
          rawQuestions
              .whereType<Map>()
              .map(
                (item) => AdminReadingQuestionInput.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminReadingQuestionInput>[],
      },
      aiGenerated: json?['ai_generated'] as bool? ?? false,
      aiGenerationMeta: json?['ai_generation_meta'] == null
          ? null
          : AdminAiGenerationMeta.fromJson(
              (json?['ai_generation_meta'] as Map?)?.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
      cover: AdminReadingCoverAsset.fromJson(json),
    );
  }
}

class AdminReadingCoverAsset {
  const AdminReadingCoverAsset({
    this.mediaAssetId,
    this.bucketName,
    this.storagePath,
    this.altText,
    this.generationMeta,
  });

  final String? mediaAssetId;
  final String? bucketName;
  final String? storagePath;
  final String? altText;
  final Map<String, dynamic>? generationMeta;

  bool get hasCover =>
      (bucketName?.trim().isNotEmpty ?? false) &&
      (storagePath?.trim().isNotEmpty ?? false);

  AdminReadingCoverAsset copyWith({
    String? mediaAssetId,
    String? bucketName,
    String? storagePath,
    String? altText,
    Map<String, dynamic>? generationMeta,
    bool clearMediaAssetId = false,
    bool clearBucketName = false,
    bool clearStoragePath = false,
    bool clearAltText = false,
    bool clearGenerationMeta = false,
  }) {
    return AdminReadingCoverAsset(
      mediaAssetId: clearMediaAssetId
          ? null
          : mediaAssetId ?? this.mediaAssetId,
      bucketName: clearBucketName ? null : bucketName ?? this.bucketName,
      storagePath: clearStoragePath ? null : storagePath ?? this.storagePath,
      altText: clearAltText ? null : altText ?? this.altText,
      generationMeta: clearGenerationMeta
          ? null
          : generationMeta ?? this.generationMeta,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cover_media_asset_id': mediaAssetId,
    'cover_bucket_name': bucketName,
    'cover_storage_path': storagePath,
    'cover_alt_text': altText,
    'cover_generation_meta': generationMeta,
  };

  factory AdminReadingCoverAsset.fromJson(Map<String, dynamic>? json) {
    return AdminReadingCoverAsset(
      mediaAssetId: _emptyStringAsNull(
        json?['cover_media_asset_id']?.toString(),
      ),
      bucketName: _emptyStringAsNull(json?['cover_bucket_name']?.toString()),
      storagePath: _emptyStringAsNull(json?['cover_storage_path']?.toString()),
      altText: _emptyStringAsNull(json?['cover_alt_text']?.toString()),
      generationMeta: switch (json?['cover_generation_meta']) {
        Map<String, dynamic>() =>
          json?['cover_generation_meta'] as Map<String, dynamic>,
        Map() => (json?['cover_generation_meta'] as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        _ => null,
      },
    );
  }
}

class AdminBulkReadingFocusWordAssignmentResult {
  const AdminBulkReadingFocusWordAssignmentResult({
    this.processedCount = 0,
    this.assignedCount = 0,
    this.skippedExistingCount = 0,
    this.noMatchCount = 0,
    this.errorCount = 0,
    this.sampleFailures = const <String>[],
  });

  final int processedCount;
  final int assignedCount;
  final int skippedExistingCount;
  final int noMatchCount;
  final int errorCount;
  final List<String> sampleFailures;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'processed_count': processedCount,
    'assigned_count': assignedCount,
    'skipped_existing_count': skippedExistingCount,
    'no_match_count': noMatchCount,
    'error_count': errorCount,
    'sample_failures': sampleFailures,
  };

  factory AdminBulkReadingFocusWordAssignmentResult.fromJson(
    Map<String, dynamic>? json,
  ) {
    final rawFailures = json?['sample_failures'];
    return AdminBulkReadingFocusWordAssignmentResult(
      processedCount: (json?['processed_count'] as num?)?.toInt() ?? 0,
      assignedCount: (json?['assigned_count'] as num?)?.toInt() ?? 0,
      skippedExistingCount:
          (json?['skipped_existing_count'] as num?)?.toInt() ?? 0,
      noMatchCount: (json?['no_match_count'] as num?)?.toInt() ?? 0,
      errorCount: (json?['error_count'] as num?)?.toInt() ?? 0,
      sampleFailures: switch (rawFailures) {
        List<dynamic>() =>
          rawFailures
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
        _ => const <String>[],
      },
    );
  }
}

class AdminGrammarExampleInput {
  const AdminGrammarExampleInput({
    this.id,
    required this.sortOrder,
    required this.english,
    required this.turkish,
    this.description,
  });

  final String? id;
  final int sortOrder;
  final String english;
  final String turkish;
  final String? description;

  AdminGrammarExampleInput copyWith({
    String? id,
    int? sortOrder,
    String? english,
    String? turkish,
    String? description,
    bool clearId = false,
    bool clearDescription = false,
  }) {
    return AdminGrammarExampleInput(
      id: clearId ? null : id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      english: english ?? this.english,
      turkish: turkish ?? this.turkish,
      description: clearDescription ? null : description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sort_order': sortOrder,
    'english': english,
    'turkish': turkish,
    'description': description,
  };

  factory AdminGrammarExampleInput.fromJson(Map<String, dynamic>? json) {
    return AdminGrammarExampleInput(
      id: _emptyStringAsNull(json?['id']?.toString()),
      sortOrder: (json?['sort_order'] as num?)?.toInt() ?? 1,
      english: json?['english']?.toString() ?? '',
      turkish: json?['turkish']?.toString() ?? '',
      description: _emptyStringAsNull(json?['description']?.toString()),
    );
  }
}

class AdminGrammarTestInput {
  const AdminGrammarTestInput({
    this.id,
    required this.sortOrder,
    required this.question,
    this.options = const <String>[],
    this.correctAnswer,
    this.description,
  });

  final String? id;
  final int sortOrder;
  final String question;
  final List<String> options;
  final String? correctAnswer;
  final String? description;

  AdminGrammarTestInput copyWith({
    String? id,
    int? sortOrder,
    String? question,
    List<String>? options,
    String? correctAnswer,
    String? description,
    bool clearId = false,
    bool clearCorrectAnswer = false,
    bool clearDescription = false,
  }) {
    return AdminGrammarTestInput(
      id: clearId ? null : id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswer: clearCorrectAnswer
          ? null
          : correctAnswer ?? this.correctAnswer,
      description: clearDescription ? null : description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sort_order': sortOrder,
    'question': question,
    'options': options,
    'correct_answer': correctAnswer,
    'description': description,
  };

  factory AdminGrammarTestInput.fromJson(Map<String, dynamic>? json) {
    final rawOptions = json?['options'];
    return AdminGrammarTestInput(
      id: _emptyStringAsNull(json?['id']?.toString()),
      sortOrder: (json?['sort_order'] as num?)?.toInt() ?? 1,
      question: json?['question']?.toString() ?? '',
      options: switch (rawOptions) {
        List<dynamic>() =>
          rawOptions
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
        Map<dynamic, dynamic>() =>
          rawOptions.values
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
        _ => const <String>[],
      },
      correctAnswer: _emptyStringAsNull(json?['correct_answer']?.toString()),
      description: _emptyStringAsNull(json?['description']?.toString()),
    );
  }
}

class AdminGrammarPageInput {
  const AdminGrammarPageInput({
    this.id,
    required this.pageNumber,
    required this.title,
    required this.htmlContent,
    this.wordCount = 0,
    this.examples = const <AdminGrammarExampleInput>[],
    this.tests = const <AdminGrammarTestInput>[],
  });

  final String? id;
  final int pageNumber;
  final String title;
  final String htmlContent;
  final int wordCount;
  final List<AdminGrammarExampleInput> examples;
  final List<AdminGrammarTestInput> tests;

  AdminGrammarPageInput copyWith({
    String? id,
    int? pageNumber,
    String? title,
    String? htmlContent,
    int? wordCount,
    List<AdminGrammarExampleInput>? examples,
    List<AdminGrammarTestInput>? tests,
    bool clearId = false,
  }) {
    return AdminGrammarPageInput(
      id: clearId ? null : id ?? this.id,
      pageNumber: pageNumber ?? this.pageNumber,
      title: title ?? this.title,
      htmlContent: htmlContent ?? this.htmlContent,
      wordCount: wordCount ?? this.wordCount,
      examples: examples ?? this.examples,
      tests: tests ?? this.tests,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'page_number': pageNumber,
    'title': title,
    'html_content': htmlContent,
    'word_count': wordCount,
    'examples': examples.map((item) => item.toJson()).toList(growable: false),
    'tests': tests.map((item) => item.toJson()).toList(growable: false),
  };

  factory AdminGrammarPageInput.fromJson(Map<String, dynamic>? json) {
    final rawExamples = json?['examples'];
    final rawTests = json?['tests'];
    return AdminGrammarPageInput(
      id: _emptyStringAsNull(json?['id']?.toString()),
      pageNumber: (json?['page_number'] as num?)?.toInt() ?? 1,
      title: json?['title']?.toString() ?? '',
      htmlContent: json?['html_content']?.toString() ?? '',
      wordCount: (json?['word_count'] as num?)?.toInt() ?? 0,
      examples: switch (rawExamples) {
        List<dynamic>() =>
          rawExamples
              .whereType<Map>()
              .map(
                (item) => AdminGrammarExampleInput.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminGrammarExampleInput>[],
      },
      tests: switch (rawTests) {
        List<dynamic>() =>
          rawTests
              .whereType<Map>()
              .map(
                (item) => AdminGrammarTestInput.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminGrammarTestInput>[],
      },
    );
  }
}

class AdminGrammarModuleDetail {
  const AdminGrammarModuleDetail({
    this.metadata = const AdminContentMetadata(),
    this.sortOrder = 1,
    this.title = '',
    this.fileName = '',
    this.icon = 'menu_book',
    this.color = '#4776E6',
    this.isPublished = true,
    this.publishAt,
    this.unpublishAt,
    this.pages = const <AdminGrammarPageInput>[],
  });

  final AdminContentMetadata metadata;
  final int sortOrder;
  final String title;
  final String fileName;
  final String icon;
  final String color;
  final bool isPublished;
  final DateTime? publishAt;
  final DateTime? unpublishAt;
  final List<AdminGrammarPageInput> pages;

  AdminGrammarModuleDetail copyWith({
    AdminContentMetadata? metadata,
    int? sortOrder,
    String? title,
    String? fileName,
    String? icon,
    String? color,
    bool? isPublished,
    DateTime? publishAt,
    DateTime? unpublishAt,
    List<AdminGrammarPageInput>? pages,
    bool clearPublishAt = false,
    bool clearUnpublishAt = false,
  }) {
    return AdminGrammarModuleDetail(
      metadata: metadata ?? this.metadata,
      sortOrder: sortOrder ?? this.sortOrder,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isPublished: isPublished ?? this.isPublished,
      publishAt: clearPublishAt ? null : publishAt ?? this.publishAt,
      unpublishAt: clearUnpublishAt ? null : unpublishAt ?? this.unpublishAt,
      pages: pages ?? this.pages,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': metadata.id,
    'sort_order': sortOrder,
    'title': title,
    'file_name': fileName,
    'icon': icon,
    'color': color,
    'is_published': isPublished,
    'publish_at': publishAt?.toIso8601String(),
    'unpublish_at': unpublishAt?.toIso8601String(),
    'pages': pages.map((item) => item.toJson()).toList(growable: false),
  };

  factory AdminGrammarModuleDetail.fromJson(Map<String, dynamic>? json) {
    final rawPages = json?['pages'];
    return AdminGrammarModuleDetail(
      metadata: AdminContentMetadata.fromJson(json),
      sortOrder: (json?['sort_order'] as num?)?.toInt() ?? 1,
      title: json?['title']?.toString() ?? '',
      fileName: json?['file_name']?.toString() ?? '',
      icon: json?['icon']?.toString() ?? 'menu_book',
      color: json?['color']?.toString() ?? '#4776E6',
      isPublished: json?['is_published'] as bool? ?? true,
      publishAt: _dateTimeFromValue(json?['publish_at']),
      unpublishAt: _dateTimeFromValue(json?['unpublish_at']),
      pages: switch (rawPages) {
        List<dynamic>() =>
          rawPages
              .whereType<Map>()
              .map(
                (item) => AdminGrammarPageInput.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false),
        _ => const <AdminGrammarPageInput>[],
      },
    );
  }
}

String? _emptyStringAsNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

DateTime? _dateTimeFromValue(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

AppRole _roleFromValue(String? value) {
  for (final item in AppRole.values) {
    if (item.value == value) {
      return item;
    }
  }
  return AppRole.user;
}

EntitlementPlan _planFromValue(String? value) {
  for (final item in EntitlementPlan.values) {
    if (item.value == value) {
      return item;
    }
  }
  return EntitlementPlan.free;
}
