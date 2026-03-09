import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_app/src/bootstrap/student_app_bootstrap.dart';

void main() {
  runApp(const ProviderScope(child: StudentAppBootstrap()));
}
