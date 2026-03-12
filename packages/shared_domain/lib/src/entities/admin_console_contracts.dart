import 'package:shared_core/shared_core.dart';

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

class AdminSettingsSnapshot {
  const AdminSettingsSnapshot({
    this.general = const AdminGeneralSettings(),
    this.notifications = const AdminNotificationSettings(),
    this.security = const AdminSecuritySettings(),
    this.dataManagement = const AdminDataManagementSettings(),
  });

  final AdminGeneralSettings general;
  final AdminNotificationSettings notifications;
  final AdminSecuritySettings security;
  final AdminDataManagementSettings dataManagement;

  AdminSettingsSnapshot copyWith({
    AdminGeneralSettings? general,
    AdminNotificationSettings? notifications,
    AdminSecuritySettings? security,
    AdminDataManagementSettings? dataManagement,
  }) {
    return AdminSettingsSnapshot(
      general: general ?? this.general,
      notifications: notifications ?? this.notifications,
      security: security ?? this.security,
      dataManagement: dataManagement ?? this.dataManagement,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'general': general.toJson(),
    'notifications': notifications.toJson(),
    'security': security.toJson(),
    'data_management': dataManagement.toJson(),
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

class AdminDashboardSnapshot {
  const AdminDashboardSnapshot({
    required this.windowDays,
    required this.userCount,
    required this.proUserCount,
    required this.wordCount,
    required this.readingCount,
    required this.grammarCount,
    required this.auditCount,
    required this.userTrend,
    required this.maintenanceMode,
  });

  final int windowDays;
  final AdminDashboardMetric userCount;
  final AdminDashboardMetric proUserCount;
  final AdminDashboardMetric wordCount;
  final AdminDashboardMetric readingCount;
  final AdminDashboardMetric grammarCount;
  final AdminDashboardMetric auditCount;
  final List<AdminTrendPoint> userTrend;
  final bool maintenanceMode;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'window_days': windowDays,
    'user_count': userCount.toJson(),
    'pro_user_count': proUserCount.toJson(),
    'word_count': wordCount.toJson(),
    'reading_count': readingCount.toJson(),
    'grammar_count': grammarCount.toJson(),
    'audit_count': auditCount.toJson(),
    'user_trend': userTrend
        .map((item) => item.toJson())
        .toList(growable: false),
    'maintenance_mode': maintenanceMode,
  };

  factory AdminDashboardSnapshot.fromJson(Map<String, dynamic>? json) {
    final rawTrend = json?['user_trend'];
    return AdminDashboardSnapshot(
      windowDays: (json?['window_days'] as num?)?.toInt() ?? 7,
      userCount: AdminDashboardMetric.fromJson(
        json?['user_count'] as Map<String, dynamic>?,
      ),
      proUserCount: AdminDashboardMetric.fromJson(
        json?['pro_user_count'] as Map<String, dynamic>?,
      ),
      wordCount: AdminDashboardMetric.fromJson(
        json?['word_count'] as Map<String, dynamic>?,
      ),
      readingCount: AdminDashboardMetric.fromJson(
        json?['reading_count'] as Map<String, dynamic>?,
      ),
      grammarCount: AdminDashboardMetric.fromJson(
        json?['grammar_count'] as Map<String, dynamic>?,
      ),
      auditCount: AdminDashboardMetric.fromJson(
        json?['audit_count'] as Map<String, dynamic>?,
      ),
      userTrend: switch (rawTrend) {
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
    this.pos = 'noun',
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
      pos: json?['pos']?.toString() ?? 'noun',
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
    bool clearPackId = false,
    bool clearLevel = false,
    bool clearCategory = false,
    bool clearTagsRaw = false,
    bool clearPublishAt = false,
    bool clearUnpublishAt = false,
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
  };

  factory AdminReadingDetail.fromJson(Map<String, dynamic>? json) {
    final rawSentences = json?['sentences'];
    final rawLinkedWords = json?['linked_words'];
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
