import 'package:shared_core/shared_core.dart';

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

class AdminWordRecord {
  const AdminWordRecord({
    required this.id,
    required this.packId,
    required this.enWord,
    required this.trMeaning,
    required this.pos,
    required this.isPublished,
  });

  final String id;
  final String packId;
  final String enWord;
  final String trMeaning;
  final String pos;
  final bool isPublished;
}

class AdminReadingRecord {
  const AdminReadingRecord({
    required this.id,
    required this.title,
    required this.level,
    required this.category,
    required this.isPublished,
  });

  final String id;
  final String title;
  final String? level;
  final String? category;
  final bool isPublished;
}

class AdminGrammarRecord {
  const AdminGrammarRecord({
    required this.id,
    required this.title,
    required this.pageCount,
    required this.isPublished,
  });

  final int id;
  final String title;
  final int pageCount;
  final bool isPublished;
}
