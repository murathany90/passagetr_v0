import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/bootstrap/admin_console_bootstrap.dart';

void main() {
  runApp(const ProviderScope(child: AdminConsoleBootstrap()));
}
