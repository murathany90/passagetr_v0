import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

enum AdminAuthStatus {
  bootstrapping,
  authenticated,
  unauthenticated,
  unauthorized,
  sessionExpired,
  busy,
}

class AdminAuthState {
  const AdminAuthState({
    required this.status,
    required this.accessContext,
    this.message,
  });

  final AdminAuthStatus status;
  final AccessContext accessContext;
  final String? message;

  bool get isBusy => status == AdminAuthStatus.busy;
  bool get isBootstrapping => status == AdminAuthStatus.bootstrapping;
  bool get isAuthenticated => status == AdminAuthStatus.authenticated;
  bool get needsLogin =>
      status == AdminAuthStatus.unauthenticated ||
      status == AdminAuthStatus.unauthorized ||
      status == AdminAuthStatus.sessionExpired;

  AdminAuthState copyWith({
    AdminAuthStatus? status,
    AccessContext? accessContext,
    String? message,
    bool clearMessage = false,
  }) {
    return AdminAuthState(
      status: status ?? this.status,
      accessContext: accessContext ?? this.accessContext,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class AdminSettingsState {
  const AdminSettingsState({
    this.persisted = const AdminSettingsSnapshot(),
    this.draft = const AdminSettingsSnapshot(),
    this.isLoading = true,
    this.isSaving = false,
    this.errorMessage,
    this.noticeMessage,
  });

  final AdminSettingsSnapshot persisted;
  final AdminSettingsSnapshot draft;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? noticeMessage;

  bool get isDirty =>
      persisted.toJson().toString() != draft.toJson().toString();

  AdminSettingsState copyWith({
    AdminSettingsSnapshot? persisted,
    AdminSettingsSnapshot? draft,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? noticeMessage,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return AdminSettingsState(
      persisted: persisted ?? this.persisted,
      draft: draft ?? this.draft,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

class AdminWordPageRequest {
  const AdminWordPageRequest({
    required this.packId,
    required this.query,
    required this.offset,
    required this.limit,
    this.isPublished,
  });

  final String? packId;
  final String query;
  final int offset;
  final int limit;
  final bool? isPublished;

  @override
  bool operator ==(Object other) {
    return other is AdminWordPageRequest &&
        other.packId == packId &&
        other.query == query &&
        other.offset == offset &&
        other.limit == limit &&
        other.isPublished == isPublished;
  }

  @override
  int get hashCode => Object.hash(packId, query, offset, limit, isPublished);
}

class AdminReadingPageRequest {
  const AdminReadingPageRequest({
    required this.query,
    required this.offset,
    required this.limit,
    this.level,
    this.isPublished,
  });

  final String query;
  final int offset;
  final int limit;
  final String? level;
  final bool? isPublished;

  @override
  bool operator ==(Object other) {
    return other is AdminReadingPageRequest &&
        other.query == query &&
        other.offset == offset &&
        other.limit == limit &&
        other.level == level &&
        other.isPublished == isPublished;
  }

  @override
  int get hashCode => Object.hash(query, offset, limit, level, isPublished);
}

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.userCount,
    required this.proUserCount,
    required this.wordCount,
    required this.readingCount,
    required this.grammarCount,
    required this.auditCount,
  });

  final int userCount;
  final int proUserCount;
  final int wordCount;
  final int readingCount;
  final int grammarCount;
  final int auditCount;
}

class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    required this.email,
    required this.role,
    required this.plan,
    required this.statusLabel,
    required this.lastSeenLabel,
  });

  final String id;
  final String email;
  final AppRole role;
  final EntitlementPlan plan;
  final String statusLabel;
  final String lastSeenLabel;

  AdminUserRecord copyWith({AppRole? role, EntitlementPlan? plan}) {
    return AdminUserRecord(
      id: id,
      email: email,
      role: role ?? this.role,
      plan: plan ?? this.plan,
      statusLabel: statusLabel,
      lastSeenLabel: lastSeenLabel,
    );
  }
}

class AdminAuditRecord {
  const AdminAuditRecord({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestampLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final String timestampLabel;
}

enum AdminAuditFeedState { ready, empty, unavailable }

class AdminAuditFeed {
  const AdminAuditFeed._({
    required this.state,
    required this.records,
    required this.message,
  });

  const AdminAuditFeed.ready(List<AdminAuditRecord> records)
    : this._(state: AdminAuditFeedState.ready, records: records, message: null);

  const AdminAuditFeed.empty(String message)
    : this._(
        state: AdminAuditFeedState.empty,
        records: const <AdminAuditRecord>[],
        message: message,
      );

  const AdminAuditFeed.unavailable(String message)
    : this._(
        state: AdminAuditFeedState.unavailable,
        records: const <AdminAuditRecord>[],
        message: message,
      );

  final AdminAuditFeedState state;
  final List<AdminAuditRecord> records;
  final String? message;

  bool get hasRecords => records.isNotEmpty;
  bool get isUnavailable => state == AdminAuditFeedState.unavailable;
  bool get isEmptyState => state == AdminAuditFeedState.empty;
}

class AdminPackRecord {
  const AdminPackRecord({
    required this.id,
    required this.name,
    required this.wordCount,
    required this.isPublished,
    required this.updatedAtLabel,
    this.createdAtLabel,
    this.updatedByLabel,
  });

  final String id;
  final String name;
  final int wordCount;
  final bool isPublished;
  final String updatedAtLabel;
  final String? createdAtLabel;
  final String? updatedByLabel;

  AdminPackRecord copyWith({
    String? id,
    String? name,
    int? wordCount,
    bool? isPublished,
    String? updatedAtLabel,
    String? createdAtLabel,
    String? updatedByLabel,
  }) {
    return AdminPackRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      wordCount: wordCount ?? this.wordCount,
      isPublished: isPublished ?? this.isPublished,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      updatedByLabel: updatedByLabel ?? this.updatedByLabel,
    );
  }
}

class AdminWordRecord {
  const AdminWordRecord({
    required this.id,
    required this.packId,
    required this.enWord,
    required this.trMeaning,
    required this.pos,
    required this.exampleEn,
    required this.exampleTr,
    required this.level,
    required this.notes,
    required this.isPublished,
    required this.updatedAtLabel,
    this.createdAtLabel,
    this.updatedByLabel,
  });

