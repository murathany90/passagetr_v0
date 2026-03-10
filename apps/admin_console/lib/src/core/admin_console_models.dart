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

class AdminPackRecord {
  const AdminPackRecord({
    required this.id,
    required this.name,
    required this.wordCount,
    required this.isPublished,
    required this.updatedAtLabel,
  });

  final String id;
  final String name;
  final int wordCount;
  final bool isPublished;
  final String updatedAtLabel;

  AdminPackRecord copyWith({
    String? id,
    String? name,
    int? wordCount,
    bool? isPublished,
    String? updatedAtLabel,
  }) {
    return AdminPackRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      wordCount: wordCount ?? this.wordCount,
      isPublished: isPublished ?? this.isPublished,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
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
    required this.isPublished,
    required this.updatedAtLabel,
  });

  final String id;
  final String? packId;
  final String? packName;
  final String title;
  final String? level;
  final String? category;
  final String? tagsRaw;
  final bool isPublished;
  final String updatedAtLabel;

  AdminReadingRecord copyWith({
    String? id,
    String? packId,
    String? packName,
    String? title,
    String? level,
    String? category,
    String? tagsRaw,
    bool? isPublished,
    String? updatedAtLabel,
  }) {
    return AdminReadingRecord(
      id: id ?? this.id,
      packId: packId ?? this.packId,
      packName: packName ?? this.packName,
      title: title ?? this.title,
      level: level ?? this.level,
      category: category ?? this.category,
      tagsRaw: tagsRaw ?? this.tagsRaw,
      isPublished: isPublished ?? this.isPublished,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
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
    );
  }
}
