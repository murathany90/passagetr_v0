import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class AdminUserListQueryController extends StateNotifier<AdminUserListQuery> {
  AdminUserListQueryController() : super(const AdminUserListQuery());

  void updateQuery(String value) {
    state = state.copyWith(query: value, offset: 0);
  }

  void updateRole(AppRole? role) {
    state = state.copyWith(role: role, clearRole: role == null, offset: 0);
  }

  void updatePlan(EntitlementPlan? plan) {
    state = state.copyWith(plan: plan, clearPlan: plan == null, offset: 0);
  }

  void updateStatus(AdminUserStatusFilter? status) {
    state = state.copyWith(
      status: status,
      clearStatus: status == null,
      offset: 0,
    );
  }

  void nextPage() {
    state = state.copyWith(offset: state.offset + state.limit);
  }

  void previousPage() {
    state = state.copyWith(
      offset: (state.offset - state.limit).clamp(0, 1 << 30),
    );
  }

  void resetPagination() {
    state = state.copyWith(offset: 0);
  }
}

class AdminSelectedUsersController extends StateNotifier<Set<String>> {
  AdminSelectedUsersController() : super(const <String>{});

  void toggle(String userId) {
    final next = Set<String>.from(state);
    if (!next.add(userId)) {
      next.remove(userId);
    }
    state = next;
  }

  void toggleAll(Iterable<String> userIds, {required bool selected}) {
    final next = Set<String>.from(state);
    if (selected) {
      next.addAll(userIds);
    } else {
      next.removeAll(userIds);
    }
    state = next;
  }

  void removeAll(Iterable<String> userIds) {
    final next = Set<String>.from(state)..removeAll(userIds);
    state = next;
  }

  void clear() {
    state = const <String>{};
  }
}

class AdminUserListOverridesController
    extends StateNotifier<Map<String, AdminUserListItem>> {
  AdminUserListOverridesController()
    : super(const <String, AdminUserListItem>{});

  void upsert(AdminUserListItem item) {
    state = <String, AdminUserListItem>{...state, item.id: item};
  }

  void upsertAll(Iterable<AdminUserListItem> items) {
    final next = <String, AdminUserListItem>{...state};
    for (final item in items) {
      next[item.id] = item;
    }
    state = next;
  }

  void remove(String userId) {
    final next = <String, AdminUserListItem>{...state}..remove(userId);
    state = next;
  }

  void removeAll(Iterable<String> userIds) {
    final next = <String, AdminUserListItem>{...state};
    for (final userId in userIds) {
      next.remove(userId);
    }
    state = next;
  }

  void clear() {
    state = const <String, AdminUserListItem>{};
  }
}

class AdminDeletedUsersController extends StateNotifier<Set<String>> {
  AdminDeletedUsersController() : super(const <String>{});

  void add(String userId) {
    state = <String>{...state, userId};
  }

  void addAll(Iterable<String> userIds) {
    state = <String>{...state, ...userIds};
  }

  void remove(String userId) {
    final next = Set<String>.from(state)..remove(userId);
    state = next;
  }

  void clear() {
    state = const <String>{};
  }
}