  final String id;
  final String packId;
  final String enWord;
  final String trMeaning;
  final String pos;
  final String exampleEn;
  final String? exampleTr;
  final String? level;
  final String? notes;
  final bool isPublished;
  final String updatedAtLabel;
  final String? createdAtLabel;
  final String? updatedByLabel;

  AdminWordRecord copyWith({
    String? id,
    String? packId,
    String? enWord,
    String? trMeaning,
    String? pos,
    String? exampleEn,
    String? exampleTr,
    String? level,
    String? notes,
    bool? isPublished,
    String? updatedAtLabel,
    String? createdAtLabel,
    String? updatedByLabel,
  }) {
    return AdminWordRecord(
      id: id ?? this.id,
      packId: packId ?? this.packId,
      enWord: enWord ?? this.enWord,
      trMeaning: trMeaning ?? this.trMeaning,
      pos: pos ?? this.pos,
      exampleEn: exampleEn ?? this.exampleEn,
      exampleTr: exampleTr ?? this.exampleTr,
      level: level ?? this.level,
      notes: notes ?? this.notes,
      isPublished: isPublished ?? this.isPublished,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      updatedByLabel: updatedByLabel ?? this.updatedByLabel,
    );
  }
}

class AdminReadingRecord {
  const AdminReadingRecord({
    required this.id,
    required this.packId,
    required this.packName,
    required this.title,
    required this.level,
    required this.category,
    required this.tagsRaw,
    required this.isPro,
    required this.isPublished,
    required this.updatedAtLabel,
    this.createdAtLabel,
    this.updatedByLabel,
  });

  final String id;
  final String? packId;
  final String? packName;
  final String title;
  final String? level;
  final String? category;
  final String? tagsRaw;
  final bool isPro;
  final bool isPublished;
  final String updatedAtLabel;
  final String? createdAtLabel;
  final String? updatedByLabel;

  AdminReadingRecord copyWith({
    String? id,
    String? packId,
    String? packName,
    String? title,
    String? level,
    String? category,
    String? tagsRaw,
    bool? isPro,
    bool? isPublished,
    String? updatedAtLabel,
    String? createdAtLabel,
    String? updatedByLabel,
  }) {
    return AdminReadingRecord(
      id: id ?? this.id,
      packId: packId ?? this.packId,
      packName: packName ?? this.packName,
      title: title ?? this.title,
      level: level ?? this.level,
      category: category ?? this.category,
      tagsRaw: tagsRaw ?? this.tagsRaw,
      isPro: isPro ?? this.isPro,
      isPublished: isPublished ?? this.isPublished,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      updatedByLabel: updatedByLabel ?? this.updatedByLabel,
    );
  }
}

class AdminGrammarRecord {
  const AdminGrammarRecord({
    required this.id,
    required this.sortOrder,
    required this.title,
    required this.fileName,
    required this.pageCount,
    required this.icon,
    required this.color,
    required this.isPublished,
    required this.updatedAtLabel,
    this.createdAtLabel,
    this.updatedByLabel,
  });

  final int id;
  final int sortOrder;
  final String title;
  final String fileName;
  final int pageCount;
  final String icon;
  final String color;
  final bool isPublished;
  final String updatedAtLabel;
  final String? createdAtLabel;
  final String? updatedByLabel;

  AdminGrammarRecord copyWith({
    int? id,
    int? sortOrder,
    String? title,
    String? fileName,
    int? pageCount,
    String? icon,
    String? color,
    bool? isPublished,
    String? updatedAtLabel,
    String? createdAtLabel,
    String? updatedByLabel,
  }) {
    return AdminGrammarRecord(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      pageCount: pageCount ?? this.pageCount,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isPublished: isPublished ?? this.isPublished,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      updatedByLabel: updatedByLabel ?? this.updatedByLabel,
    );
  }
}
