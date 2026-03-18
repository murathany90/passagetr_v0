enum AppRole {
  user('user'),
  admin('admin'),
  superAdmin('super_admin'),
  developer('developer');

  const AppRole(this.value);

  final String value;

  static AppRole fromName(String? name) {
    for (final role in AppRole.values) {
      if (role.value == name) return role;
    }
    return AppRole.user;
  }
}
