enum AppEnvironment {
  dev('dev'),
  stage('stage'),
  prod('prod');

  const AppEnvironment(this.value);

  final String value;

  static AppEnvironment fromValue(String value) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.value == value,
      orElse: () => AppEnvironment.dev,
    );
  }
}

enum PlatformMode {
  mobile('mobile'),
  web('web');

  const PlatformMode(this.value);

  final String value;

  static PlatformMode fromValue(String value) {
    return PlatformMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => PlatformMode.mobile,
    );
  }
}
